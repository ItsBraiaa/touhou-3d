# Runs the project's Godot 4.7.2 console binary and forwards every argument unchanged.
#
# Resolution order: $env:GODOT_BIN, then the verified Downloads path below.
# Prints "Using Godot: <path>" to stderr once and exits with Godot's own exit code.
# Exit code 2 means no binary was found at either location.
#
# PowerShell prompts: PowerShell itself removes the first bare "--" from a direct .ps1
# call, so Godot user arguments need "-- --" there. tools/godot.cmd and tools/test.ps1
# forward "--" correctly.

$defaultGodot = 'C:\Users\Braia\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'

$godot = $null
if ($env:GODOT_BIN) {
    if (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf) {
        $godot = $env:GODOT_BIN
    } else {
        [Console]::Error.WriteLine("godot.ps1: GODOT_BIN is set but no file exists there: $env:GODOT_BIN")
    }
}
if (-not $godot -and (Test-Path -LiteralPath $defaultGodot -PathType Leaf)) {
    $godot = $defaultGodot
}
if (-not $godot) {
    $envShown = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { '(not set)' }
    [Console]::Error.WriteLine('godot.ps1: Godot binary not found. Looked at:')
    [Console]::Error.WriteLine("  1. GODOT_BIN environment variable: $envShown")
    [Console]::Error.WriteLine("  2. Default path: $defaultGodot")
    [Console]::Error.WriteLine('Set GODOT_BIN to a Godot 4.7.2 console executable or place it at the default path.')
    exit 2
}

[Console]::Error.WriteLine("Using Godot: $godot")
& $godot @args
exit $LASTEXITCODE
