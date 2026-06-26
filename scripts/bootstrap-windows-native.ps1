#requires -Version 5.1
<#
.SYNOPSIS
  Native Windows 11 AI/ML bootstrap without WSL.

.DESCRIPTION
  This entrypoint is for workstations where WSL cannot be installed or updated.
  It uses a uv-first Python environment, optional Miniforge/mamba fallback, and
  optional Windows build/CUDA/container tooling. The default native feature set is
  intentionally small; add features when needed.

.EXAMPLE
  .\scripts\bootstrap-windows-native.ps1 -Profile enterprise
  .\scripts\bootstrap-windows-native.ps1 -Profile enterprise -Features minimal,ai,conda
  .\scripts\bootstrap-windows-native.ps1 -Profile personal -Features minimal,ai,vcs,editor,build,conda,mlsys
  .\scripts\bootstrap-windows-native.ps1 -Profile personal -InstallRoot D:\AI -WingetMode interactive
#>
param(
    [ValidateSet('personal','enterprise')]
    [string]$Profile = 'personal',

    # Empty means profile-aware default:
    #   enterprise -> minimal,ai
    #   personal   -> minimal,ai,vcs,editor,build,conda
    # Backward compatible alias: core -> minimal,desktop,vcs,editor,build
    [string[]]$Features = @(),

    [string]$PythonVersion = '3.12',

    [ValidateSet('auto','cpu','cu118','cu126','cu128','cu130','xpu')]
    [string]$PytorchBackend = 'auto',

    # Central root for project/caches/tools that can be placed outside C:\Users.
    # If omitted, the script offers an interactive prompt unless -UseDefaults or -NoLocationPrompts is supplied.
    [string]$InstallRoot = '',

    [string]$ProjectDir = '',
    [string]$MiniforgeDir = '',
    [string]$MiniforgeInstallerPath = '',
    [string]$ModelsDir = '',
    [string]$MlrunsDir = '',
    [string]$UvCacheDir = '',
    [string]$UvPythonInstallDir = '',
    [string]$UvToolDir = '',
    [string]$UvToolBinDir = '',
    [string]$UvInstallDir = '',

    # Optional common winget install location. WinGet passes --location only when a package supports it.
    # Some installers ignore or reject it; the script retries once without --location if that happens.
    [string]$WingetInstallLocation = '',

    [ValidateSet('progress','interactive','silent')]
    [string]$WingetMode = 'progress',

    # Backward-compatible switches from older template revisions.
    [switch]$VerboseWinget,
    [switch]$InteractiveWinget,
    [switch]$SilentWinget,

    [string[]]$SkipPackages = @(),
    [string[]]$OnlyPackages = @(),

    [switch]$NoRemoteScripts,
    [switch]$SkipNvidiaPreflight,
    [switch]$UseDefaults,
    [switch]$NoLocationPrompts,
    [switch]$AssumeYes,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$script:WingetVerboseLogs = $true

if ($InteractiveWinget) { $WingetMode = 'interactive' }
if ($SilentWinget) { $WingetMode = 'silent' }

function Test-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-InteractiveSession() {
    try {
        return [Environment]::UserInteractive -and ($null -ne $Host) -and ($null -ne $Host.UI)
    } catch {
        return $false
    }
}

function Expand-PathValue([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    return [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
}

function Read-PathChoice([string]$Label, [string]$DefaultValue, [bool]$WasProvided) {
    $DefaultValue = Expand-PathValue $DefaultValue
    if ($WasProvided -or $UseDefaults -or $NoLocationPrompts -or -not (Test-InteractiveSession)) {
        return $DefaultValue
    }
    Write-Host "`n$Label" -ForegroundColor Yellow
    Write-Host "  Default: $DefaultValue"
    Write-Host '  Press Enter to keep default, or type a custom absolute path.'
    $answer = Read-Host '  Path'
    if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultValue }
    return Expand-PathValue $answer
}

function Confirm-Plan() {
    if ($AssumeYes -or $UseDefaults -or $DryRun -or -not (Test-InteractiveSession)) { return }
    Write-Host ''
    $answer = Read-Host 'Proceed with this plan? [Y/n]'
    if ($answer -match '^(n|no)$') {
        throw 'User cancelled bootstrap.'
    }
}

function Invoke-Step([string]$Name, [scriptblock]$Script) {
    Write-Host "`n==> $Name" -ForegroundColor Cyan
    if ($DryRun) { return }
    & $Script
}

function Set-UserEnvValue([string]$Name, [string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Set-Item -Path "env:$Name" -Value $Value
}

function Normalize-Features([string[]]$InputFeatures) {
    if (-not $InputFeatures -or $InputFeatures.Count -eq 0) {
        if ($Profile -eq 'enterprise') {
            $InputFeatures = @('minimal','ai')
        } else {
            $InputFeatures = @('minimal','ai','vcs','editor','build','conda')
        }
    }

    $out = New-Object 'System.Collections.Generic.List[string]'
    foreach ($feature in $InputFeatures) {
        if ([string]::IsNullOrWhiteSpace($feature)) { continue }
        foreach ($part in ($feature -split ',')) {
            $f = $part.Trim().ToLowerInvariant()
            if (-not $f) { continue }
            switch ($f) {
                'core' {
                    foreach ($alias in @('minimal','desktop','vcs','editor','build')) { $out.Add($alias) }
                }
                'all' {
                    foreach ($alias in @('minimal','desktop','vcs','editor','build','ai','conda','mlsys','containers','native-build','cuda-toolkit-windows','windows-cuda-extras')) { $out.Add($alias) }
                }
                default { $out.Add($f) }
            }
        }
    }

    return @($out | Select-Object -Unique)
}

$Features = Normalize-Features $Features

function Has-Feature([string]$Name) {
    return $Features -contains $Name.ToLowerInvariant()
}

function Test-PackageSelected([string]$Id) {
    if ($SkipPackages -contains $Id) {
        Write-Host "Skipping $Id because it is listed in -SkipPackages."
        return $false
    }
    if ($OnlyPackages -and $OnlyPackages.Count -gt 0 -and -not ($OnlyPackages -contains $Id)) {
        Write-Host "Skipping $Id because it is not listed in -OnlyPackages."
        return $false
    }
    return $true
}

function Test-AnyCommand([string[]]$Names) {
    foreach ($name in $Names) {
        if ($name -and (Test-Command $name)) {
            Write-Host "Command already available: $name -> $((Get-Command $name).Source)"
            return $true
        }
    }
    return $false
}

function Test-VSBuildToolsInstalled() {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) { return $false }
    $path = & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null | Select-Object -First 1
    if ($path) {
        Write-Host "Visual Studio C++ build tools already found: $path"
        return $true
    }
    return $false
}

function Invoke-WingetInstall([string[]]$ArgsForWinget) {
    Write-Host ("  command: winget {0}" -f ($ArgsForWinget -join ' '))
    & winget @ArgsForWinget
    return $LASTEXITCODE
}

function Install-WingetPackage(
    [string]$Id,
    [string[]]$Commands = @(),
    [switch]$SupportsLocation,
    [string[]]$ExtraArgs = @()
) {
    if (-not (Test-PackageSelected $Id)) { return }

    if ($Commands -and (Test-AnyCommand $Commands)) {
        Write-Host "Skipping winget package because command already exists: $Id"
        return
    }

    if (-not (Test-Command winget)) {
        Write-Warning 'winget not found. Install App Installer from Microsoft Store, or install packages manually.'
        return
    }

    Write-Host "Checking winget package: $Id"
    $installed = winget list -e --id $Id 2>$null | Select-String -SimpleMatch $Id
    if ($installed) {
        Write-Host "winget package already installed: $Id"
        return
    }

    $logRoot = Join-Path $env:TEMP 'ai-ml-dev-bootstrap\winget-logs'
    New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
    $safeId = $Id -replace '[^A-Za-z0-9_.-]', '_'
    $logFile = Join-Path $logRoot ("{0}-{1}.log" -f $safeId, (Get-Date -Format 'yyyyMMdd-HHmmss'))

    Write-Host "Installing $Id" -ForegroundColor Green
    Write-Host "  winget mode: $WingetMode"
    Write-Host "  winget log:  $logFile"

    $baseArgs = @(
        'install','-e','--id',$Id,
        '--accept-source-agreements','--accept-package-agreements',
        '--log',$logFile
    )

    # Keep verbose logs enabled by default. The old -VerboseWinget switch remains accepted.
    if ($script:WingetVerboseLogs -or $VerboseWinget) { $baseArgs += '--verbose-logs' }

    switch ($WingetMode) {
        'interactive' { $baseArgs += '--interactive' }
        'silent' { $baseArgs += @('--silent','--disable-interactivity') }
        default { }
    }

    $baseArgs += $ExtraArgs

    $argsWithLocation = $baseArgs
    $usedLocation = $false
    if ($SupportsLocation -and -not [string]::IsNullOrWhiteSpace($WingetInstallLocation)) {
        $argsWithLocation += @('--location', $WingetInstallLocation)
        $usedLocation = $true
        Write-Host "  requested location: $WingetInstallLocation"
        Write-Host '  note: WinGet/installer may ignore or reject --location if unsupported.' -ForegroundColor DarkYellow
    }

    $exitCode = Invoke-WingetInstall $argsWithLocation
    if ($exitCode -ne 0 -and $usedLocation) {
        Write-Warning "winget install for $Id failed with --location. Retrying once without --location."
        $exitCode = Invoke-WingetInstall $baseArgs
    }

    if ($exitCode -ne 0) {
        throw "winget install failed for $Id with exit code $exitCode. Log: $logFile"
    }
}


function Select-Default([string]$Value, [string]$DefaultValue) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $DefaultValue }
    return $Value
}

function Resolve-InstallLocations() {
    $defaultRoot = Join-Path $env:USERPROFILE 'ai-ml-dev'
    $script:InstallRoot = Read-PathChoice 'Choose central AI/ML install/cache root.' (Select-Default $InstallRoot $defaultRoot) ($PSBoundParameters.ContainsKey('InstallRoot') -and $InstallRoot)

    if ([string]::IsNullOrWhiteSpace($script:InstallRoot)) { $script:InstallRoot = $defaultRoot }
    $script:InstallRoot = Expand-PathValue $script:InstallRoot

    $script:ProjectDir = Read-PathChoice 'Choose starter project directory.' (Select-Default $ProjectDir (Join-Path $script:InstallRoot 'Projects\ai-ml-starter')) ($PSBoundParameters.ContainsKey('ProjectDir') -and $ProjectDir)
    $script:MiniforgeDir = Read-PathChoice 'Choose Miniforge install directory.' (Select-Default $MiniforgeDir (Join-Path $script:InstallRoot 'miniforge3')) ($PSBoundParameters.ContainsKey('MiniforgeDir') -and $MiniforgeDir)
    $script:ModelsDir = Read-PathChoice 'Choose Hugging Face/model cache directory.' (Select-Default $ModelsDir (Join-Path $script:InstallRoot 'Models\huggingface')) ($PSBoundParameters.ContainsKey('ModelsDir') -and $ModelsDir)
    $script:MlrunsDir = Read-PathChoice 'Choose local MLflow runs directory.' (Select-Default $MlrunsDir (Join-Path $script:InstallRoot 'mlruns')) ($PSBoundParameters.ContainsKey('MlrunsDir') -and $MlrunsDir)
    $script:UvCacheDir = Read-PathChoice 'Choose uv package cache directory.' (Select-Default $UvCacheDir (Join-Path $script:InstallRoot 'uv-cache')) ($PSBoundParameters.ContainsKey('UvCacheDir') -and $UvCacheDir)
    $script:UvPythonInstallDir = Read-PathChoice 'Choose uv-managed Python install directory.' (Select-Default $UvPythonInstallDir (Join-Path $script:InstallRoot 'uv-python')) ($PSBoundParameters.ContainsKey('UvPythonInstallDir') -and $UvPythonInstallDir)
    $script:UvToolDir = Read-PathChoice 'Choose uv tool storage directory.' (Select-Default $UvToolDir (Join-Path $script:InstallRoot 'uv-tools')) ($PSBoundParameters.ContainsKey('UvToolDir') -and $UvToolDir)
    $script:UvToolBinDir = Read-PathChoice 'Choose uv tool executable directory.' (Select-Default $UvToolBinDir (Join-Path $script:InstallRoot 'uv-tools-bin')) ($PSBoundParameters.ContainsKey('UvToolBinDir') -and $UvToolBinDir)
    $script:UvInstallDir = Read-PathChoice 'Choose uv standalone installer directory, used only if winget uv is unavailable.' (Select-Default $UvInstallDir (Join-Path $script:InstallRoot 'uv-bin')) ($PSBoundParameters.ContainsKey('UvInstallDir') -and $UvInstallDir)

    if (-not [string]::IsNullOrWhiteSpace($WingetInstallLocation)) {
        $script:WingetInstallLocation = Expand-PathValue $WingetInstallLocation
    } elseif (-not ($UseDefaults -or $NoLocationPrompts) -and (Test-InteractiveSession)) {
        Write-Host "`nOptional: choose a common WinGet install location." -ForegroundColor Yellow
        Write-Host '  Leave blank to let each installer choose its default location.'
        Write-Host '  Some packages do not support --location; if they reject it, the script retries without it.'
        $answer = Read-Host '  WinGet install location'
        $script:WingetInstallLocation = Expand-PathValue $answer
    } else {
        $script:WingetInstallLocation = ''
    }

    foreach ($dir in @($script:InstallRoot,$script:ProjectDir,$script:ModelsDir,$script:MlrunsDir,$script:UvCacheDir,$script:UvPythonInstallDir,$script:UvToolDir,$script:UvToolBinDir,$script:UvInstallDir)) {
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
    }
}

function Show-BootstrapPlan() {
    Write-Host "`nNative Windows AI/ML bootstrap plan" -ForegroundColor Cyan
    Write-Host "  Profile:        $Profile"
    Write-Host "  Features:       $($Features -join ',')"
    Write-Host "  Winget mode:    $WingetMode"
    Write-Host "  Install root:   $script:InstallRoot"
    Write-Host "  Project dir:    $script:ProjectDir"
    Write-Host "  Miniforge dir:  $script:MiniforgeDir"
    Write-Host "  Models dir:     $script:ModelsDir"
    Write-Host "  MLflow dir:     $script:MlrunsDir"
    Write-Host "  uv cache:       $script:UvCacheDir"
    Write-Host "  uv Python dir:  $script:UvPythonInstallDir"
    if (-not [string]::IsNullOrWhiteSpace($script:WingetInstallLocation)) {
        Write-Host "  WinGet location:$script:WingetInstallLocation"
    } else {
        Write-Host '  WinGet location:<installer default>'
    }
    Write-Host ''
    Write-Host 'Feature notes:' -ForegroundColor DarkCyan
    Write-Host '  minimal: uv + local AI/ML environment variables only.'
    Write-Host '  ai:      creates the starter project and .venv, installs PyTorch/HF/scientific packages.'
    Write-Host '  conda:   installs Miniforge/mamba fallback environment.'
    Write-Host '  vcs/editor/desktop/build/native-build/cuda-toolkit-windows/containers are opt-in.'
}

function Apply-ProfileEnvironment() {
    New-Item -ItemType Directory -Force -Path $script:ModelsDir, $script:MlrunsDir, $script:UvCacheDir, $script:UvPythonInstallDir, $script:UvToolDir, $script:UvToolBinDir | Out-Null

    $mlrunsUri = 'file:///' + ($script:MlrunsDir -replace '\\','/')
    Set-UserEnvValue 'AI_DEV_PROFILE' $Profile
    Set-UserEnvValue 'HF_HOME' $script:ModelsDir
    Set-UserEnvValue 'MLFLOW_TRACKING_URI' $mlrunsUri
    Set-UserEnvValue 'TOKENIZERS_PARALLELISM' 'false'
    Set-UserEnvValue 'UV_LINK_MODE' 'copy'
    Set-UserEnvValue 'UV_CACHE_DIR' $script:UvCacheDir
    Set-UserEnvValue 'UV_PYTHON_INSTALL_DIR' $script:UvPythonInstallDir
    Set-UserEnvValue 'UV_TOOL_DIR' $script:UvToolDir
    Set-UserEnvValue 'UV_TOOL_BIN_DIR' $script:UvToolBinDir
    Set-UserEnvValue 'UV_INSTALL_DIR' $script:UvInstallDir

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
        "`$env:HF_HOME = '$script:ModelsDir'",
        "`$env:MLFLOW_TRACKING_URI = '$mlrunsUri'",
        "`$env:TOKENIZERS_PARALLELISM = 'false'",
        "`$env:UV_LINK_MODE = 'copy'",
        "`$env:UV_CACHE_DIR = '$script:UvCacheDir'",
        "`$env:UV_PYTHON_INSTALL_DIR = '$script:UvPythonInstallDir'",
        "`$env:UV_TOOL_DIR = '$script:UvToolDir'",
        "`$env:UV_TOOL_BIN_DIR = '$script:UvToolBinDir'",
        "`$env:UV_INSTALL_DIR = '$script:UvInstallDir'"
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
    Apply-ProfileEnvironment
    if (Test-Command uv) {
        Write-Host "uv already available: $((Get-Command uv).Source)"
        return
    }
    try {
        Install-WingetPackage -Id 'astral-sh.uv' -Commands @('uv') -SupportsLocation
    } catch {
        Write-Warning ("winget uv install failed: {0}" -f $_.Exception.Message)
    }
    if (-not (Test-Command uv)) {
        if ($Profile -eq 'enterprise' -or $NoRemoteScripts) {
            throw 'uv is not installed. In enterprise/no-remote-scripts mode, install uv through an approved package source, then re-run.'
        }
        Write-Host 'Installing uv with the official standalone installer.'
        New-Item -ItemType Directory -Force -Path $script:UvInstallDir | Out-Null
        $env:UV_INSTALL_DIR = $script:UvInstallDir
        powershell -ExecutionPolicy ByPass -NoProfile -Command "irm https://astral.sh/uv/install.ps1 | iex"
        if (Test-Path $script:UvInstallDir) { $env:Path = "$script:UvInstallDir;$env:Path" }
    }
    if (-not (Test-Command uv)) { throw 'uv installation failed or uv is not on PATH.' }
}

function Copy-StarterProject() {
    $template = Join-Path $RepoRoot 'templates\ai-starter'
    if (-not (Test-Path $template)) { throw "Template project not found: $template" }

    if (-not (Test-Path $script:ProjectDir)) {
        New-Item -ItemType Directory -Force -Path $script:ProjectDir | Out-Null
        Copy-Item -Path (Join-Path $template '*') -Destination $script:ProjectDir -Recurse -Force
    } else {
        Write-Host "Project directory already exists: $script:ProjectDir"
        $marker = Join-Path $script:ProjectDir 'pyproject.toml'
        if (-not (Test-Path $marker)) {
            Copy-Item -Path (Join-Path $template '*') -Destination $script:ProjectDir -Recurse -Force
        }
    }

    $profileFile = Join-Path $RepoRoot "profiles\$Profile.env"
    if (Test-Path $profileFile) {
        Copy-Item $profileFile (Join-Path $script:ProjectDir '.env.profile') -Force
    }
}

function Invoke-UvPip([string[]]$ArgList) {
    $pythonExe = Join-Path $script:ProjectDir '.venv\Scripts\python.exe'
    if (-not (Test-Path $pythonExe)) { throw "Python executable not found: $pythonExe" }
    & uv pip install --python $pythonExe @ArgList
    if ($LASTEXITCODE -ne 0) { throw "uv pip install failed with exit code $LASTEXITCODE" }
}

function Install-RequirementsFile([string]$RelativePath) {
    $req = Join-Path $script:ProjectDir $RelativePath
    if (Test-Path $req) {
        Invoke-UvPip -ArgList @('-r', $req)
    } else {
        Write-Warning "Requirements file not found: $req"
    }
}

function Install-NativeCondaEnv() {
    $installer = Join-Path $RepoRoot 'scripts\install-miniforge-windows.ps1'
    & $installer -InstallDir $script:MiniforgeDir -InstallerPath $MiniforgeInstallerPath -NoRemoteScripts:$NoRemoteScripts -DryRun:$DryRun

    $mambaExe = Join-Path $script:MiniforgeDir 'Scripts\mamba.exe'
    $condaExe = Join-Path $script:MiniforgeDir 'Scripts\conda.exe'
    if (Test-Path $mambaExe) {
        $mamba = $mambaExe
    } elseif (Test-Command mamba) {
        $mamba = (Get-Command mamba).Source
    } elseif (Test-Path $condaExe) {
        throw 'Miniforge installed but mamba.exe was not found. Use conda manually or reinstall Miniforge.'
    } else {
        throw 'mamba not found after Miniforge installation.'
    }

    $envFile = Join-Path $RepoRoot 'envs\ai-native-windows.yml'
    if (-not (Test-Path $envFile)) { throw "Conda env file not found: $envFile" }

    $existing = (& $mamba env list) -join "`n"
    if ($existing -match 'ai-native-win') {
        & $mamba env update -n ai-native-win -f $envFile
    } else {
        & $mamba env create -f $envFile
    }
    if ($LASTEXITCODE -ne 0) { throw "mamba env create/update failed with exit code $LASTEXITCODE" }
}

Resolve-InstallLocations
Show-BootstrapPlan
Confirm-Plan

if (Has-Feature 'minimal') {
    Invoke-Step 'Install minimal Python tooling: uv and AI/ML environment variables' {
        Install-Uv
        Apply-ProfileEnvironment
    }
}

if (Has-Feature 'desktop') {
    Invoke-Step 'Install optional desktop utilities' {
        foreach ($pkg in @(
            @{ Id='Microsoft.PowerShell'; Commands=@('pwsh'); SupportsLocation=$true },
            @{ Id='Microsoft.WindowsTerminal'; Commands=@('wt'); SupportsLocation=$false },
            @{ Id='7zip.7zip'; Commands=@('7z','7zz'); SupportsLocation=$true }
        )) {
            $supportsLocation = [bool]$pkg.SupportsLocation
            try { Install-WingetPackage -Id $pkg.Id -Commands $pkg.Commands -SupportsLocation:$supportsLocation } catch { Write-Warning ("Skipped {0}: {1}" -f $pkg.Id, $_.Exception.Message) }
        }
    }
}

if (Has-Feature 'vcs') {
    Invoke-Step 'Install optional version-control tools' {
        foreach ($pkg in @(
            @{ Id='Git.Git'; Commands=@('git'); SupportsLocation=$true },
            @{ Id='GitHub.cli'; Commands=@('gh'); SupportsLocation=$true }
        )) {
            $supportsLocation = [bool]$pkg.SupportsLocation
            try { Install-WingetPackage -Id $pkg.Id -Commands $pkg.Commands -SupportsLocation:$supportsLocation } catch { Write-Warning ("Skipped {0}: {1}" -f $pkg.Id, $_.Exception.Message) }
        }
    }
}

if (Has-Feature 'editor') {
    Invoke-Step 'Install optional editor' {
        try { Install-WingetPackage -Id 'VSCodium.VSCodium' -Commands @('codium','code') -SupportsLocation } catch { Write-Warning ("Skipped {0}: {1}" -f 'VSCodium.VSCodium', $_.Exception.Message) }
    }
}

if (Has-Feature 'build') {
    Invoke-Step 'Install optional CMake/Ninja build helpers' {
        foreach ($pkg in @(
            @{ Id='Kitware.CMake'; Commands=@('cmake'); SupportsLocation=$true },
            @{ Id='Ninja-build.Ninja'; Commands=@('ninja'); SupportsLocation=$true }
        )) {
            $supportsLocation = [bool]$pkg.SupportsLocation
            try { Install-WingetPackage -Id $pkg.Id -Commands $pkg.Commands -SupportsLocation:$supportsLocation } catch { Write-Warning ("Skipped {0}: {1}" -f $pkg.Id, $_.Exception.Message) }
        }
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
        if (Test-VSBuildToolsInstalled) {
            Write-Host 'Skipping Visual Studio Build Tools installation.'
        } else {
            try { Install-WingetPackage -Id 'Microsoft.VisualStudio.2022.BuildTools' -SupportsLocation } catch { Write-Warning ("Skipped {0}: {1}" -f 'Microsoft.VisualStudio.2022.BuildTools', $_.Exception.Message) }
        }
    }
}

if (Has-Feature 'cuda-toolkit-windows') {
    Invoke-Step 'Install optional NVIDIA CUDA Toolkit for Windows' {
        try { Install-WingetPackage -Id 'Nvidia.CUDA' -Commands @('nvcc') -SupportsLocation } catch { Write-Warning ("Skipped {0}: {1}" -f 'Nvidia.CUDA', $_.Exception.Message) }
    }
}

if (Has-Feature 'containers') {
    Invoke-Step 'Install optional container desktop tools' {
        foreach ($pkg in @(
            @{ Id='RedHat.Podman-Desktop'; Commands=@('podman-desktop'); SupportsLocation=$true },
            @{ Id='SUSE.RancherDesktop'; Commands=@('rdctl'); SupportsLocation=$true }
        )) {
            $supportsLocation = [bool]$pkg.SupportsLocation
            try { Install-WingetPackage -Id $pkg.Id -Commands $pkg.Commands -SupportsLocation:$supportsLocation } catch { Write-Warning ("Skipped {0}: {1}" -f $pkg.Id, $_.Exception.Message) }
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
        Install-Uv
        Apply-ProfileEnvironment
        Copy-StarterProject
        Push-Location $script:ProjectDir
        try {
            & uv python install $PythonVersion
            if ($LASTEXITCODE -ne 0) { throw "uv python install failed with exit code $LASTEXITCODE" }
            & uv venv --python $PythonVersion .venv
            if ($LASTEXITCODE -ne 0) { throw "uv venv failed with exit code $LASTEXITCODE" }

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

            $pythonExe = Join-Path $script:ProjectDir '.venv\Scripts\python.exe'
            & $pythonExe (Join-Path $script:ProjectDir 'scripts\check_env.py')
        } finally {
            Pop-Location
        }
    }
}

Write-Host "`nDone." -ForegroundColor Green
Write-Host "Project: $script:ProjectDir"
Write-Host 'Start:'
Write-Host "  cd `"$script:ProjectDir`""
Write-Host '  .\.venv\Scripts\Activate.ps1'
Write-Host '  python scripts\check_env.py'
Write-Host '  jupyter lab'
