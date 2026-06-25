#requires -Version 5.1
<#
.SYNOPSIS
  Install Miniforge3 for Windows silently, then make mamba/conda available to the current process.
#>
param(
    [string]$InstallDir = (Join-Path $env:USERPROFILE 'miniforge3'),
    [string]$InstallerPath = '',
    [switch]$NoRemoteScripts,
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Test-Mamba([string]$Root) {
    $mamba = Join-Path $Root 'Scripts\mamba.exe'
    return Test-Path $mamba
}

if ((Test-Mamba $InstallDir) -and -not $Force) {
    Write-Host "Miniforge already installed at $InstallDir"
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
        if (-not (Test-Path $installer)) { throw "Miniforge installer not found: $installer" }
        if ($Force -and (Test-Path $InstallDir)) {
            Write-Warning "Removing existing Miniforge directory: $InstallDir"
            Remove-Item -Recurse -Force $InstallDir
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $InstallDir -Parent) | Out-Null
        # Miniforge Windows installer uses NSIS. /D must be last and unquoted.
        $installerArgs = @('/InstallationType=JustMe', '/RegisterPython=0', '/AddToPath=0', '/S', "/D=$InstallDir")
        $p = Start-Process -FilePath $installer -ArgumentList $installerArgs -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -ne 0) { throw "Miniforge installer failed with exit code $($p.ExitCode)" }
    }
}

$env:PATH = "$InstallDir;$InstallDir\Library\bin;$InstallDir\Scripts;$InstallDir\condabin;$env:PATH"

$mambaExe = Join-Path $InstallDir 'Scripts\mamba.exe'
$condaExe = Join-Path $InstallDir 'Scripts\conda.exe'
if (Test-Path $mambaExe) {
    & $mambaExe --version
} elseif (Test-Path $condaExe) {
    & $condaExe --version
} else {
    throw "Miniforge install did not produce mamba.exe or conda.exe under $InstallDir"
}
