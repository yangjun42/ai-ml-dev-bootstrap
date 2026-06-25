param(
    [Alias('Mode')]
    [ValidateSet('wsl','native')]
    [string]$Backend = 'wsl',
    [string]$Distro = 'Ubuntu-24.04',
    [string]$WslProject = '~/projects/ai-ml-starter',
    [string]$NativeProject = (Join-Path $HOME 'Projects\ai-ml-starter')
)

$ErrorActionPreference = 'Stop'

if ($Backend -eq 'native') {
    $python = Join-Path $NativeProject '.venv\Scripts\python.exe'
    if (-not (Test-Path $python)) { throw "Native project python not found: $python" }
    & $python (Join-Path $NativeProject 'scripts\check_env.py')
} else {
    wsl -d $Distro -- bash -lc "cd $WslProject && uv run python scripts/check_env.py"
}
