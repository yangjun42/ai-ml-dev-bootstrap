#requires -Version 5.1
<#
.SYNOPSIS
  Windows entrypoint. Defaults to WSL2 Ubuntu, or routes to native Windows AI/ML bootstrap with -Backend native.

.EXAMPLE
  .\scripts\bootstrap.ps1 -Profile personal
  .\scripts\bootstrap.ps1 -Backend native -Profile enterprise
  .\scripts\bootstrap.ps1 -Backend native -Profile enterprise -InstallRoot D:\AI -UseDefaults -AssumeYes
#>
param(
    [Alias('Mode')]
    [ValidateSet('wsl','native')]
    [string]$Backend = 'wsl',

    [ValidateSet('personal','enterprise')]
    [string]$Profile = 'personal',

    # Empty means backend/profile-aware defaults.
    [string[]]$Features = @(),

    [string]$Distro = 'Ubuntu-24.04',
    [string]$PythonVersion = '3.12',

    [ValidateSet('auto','cpu','cu118','cu126','cu128','cu130','xpu')]
    [string]$PytorchBackend = 'auto',

    [string]$ProjectDir = '',
    [string]$InstallRoot = '',
    [string]$MiniforgeDir = '',
    [string]$MiniforgeInstallerPath = '',
    [string]$ModelsDir = '',
    [string]$MlrunsDir = '',
    [string]$UvCacheDir = '',
    [string]$UvPythonInstallDir = '',
    [string]$UvToolDir = '',
    [string]$UvToolBinDir = '',
    [string]$UvInstallDir = '',
    [string]$WingetInstallLocation = '',

    [ValidateSet('progress','interactive','silent')]
    [string]$WingetMode = 'progress',

    [int]$WingetCheckTimeoutSec = 45,
    [int]$WingetInstallTimeoutSec = 1800,
    [switch]$SkipWingetInstalledCheck,
    [string]$WingetSource = 'winget',

    [string[]]$SkipPackages = @(),
    [string[]]$OnlyPackages = @(),

    [ValidateSet('prompt','reuse','backup','clean','fail')]
    [string]$ExistingInstallDirPolicy = 'prompt',

    [ValidateSet('prompt','merge','new','fail')]
    [string]$ExistingProjectPolicy = 'prompt',

    [switch]$ForceReinstallTools,

    [switch]$VerboseWinget,
    [switch]$InteractiveWinget,
    [switch]$SilentWinget,
    [switch]$UseDefaults,
    [switch]$NoLocationPrompts,
    [switch]$AssumeYes,
    [switch]$NoRemoteScripts,

    [string]$PytorchCudaIndex = 'https://download.pytorch.org/whl/cu130',

    # Only needed when you explicitly want nvcc / CUDA headers inside WSL.
    # PyTorch CUDA wheels do not require this. Example values: 12-9, 13-3.
    [string]$CudaToolkitVersion = '13-3',

    [switch]$SkipNvidiaPreflight,
    [switch]$SkipWSL,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

function Test-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Has-Feature([string]$Name) {
    return ($script:EffectiveFeatures -contains $Name) -or ($script:EffectiveFeatures -contains 'all')
}

function Invoke-Step([string]$Name, [scriptblock]$Script) {
    Write-Host "`n==> $Name" -ForegroundColor Cyan
    if ($DryRun) { return }
    & $Script
}

if ($Backend -eq 'native') {
    $NativeBootstrap = Join-Path $RepoRoot 'scripts\bootstrap-windows-native.ps1'
    if (-not (Test-Path $NativeBootstrap)) { throw "Native bootstrap not found: $NativeBootstrap" }
    $nativeArgs = @{
        Profile = $Profile
        Features = $Features
        PythonVersion = $PythonVersion
        PytorchBackend = $PytorchBackend
        ProjectDir = $ProjectDir
        InstallRoot = $InstallRoot
        MiniforgeDir = $MiniforgeDir
        ModelsDir = $ModelsDir
        MlrunsDir = $MlrunsDir
        UvCacheDir = $UvCacheDir
        UvPythonInstallDir = $UvPythonInstallDir
        UvToolDir = $UvToolDir
        UvToolBinDir = $UvToolBinDir
        UvInstallDir = $UvInstallDir
        WingetInstallLocation = $WingetInstallLocation
        WingetMode = $WingetMode
        WingetCheckTimeoutSec = $WingetCheckTimeoutSec
        WingetInstallTimeoutSec = $WingetInstallTimeoutSec
        WingetSource = $WingetSource
        SkipPackages = $SkipPackages
        OnlyPackages = $OnlyPackages
        ExistingInstallDirPolicy = $ExistingInstallDirPolicy
        ExistingProjectPolicy = $ExistingProjectPolicy
    }
    if ($MiniforgeInstallerPath) { $nativeArgs.MiniforgeInstallerPath = $MiniforgeInstallerPath }
    if ($SkipWingetInstalledCheck) { $nativeArgs.SkipWingetInstalledCheck = $true }
    if ($NoRemoteScripts) { $nativeArgs.NoRemoteScripts = $true }
    if ($SkipNvidiaPreflight) { $nativeArgs.SkipNvidiaPreflight = $true }
    if ($DryRun) { $nativeArgs.DryRun = $true }
    if ($VerboseWinget) { $nativeArgs.VerboseWinget = $true }
    if ($InteractiveWinget) { $nativeArgs.InteractiveWinget = $true }
    if ($SilentWinget) { $nativeArgs.SilentWinget = $true }
    if ($UseDefaults) { $nativeArgs.UseDefaults = $true }
    if ($NoLocationPrompts) { $nativeArgs.NoLocationPrompts = $true }
    if ($AssumeYes) { $nativeArgs.AssumeYes = $true }
    if ($ForceReinstallTools) { $nativeArgs.ForceReinstallTools = $true }
    & $NativeBootstrap @nativeArgs
    return
}

if (-not $Features -or $Features.Count -eq 0) {
    $script:EffectiveFeatures = @('core','ai','conda')
} else {
    $script:EffectiveFeatures = $Features
}
$FeatureCsv = ($script:EffectiveFeatures -join ',')

function Install-WingetPackage([string]$Id) {
    if (-not (Test-Command winget)) {
        Write-Warning 'winget not found. Install App Installer from Microsoft Store or use Windows 11 default App Installer.'
        return
    }
    $installed = winget list -e --id $Id 2>$null | Select-String -SimpleMatch $Id
    if ($installed) {
        Write-Host "winget package already installed: $Id"
        return
    }
    Write-Host "Installing $Id"
    winget install -e --id $Id --accept-source-agreements --accept-package-agreements --silent --disable-interactivity
}

if (Has-Feature 'core') {
    Invoke-Step 'Install Windows helper tools for WSL bootstrap' {
        $packages = @(
            'Microsoft.PowerShell',
            'Microsoft.WindowsTerminal',
            'Git.Git',
            'GitHub.cli',
            '7zip.7zip',
            'VSCodium.VSCodium'
        )
        foreach ($p in $packages) {
            try { Install-WingetPackage $p } catch { Write-Warning ("Skipped {0}: {1}" -f $p, $_.Exception.Message) }
        }
    }
}

if (Has-Feature 'containers') {
    Invoke-Step 'Install optional container desktop tools' {
        foreach ($p in @('RedHat.Podman-Desktop', 'SUSE.RancherDesktop')) {
            try { Install-WingetPackage $p } catch { Write-Warning ("Skipped {0}: {1}" -f $p, $_.Exception.Message) }
        }
    }
}

if (-not $SkipNvidiaPreflight) {
    Invoke-Step 'Preflight Windows NVIDIA driver and WSL2 GPU bridge' {
        $Preflight = Join-Path $RepoRoot 'scripts\preflight-windows-nvidia.ps1'
        if (Test-Path $Preflight) {
            & $Preflight -Distro $Distro
        }
    }
}

if (-not $SkipWSL) {
    Invoke-Step 'Ensure WSL2 Ubuntu is installed' {
        if (-not (Test-Command wsl)) {
            Write-Host 'Installing WSL. A reboot may be required; re-run this script after reboot if requested.'
            wsl --install -d $Distro
            if ($LASTEXITCODE -ne 0) {
                throw ("wsl --install failed with exit code {0}. Use native fallback: .\scripts\bootstrap.ps1 -Backend native -Profile {1}" -f $LASTEXITCODE, $Profile)
            }
        } else {
            try {
                wsl --update
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning ("wsl --update returned exit code {0}. Continuing without forcing WSL update." -f $LASTEXITCODE)
                    Write-Warning 'If distro install also fails, use: .\scripts\bootstrap.ps1 -Backend native'
                }
            } catch {
                Write-Warning ("wsl --update failed: {0}" -f $_.Exception.Message)
                Write-Warning 'Continuing without forcing WSL update. If distro install also fails, use: .\scripts\bootstrap.ps1 -Backend native'
            }
            try { wsl --set-default-version 2 } catch { Write-Warning ("wsl default version update failed: {0}" -f $_.Exception.Message) }
            $distros = (wsl -l -q) -replace "`0", ''
            if ($distros -notcontains $Distro) {
                Write-Host "Installing WSL distro $Distro. A reboot or first-launch user setup may be required."
                wsl --install -d $Distro
                if ($LASTEXITCODE -ne 0) {
                    throw ("wsl --install -d {0} failed with exit code {1}. Use native fallback: .\scripts\bootstrap.ps1 -Backend native -Profile {2}" -f $Distro, $LASTEXITCODE, $Profile)
                }
            }
        }
    }

    Invoke-Step 'Run Linux bootstrap inside WSL' {
        $RepoRootWsl = (wsl -d $Distro -- wslpath -a "$RepoRoot").Trim()
        $ScriptWsl = (wsl -d $Distro -- wslpath -a (Join-Path $RepoRoot 'scripts\bootstrap-wsl.sh')).Trim()
        wsl -d $Distro -- bash "$ScriptWsl" --profile "$Profile" --features "$FeatureCsv" --repo-root "$RepoRootWsl" --python "$PythonVersion" --pytorch-cuda-index "$PytorchCudaIndex" --cuda-toolkit-version "$CudaToolkitVersion"
    }
}

Write-Host "`nDone. In WSL: cd ~/projects/ai-ml-starter && uv run jupyter lab" -ForegroundColor Green
Write-Host "If WSL update/install is blocked on this workstation, run: .\scripts\bootstrap.ps1 -Backend native -Profile $Profile" -ForegroundColor Yellow
