#requires -Version 5.1
<#
.SYNOPSIS
  Install Miniforge3 for Windows, then make mamba/conda available to the current process.

.DESCRIPTION
  This helper is intentionally idempotent. If the target directory already contains
  a complete Miniforge installation, it reuses it. If the directory is non-empty
  but incomplete, it can prompt, move the directory aside, clean it, or fail based
  on -ExistingDirPolicy.
#>
param(
    [string]$InstallDir = (Join-Path $env:USERPROFILE 'miniforge3'),
    [string]$InstallerPath = '',

    [ValidateSet('prompt','reuse','backup','clean','fail')]
    [string]$ExistingDirPolicy = 'prompt',

    [switch]$NoRemoteScripts,
    [switch]$Force,
    [switch]$AssumeYes,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$InstallDir = [Environment]::ExpandEnvironmentVariables($InstallDir.Trim().Trim('"'))

function Test-InteractiveSession() {
    try {
        return [Environment]::UserInteractive -and ($null -ne $Host) -and ($null -ne $Host.UI)
    } catch {
        return $false
    }
}

function Test-PathNonEmpty([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $true }
    $item = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    return $null -ne $item
}

function Test-Mamba([string]$Root) {
    $mamba = Join-Path $Root 'Scripts\mamba.exe'
    return Test-Path -LiteralPath $mamba
}

function Test-Conda([string]$Root) {
    $conda = Join-Path $Root 'Scripts\conda.exe'
    return Test-Path -LiteralPath $conda
}

function Move-PathAside([string]$Path, [string]$Suffix = 'incomplete') {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "{0}.{1}-{2}" -f $Path, $Suffix, $timestamp
    Write-Warning ("Moving existing path aside: {0} -> {1}" -f $Path, $backup)
    if (-not $DryRun) {
        Move-Item -LiteralPath $Path -Destination $backup -Force
    }
    return $backup
}

function Resolve-MiniforgeInstallDir() {
    if ((Test-Mamba $InstallDir) -and -not $Force) {
        Write-Host "Miniforge/mamba already installed at $InstallDir"
        return
    }

    if ($Force -and (Test-Path -LiteralPath $InstallDir)) {
        Write-Warning "Force reinstall requested. Removing existing Miniforge directory: $InstallDir"
        if (-not $DryRun) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
        return
    }

    if (-not (Test-Path -LiteralPath $InstallDir)) { return }

    if (-not (Test-PathNonEmpty $InstallDir)) {
        Write-Host "Removing empty Miniforge install directory before running installer: $InstallDir"
        if (-not $DryRun) { Remove-Item -LiteralPath $InstallDir -Force }
        return
    }

    if (Test-Conda $InstallDir) {
        Write-Warning "A conda.exe exists under $InstallDir but mamba.exe is missing. This does not look like the expected Miniforge layout for this template."
    }

    $policy = $ExistingDirPolicy
    if ($policy -eq 'prompt') {
        if ((Test-InteractiveSession) -and -not $AssumeYes) {
            Write-Host ''
            Write-Warning "Miniforge target directory is non-empty but incomplete: $InstallDir"
            Write-Host '  [B] Backup/move it aside and install fresh (recommended)'
            Write-Host '  [C] Clean/delete it and install fresh'
            Write-Host '  [R] Reuse only if complete; otherwise fail'
            Write-Host '  [F] Fail now'
            $answer = Read-Host 'Choose action [B/c/r/f]'
            switch -Regex ($answer.Trim().ToLowerInvariant()) {
                '^c' { $policy = 'clean' }
                '^r' { $policy = 'reuse' }
                '^f' { $policy = 'fail' }
                default { $policy = 'backup' }
            }
        } else {
            $policy = 'backup'
        }
    }

    switch ($policy) {
        'backup' { Move-PathAside -Path $InstallDir -Suffix 'incomplete' | Out-Null }
        'clean' {
            Write-Warning "Deleting incomplete Miniforge directory: $InstallDir"
            if (-not $DryRun) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
        }
        'reuse' { throw "Cannot reuse Miniforge directory because Scripts\mamba.exe is missing: $InstallDir" }
        'fail' { throw "Refusing to install Miniforge into non-empty incomplete directory: $InstallDir" }
        default { Move-PathAside -Path $InstallDir -Suffix 'incomplete' | Out-Null }
    }
}

Resolve-MiniforgeInstallDir

if ((Test-Mamba $InstallDir) -and -not $Force) {
    # Already reusable after directory resolution.
} else {
    $installer = $InstallerPath
    if (-not $installer) {
        if ($NoRemoteScripts) { throw 'Miniforge is not installed and remote download is disabled. Pass -InstallerPath to a preapproved Miniforge installer.' }
        $installer = Join-Path $env:TEMP 'Miniforge3-Windows-x86_64.exe'
        $url = 'https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Windows-x86_64.exe'
        Write-Host "Downloading Miniforge from $url"
        if (-not $DryRun) { Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing }
    }
    if (-not $DryRun) {
        if (-not (Test-Path -LiteralPath $installer)) { throw "Miniforge installer not found: $installer" }
        New-Item -ItemType Directory -Force -Path (Split-Path $InstallDir -Parent) | Out-Null
        # Miniforge Windows installer uses NSIS. /D must be last and unquoted.
        $installerArgs = @('/InstallationType=JustMe', '/RegisterPython=0', '/AddToPath=0', '/S', "/D=$InstallDir")
        Write-Host "Installing Miniforge to $InstallDir"
        $p = Start-Process -FilePath $installer -ArgumentList $installerArgs -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -ne 0) { throw "Miniforge installer failed with exit code $($p.ExitCode)" }
    }
}

$env:PATH = "$InstallDir;$InstallDir\Library\bin;$InstallDir\Scripts;$InstallDir\condabin;$env:PATH"

$mambaExe = Join-Path $InstallDir 'Scripts\mamba.exe'
$condaExe = Join-Path $InstallDir 'Scripts\conda.exe'
if (Test-Path -LiteralPath $mambaExe) {
    & $mambaExe --version
} elseif (Test-Path -LiteralPath $condaExe) {
    & $condaExe --version
    throw "conda.exe exists but mamba.exe was not found under $InstallDir. Re-run with -ExistingDirPolicy backup or clean to install the expected Miniforge layout."
} else {
    throw "Miniforge install did not produce mamba.exe or conda.exe under $InstallDir"
}
