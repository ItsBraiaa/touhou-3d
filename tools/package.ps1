[CmdletBinding()]
param(
    [string]$Exe = 'build/Touhou-3D.exe',
    [string]$OutDir = 'build/package',
    [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'

function Write-Failure([int]$Code, [string]$Message) {
    [Console]::Error.WriteLine("package: $Message")
    exit $Code
}

function Invoke-Checked([string]$FilePath, [string[]]$ArgumentList, [string]$Label) {
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        Write-Failure 1 "$Label failed with exit code $LASTEXITCODE."
    }
}

$repoRoot = (Get-Location).Path
$exePath = Join-Path $repoRoot $Exe
if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
    Write-Failure 2 "executable '$Exe' is missing; run F14-01's export first."
}

$status = @(git status --porcelain)
if ($LASTEXITCODE -ne 0) {
    Write-Failure 1 'git status failed.'
}
if ($status.Count -gt 0) {
    $dirtyPaths = ($status | ForEach-Object { $_.Substring([Math]::Min(3, $_.Length)) }) -join ', '
    Write-Failure 3 "working tree is dirty: $dirtyPaths"
}

$consoleExe = [IO.Path]::Combine(
    [IO.Path]::GetDirectoryName($exePath),
    ([IO.Path]::GetFileNameWithoutExtension($exePath) + '.console.exe'))
if (-not (Test-Path -LiteralPath $consoleExe -PathType Leaf)) {
    Write-Failure 2 "console executable '$([IO.Path]::GetFileName($consoleExe))' is missing; run F14-01's export first."
}

$packageRoot = Join-Path (Join-Path $repoRoot $OutDir) 'Touhou-3D'
$outRoot = Split-Path -Parent $packageRoot
$verifyRoot = Join-Path $outRoot 'verify'
$archiveName = 'Touhou-3D-{0}.zip' -f (Get-Date -Format 'yyyyMMdd')
$archivePath = Join-Path $outRoot $archiveName

New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
foreach ($path in @($packageRoot, $verifyRoot, $archivePath)) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

$projectRoot = Join-Path $packageRoot 'project'
$gameRoot = Join-Path $packageRoot 'game'
New-Item -ItemType Directory -Force -Path $projectRoot, $gameRoot | Out-Null

$trackedFiles = @(git ls-files)
if ($LASTEXITCODE -ne 0) {
    Write-Failure 1 'git ls-files failed.'
}
foreach ($relativePath in $trackedFiles) {
    if ([string]::IsNullOrWhiteSpace($relativePath)) {
        continue
    }
    $normalised = $relativePath.Replace('/', '\')
    if ($normalised.StartsWith('.claude\', [StringComparison]::OrdinalIgnoreCase) -or
            $normalised.StartsWith('.agents\', [StringComparison]::OrdinalIgnoreCase)) {
        continue
    }
    $source = Join-Path $repoRoot $normalised
    $destination = Join-Path $projectRoot $normalised
    $destinationDirectory = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

Copy-Item -LiteralPath $exePath -Destination (Join-Path $gameRoot 'Touhou-3D.exe') -Force
Copy-Item -LiteralPath $consoleExe -Destination (Join-Path $gameRoot 'Touhou-3D.console.exe') -Force

$readme = @(
    'Touhou 3D — Guardiã dos Ventos',
    '',
    'Execute game/Touhou-3D.exe para iniciar o jogo.',
    'Abra project/ no Godot 4.7.2 para editar ou executar o projeto.',
    '',
    'Controles:',
    'Mover: WASD; subir/descer: Espaço/Ctrl; câmera: setas.',
    'Disparar: J; foco: Shift; alvo: Tab; próximo alvo: Q.',
    'Bomba: B; pausa: Esc; menus: setas, Enter e Esc.',
    '',
    'Os créditos estão no menu Créditos.',
    'Licenças e créditos de assets estão em project/docs/ASSET_CREDITS.md',
    'e project/assets/licenses/.'
)
$readme | Set-Content -LiteralPath (Join-Path $packageRoot 'LEIA-ME.txt') -Encoding UTF8

Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $archivePath -CompressionLevel Optimal
$archiveInfo = Get-Item -LiteralPath $archivePath
$archiveFiles = (Get-ChildItem -LiteralPath $packageRoot -Recurse -File).Count
Write-Output ("PACKAGE_ARCHIVE {0} bytes, {1} staged files: {2}" -f $archiveInfo.Length, $archiveFiles, $archivePath)

if ($SkipVerify) {
    Write-Output 'PACKAGE_OK (verification skipped)'
    exit 0
}

$verifyDestination = Join-Path $verifyRoot 'Touhou-3D'
New-Item -ItemType Directory -Force -Path $verifyRoot | Out-Null
Expand-Archive -LiteralPath $archivePath -DestinationPath $verifyRoot -Force
$verifyProject = Join-Path $verifyDestination 'project'
$verifyGame = Join-Path $verifyDestination 'game'
$godotScript = Join-Path $repoRoot 'tools/godot.ps1'

Invoke-Checked 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $godotScript, '--headless', '--path', $verifyProject, '--import') 'project import'

$testOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $godotScript --headless --path $verifyProject --script res://tests/run_tests.gd 2>&1
if ($LASTEXITCODE -ne 0 -or ($testOutput -join "`n") -match 'SCRIPT ERROR') {
    Write-Failure 1 'extracted project tests failed or emitted SCRIPT ERROR.'
}

$bootOutput = & (Join-Path $verifyGame 'Touhou-3D.console.exe') --headless --quit-after 300 2>&1
if ($LASTEXITCODE -ne 0 -or ($bootOutput -join "`n") -match 'ERROR:') {
    Write-Failure 1 'extracted executable boot failed or emitted ERROR:.'
}

Write-Output 'PACKAGE_OK'
