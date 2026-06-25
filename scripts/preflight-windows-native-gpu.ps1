#requires -Version 5.1
<#
.SYNOPSIS
  Preflight checks for Windows-native NVIDIA/CUDA AI development without WSL.
#>
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'

function Write-Info([string]$Message) {
    if (-not $Quiet) { Write-Host $Message }
}

function Test-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

$info = [ordered]@{
    windows_version = $null
    powershell = $PSVersionTable.PSVersion.ToString()
    nvidia_smi = $null
    nvidia_gpus = @()
    cuda_nvcc = $null
    cuda_path = $env:CUDA_PATH
    visual_studio_where = $null
    cl = $null
}

try {
    $os = Get-CimInstance Win32_OperatingSystem
    $info.windows_version = ('{0} {1} build {2}' -f $os.Caption, $os.Version, $os.BuildNumber)
} catch {}

if (Test-Command nvidia-smi) {
    $info.nvidia_smi = (Get-Command nvidia-smi).Source
    try {
        $gpuLines = & nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>$null
        $info.nvidia_gpus = @($gpuLines)
    } catch {
        $info.nvidia_gpus = @('nvidia-smi exists but query failed: ' + $_.Exception.Message)
    }
} else {
    Write-Warning 'nvidia-smi not found on PATH. Install or repair the Windows NVIDIA driver if CUDA GPU use is expected.'
}

if (Test-Command nvcc) {
    try { $info.cuda_nvcc = (& nvcc --version | Select-Object -Last 1) } catch {}
} else {
    Write-Info 'nvcc not found. This is OK for PyTorch wheel usage; install CUDA Toolkit only for native CUDA compilation.'
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path $vswhere) {
    $info.visual_studio_where = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null)
}
if (Test-Command cl) {
    try { $info.cl = (& cl 2>&1 | Select-Object -First 1) } catch {}
}

$info | ConvertTo-Json -Depth 5

if (-not $info.nvidia_smi) {
    Write-Warning 'No nvidia-smi detected. Continuing; CPU-only PyTorch remains available.'
}
