<#
.SYNOPSIS
Runs the headless GDScript test suite (tests/run_tests.gd) through tools/godot.ps1.

.DESCRIPTION
Exits with Godot's exit code: 0 when every discovered test passed, 1 otherwise.

Scripts that reference class_name types (TestCase, the Rules Cores) resolve only through
Godot's global class cache in .godot/, which the editor writes when it scans the project.
This script refreshes that cache with a headless editor import (about three seconds) when
the cache is missing, when -Import is given, or when any .gd file under the code folders is
newer than the last import this script performed.

.PARAMETER Filter
Substring matched against "<file>::<method>"; only matching tests run.
Forwarded to the runner as --filter=<value>.

.PARAMETER Import
Force the headless editor import before the tests run.

.PARAMETER ExtraArgs
Everything else is forwarded to the runner after "--", for example --timeout=60.

.EXAMPLE
tools/test.ps1

.EXAMPLE
tools/test.ps1 -Filter flight_model
#>
[CmdletBinding()]
param(
    [string]$Filter = '',
    [switch]$Import,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs = @()
)

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$godotWrapper = Join-Path $PSScriptRoot 'godot.ps1'
$cacheDir = Join-Path $root '.godot'
$classCache = Join-Path $cacheDir 'global_script_class_cache.cfg'
$stamp = Join-Path $cacheDir 'test_import.stamp'
$codeDirs = @('scripts', 'tests', 'tools', 'scenes', 'content', 'addons')

function Test-ImportNeeded {
    if (-not (Test-Path -LiteralPath $classCache)) { return $true }
    if (-not (Test-Path -LiteralPath $stamp)) { return $true }
    $stampTime = (Get-Item -LiteralPath $stamp).LastWriteTimeUtc
    foreach ($dir in $codeDirs) {
        $full = Join-Path $root $dir
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $newer = Get-ChildItem -LiteralPath $full -Recurse -File -Filter '*.gd' |
            Where-Object { $_.LastWriteTimeUtc -gt $stampTime } |
            Select-Object -First 1
        if ($newer) { return $true }
    }
    return $false
}

if ($Import -or (Test-ImportNeeded)) {
    [Console]::Error.WriteLine('test.ps1: refreshing the Godot class cache (headless import)...')
    & $godotWrapper @('--headless', '--path', $root, '--import')
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("test.ps1: import failed with exit code $LASTEXITCODE")
        exit $LASTEXITCODE
    }
    New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
    Set-Content -LiteralPath $stamp -Value (Get-Date -Format o) -Encoding ascii
}

$godotArgs = @('--headless', '--path', $root, '--script', 'res://tests/run_tests.gd', '--')
if ($Filter) { $godotArgs += "--filter=$Filter" }
$godotArgs += $ExtraArgs

& $godotWrapper @godotArgs
exit $LASTEXITCODE
