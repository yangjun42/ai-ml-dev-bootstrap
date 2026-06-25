#requires -Version 5.1
<#
.SYNOPSIS
  Native Windows 11 AI/ML bootstrap without WSL.

.DESCRIPTION
  This entrypoint is for workstations where WSL cannot be installed or updated.
  It installs Windows developer tools, uv, an AI starter venv, optional Miniforge/mamba,
  optional MLsys tools, and optional native CUDA build prerequisites.

.EXAMPLE
  .\scripts\bootstrap-windows-native.ps1 -Profile personal
  .\scripts\bootstrap-windows-native.ps1 -Profile enterprise -Features core,ai,conda,mlsys
  .\scripts\bootstrap-windows-native.ps1 -Profile personal -Features core,ai,conda,native-build,cuda-toolkit-windows
#>
param(
    [ValidateSet('personal','enterprise')]
    [string]$Profile = 'personal',

    [string[]]$Features = @('core','ai','conda'),

    [string]$PythonVersion = '3.12',

    [ValidateSet('auto','cpu','cu118','cu126','cu128','cu130','xpu')]
    [string]$PytorchBackend = 'auto',

    [string]$ProjectDir = (Join-Path $HOME 'Projects\ai-ml-starter'),

    [string]$MiniforgeDir = (Join-Path $env:USERPROFILE 'miniforge3'),

    [string]$MiniforgeInstallerPath = '',

    [switch]$NoRemoteScripts,

    [switch]$SkipNvidiaPreflight,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

function Has-Feature([string]$Name) {
    return ($Features -contains $Name) -or ($Features -contains 'all')
}

function Test-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Step([string]$Name, [scriptblock]$Script) {
    Write-Host "`n==> $Name" -ForegroundColor Cyan
    if ($DryRun) { return }
    & $Script
}

function Install-WingetPackage([string]$Id, [string[]]$ExtraArgs = @()) {
    if (-not (Test-Command winget)) {
        Write-Warning 'winget not found. Install App Installer from Microsoft Store, or install packages manually.'
        return
    }

    $installed = winget list -e --id $Id 2>$null | Select-String -SimpleMatch $Id
    if ($installed) {
        Write-Host "winget package already installed: $Id"
        return
    }

    Write-Host "Installing $Id"
    $wingetArgs = @('install','-e','--id',$Id,'--accept-source-agreements','--accept-package-agreements','--silent','--disable-interactivity') + $ExtraArgs
    & winget @wingetArgs
}


function Set-UserEnvValue([string]$Name, [string]$Value) {
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Set-Item -Path "env:$Name" -Value $Value
}

function Apply-ProfileEnvironment() {
    $modelsDir = Join-Path $env:USERPROFILE 'Models\huggingface'
    $mlrunsDir = Join-Path $env:USERPROFILE 'mlruns'
    New-Item -ItemType Directory -Force -Path $modelsDir, $mlrunsDir, (Join-Path $env:USERPROFILE 'Data'), (Join-Path $env:USERPROFILE 'Models') | Out-Null

    $mlrunsUri = 'file:///' + ($mlrunsDir -replace '\\','/')
    Set-UserEnvValue 'AI_DEV_PROFILE' $Profile
    Set-UserEnvValue 'HF_HOME' $modelsDir
    Set-UserEnvValue 'MLFLOW_TRACKING_URI' $mlrunsUri
    Set-UserEnvValue 'TOKENIZERS_PARALLELISM' 'false'
    Set-UserEnvValue 'UV_LINK_MODE' 'copy'

    if ($Profile -eq 'enterprise') {
        Set-UserEnvValue 'HF_HUB_DISABLE_TELEMETRY' '1'
        Set-UserEnvValue 'DO_NOT_TRACK' '1'
        Set-UserEnvValue 'WANDB_MODE' 'offline'
    }

    $profileDir = Join-Path $env:USERPROFILE '.config\ai-ml-dev-bootstrap'
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    $profilePs1 = Join-Path $profileDir 'profile.ps1'
    $lines = @(
        "`$env:AI_DEV_PROFILE = '$Profile'",
        "`$env:HF_HOME = '$modelsDir'",
        "`$env:MLFLOW_TRACKING_URI = '$mlrunsUri'",
        "`$env:TOKENIZERS_PARALLELISM = 'false'",
        "`$env:UV_LINK_MODE = 'copy'"
    )
    if ($Profile -eq 'enterprise') {
        $lines += @(
            "`$env:HF_HUB_DISABLE_TELEMETRY = '1'",
            "`$env:DO_NOT_TRACK = '1'",
            "`$env:WANDB_MODE = 'offline'"
        )
    }
    Set-Content -Path $profilePs1 -Value $lines -Encoding UTF8
}

function Install-Uv() {
    if (Test-Command uv) {
        Write-Host "uv already available: $((Get-Command uv).Source)"
        return
    }
    try {
        Install-WingetPackage 'astral-sh.uv'
    } catch {
        Write-Warning ("winget uv install failed: {0}" -f $_.Exception.Message)
    }
    if (-not (Test-Command uv)) {
        if ($Profile -eq 'enterprise' -or $NoRemoteScripts) {
            throw 'uv is not installed. In enterprise/no-remote-scripts mode, install uv through an approved package source, then re-run.'
        }
        Write-Host 'Installing uv with the official standalone installer.'
        powershell -ExecutionPolicy ByPass -NoProfile -Command "irm https://astral.sh/uv/install.ps1 | iex"
        $uvBin = Join-Path $HOME '.local\bin'
        if (Test-Path $uvBin) { $env:Path = "$uvBin;$env:Path" }
    }
    if (-not (Test-Command uv)) { throw 'uv installation failed or uv is not on PATH.' }
}


function Copy-StarterProject() {
    $template = Join-Path $RepoRoot 'templates\ai-starter'
    if (-not (Test-Path $template)) { throw "Template project not found: $template" }

    if (-not (Test-Path $ProjectDir)) {
        New-Item -ItemType Directory -Force -Path $ProjectDir | Out-Null
        Copy-Item -Path (Join-Path $template '*') -Destination $ProjectDir -Recurse -Force
    } else {
        Write-Host "Project directory already exists: $ProjectDir"
        $marker = Join-Path $ProjectDir 'pyproject.toml'
        if (-not (Test-Path $marker)) {
            Copy-Item -Path (Join-Path $template '*') -Destination $ProjectDir -Recurse -Force
        }
    }

    $profileFile = Join-Path $RepoRoot "profiles\$Profile.env"
    if (Test-Path $profileFile) {
        Copy-Item $profileFile (Join-Path $ProjectDir '.env.profile') -Force
    }
}

function Invoke-UvPip([string[]]$ArgList) {
    $pythonExe = Join-Path $ProjectDir '.venv\Scripts\python.exe'
    if (-not (Test-Path $pythonExe)) { throw "Python executable not found: $pythonExe" }
    & uv pip install --python $pythonExe @ArgList
}

function Install-RequirementsFile([string]$RelativePath) {
    $req = Join-Path $ProjectDir $RelativePath
    if (Test-Path $req) {
        Invoke-UvPip -ArgList @('-r', $req)
    } else {
        Write-Warning "Requirements file not found: $req"
    }
}

function Install-NativeCondaEnv() {
    $installer = Join-Path $RepoRoot 'scripts\install-miniforge-windows.ps1'
    & $installer -InstallDir $MiniforgeDir -InstallerPath $MiniforgeInstallerPath -NoRemoteScripts:$NoRemoteScripts

    $mamba = Get-Command mamba -ErrorAction SilentlyContinue
    if (-not $mamba) { throw 'mamba not found after Miniforge installation.' }

    $envFile = Join-Path $RepoRoot 'envs\ai-native-windows.yml'
    if (-not (Test-Path $envFile)) { throw "Conda env file not found: $envFile" }

    $existing = (& mamba env list) -join "`n"
    if ($existing -match 'ai-native-win') {
        & mamba env update -n ai-native-win -f $envFile
    } else {
        & mamba env create -f $envFile
    }
}

if (Has-Feature 'core') {
    Invoke-Step 'Install Windows desktop developer tools' {
        $packages = @(
            'Microsoft.PowerShell',
            'Microsoft.WindowsTerminal',
            'Git.Git',
            'GitHub.cli',
            '7zip.7zip',
            'VSCodium.VSCodium',
            'Kitware.CMake'
        )
        foreach ($p in $packages) {
            try { Install-WingetPackage $p } catch { Write-Warning ("Skipped {0}: {1}" -f $p, $_.Exception.Message) }
        }
        try { Install-WingetPackage 'Ninja-build.Ninja' } catch { Write-Warning ("Skipped {0}: {1}" -f 'Ninja-build.Ninja', $_.Exception.Message) }
        Install-Uv
        Apply-ProfileEnvironment
    }
}

if (-not $SkipNvidiaPreflight) {
    Invoke-Step 'Preflight native Windows NVIDIA/CUDA state' {
        $preflight = Join-Path $RepoRoot 'scripts\preflight-windows-native.ps1'
        if (Test-Path $preflight) { & $preflight }
    }
}

if (Has-Feature 'native-build') {
    Invoke-Step 'Install optional native build toolchain' {
        # Visual Studio Build Tools / MSVC are proprietary, but they are the supported Windows toolchain
        # for many CUDA and PyTorch extension builds. Keep this feature opt-in.
        try { Install-WingetPackage 'Microsoft.VisualStudio.2022.BuildTools' } catch { Write-Warning ("Skipped {0}: {1}" -f 'Microsoft.VisualStudio.2022.BuildTools', $_.Exception.Message) }
    }
}

if (Has-Feature 'cuda-toolkit-windows') {
    Invoke-Step 'Install optional NVIDIA CUDA Toolkit for Windows' {
        # Only needed for nvcc, CUDA samples, or native CUDA extension compilation.
        try { Install-WingetPackage 'Nvidia.CUDA' } catch { Write-Warning ("Skipped {0}: {1}" -f 'Nvidia.CUDA', $_.Exception.Message) }
    }
}

if (Has-Feature 'containers') {
    Invoke-Step 'Install optional container desktop tools' {
        foreach ($p in @('RedHat.Podman-Desktop','SUSE.RancherDesktop')) {
            try { Install-WingetPackage $p } catch { Write-Warning ("Skipped {0}: {1}" -f $p, $_.Exception.Message) }
        }
    }
}

if (Has-Feature 'conda') {
    Invoke-Step 'Install Miniforge/mamba and native conda fallback env' {
        Install-NativeCondaEnv
    }
}

if (Has-Feature 'ai') {
    Invoke-Step 'Create native Windows uv AI starter environment' {
        Apply-ProfileEnvironment
        Copy-StarterProject
        Push-Location $ProjectDir
        try {
            & uv python install $PythonVersion
            & uv venv --python $PythonVersion .venv

            # Use uv's PyTorch backend detection by default. It queries installed GPU drivers and
            # chooses the most compatible PyTorch index, falling back to CPU when needed.
            if ($PytorchBackend -eq 'cpu') {
                Invoke-UvPip -ArgList @('torch','torchvision','torchaudio','--index-url','https://download.pytorch.org/whl/cpu')
            } else {
                Invoke-UvPip -ArgList @('torch','torchvision','torchaudio',"--torch-backend=$PytorchBackend")
            }

            Install-RequirementsFile 'requirements\base.txt'
            Install-RequirementsFile 'requirements\dev.txt'
            Install-RequirementsFile 'requirements\llm.txt'
            Install-RequirementsFile "requirements\$Profile.txt"
            if (Has-Feature 'mlsys') { Install-RequirementsFile 'requirements\mlsys.txt' }
            if (Has-Feature 'windows-cuda-extras') { Install-RequirementsFile 'requirements\windows-cuda-extras.txt' }

            $pythonExe = Join-Path $ProjectDir '.venv\Scripts\python.exe'
            & $pythonExe (Join-Path $ProjectDir 'scripts\check_env.py')
        } finally {
            Pop-Location
        }
    }
}

Write-Host "`nDone." -ForegroundColor Green
Write-Host "Project: $ProjectDir"
Write-Host 'Start:'
Write-Host "  cd `"$ProjectDir`""
Write-Host '  .\.venv\Scripts\Activate.ps1'
Write-Host '  python scripts\check_env.py'
Write-Host '  jupyter lab'
