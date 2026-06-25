#requires -Version 5.1
<#
.SYNOPSIS
  Checks the Windows NVIDIA driver and WSL2 GPU bridge before/after installing a Linux distro.

.DESCRIPTION
  WSL2 CUDA uses the NVIDIA Windows display/compute driver exposed into Linux as /usr/lib/wsl/lib/libcuda.so.
  This preflight intentionally does not install any Linux NVIDIA display driver.
#>
param(
    [string]$Distro = 'Ubuntu-24.04'
)

$ErrorActionPreference = 'Continue'

function Find-NvidiaSmi {
    $cmd = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'NVIDIA Corporation\NVSMI\nvidia-smi.exe'),
        (Join-Path $env:SystemRoot 'System32\nvidia-smi.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    return $null
}

Write-Host '==> NVIDIA / WSL2 CUDA preflight' -ForegroundColor Cyan

$nvidiaSmi = Find-NvidiaSmi
if ($nvidiaSmi) {
    Write-Host "Windows nvidia-smi: $nvidiaSmi"
    try {
        & $nvidiaSmi --query-gpu=name,driver_version --format=csv,noheader
    } catch {
        Write-Warning "Windows nvidia-smi exists but failed: $($_.Exception.Message)"
    }
} else {
    Write-Warning 'Windows nvidia-smi was not found. Install or update the NVIDIA Windows driver before expecting CUDA in WSL2.'
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Write-Warning 'wsl.exe was not found. bootstrap.ps1 will install WSL if possible.'
    return
}

try { wsl.exe --status } catch { Write-Warning "wsl --status failed: $($_.Exception.Message)" }
try { wsl.exe --version } catch { }

$distrosRaw = @()
try { $distrosRaw = (wsl.exe -l -q) -replace "`0", '' } catch { }
$distros = @($distrosRaw | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_.Length -gt 0 })
if ($distros -notcontains $Distro) {
    Write-Host "WSL distro '$Distro' is not installed yet. After installation, the NVIDIA bridge should appear at /usr/lib/wsl/lib inside the distro if the Windows driver supports WSL2."
    return
}

Write-Host "Checking NVIDIA visibility inside WSL distro: $Distro"
try {
    wsl.exe -d $Distro -- bash -lc @'
set -e
if [ -x /usr/lib/wsl/lib/nvidia-smi ]; then
  echo "WSL nvidia-smi: /usr/lib/wsl/lib/nvidia-smi"
  /usr/lib/wsl/lib/nvidia-smi -L || true
elif command -v nvidia-smi >/dev/null 2>&1; then
  echo "WSL nvidia-smi: $(command -v nvidia-smi)"
  nvidia-smi -L || true
else
  echo "WSL nvidia-smi not found. Try: wsl --update; update NVIDIA Windows driver; then wsl --shutdown."
fi
if [ -e /usr/lib/wsl/lib/libcuda.so ] || [ -e /usr/lib/wsl/lib/libcuda.so.1 ]; then
  echo "WSL libcuda bridge: present"
else
  echo "WSL libcuda bridge: not found"
fi
'@
} catch {
    Write-Warning "Could not run WSL NVIDIA check. If this is the first distro launch, finish the Ubuntu username/password setup and rerun bootstrap.ps1. $($_.Exception.Message)"
}
