#requires -Version 5.1
<#
.SYNOPSIS
  Native Windows preflight for AI/ML development without WSL.
#>
param(
    [switch]$Json
)

$ErrorActionPreference = 'Continue'

function Test-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-CommandVersion([string]$Name, [string[]]$Args = @('--version')) {
    if (-not (Test-Command $Name)) { return $null }
    try {
        $out = & $Name @Args 2>&1 | Select-Object -First 3
        return (($out | ForEach-Object { $_.ToString() }) -join "`n")
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

$result = [ordered]@{}

try {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $result.os = [ordered]@{
        Caption = $os.Caption
        Version = $os.Version
        BuildNumber = $os.BuildNumber
        Architecture = $os.OSArchitecture
        Manufacturer = $cs.Manufacturer
        Model = $cs.Model
        TotalPhysicalMemoryGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    }
} catch {
    $result.os = "ERROR: $($_.Exception.Message)"
}

$commands = 'winget','git','gh','uv','python','py','conda','mamba','nvidia-smi','nvcc','cmake','ninja','cl'
$result.commands = [ordered]@{}
foreach ($cmd in $commands) {
    $entry = [ordered]@{ found = (Test-Command $cmd); path = $null; version = $null }
    if ($entry.found) {
        try { $entry.path = (Get-Command $cmd -ErrorAction Stop).Source } catch {}
        switch ($cmd) {
            'nvidia-smi' { $entry.version = Get-CommandVersion $cmd @('--query-gpu=name,driver_version','--format=csv') }
            'cl' { $entry.version = Get-CommandVersion $cmd @() }
            default { $entry.version = Get-CommandVersion $cmd }
        }
    }
    $result.commands[$cmd] = $entry
}

$result.cuda = [ordered]@{
    CUDA_PATH = $env:CUDA_PATH
    CUDA_PATH_V12_0 = $env:CUDA_PATH_V12_0
    CUDA_PATH_V13_0 = $env:CUDA_PATH_V13_0
    toolkit_dirs = @()
}
$cudaRoot = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA'
if (Test-Path $cudaRoot) {
    try { $result.cuda.toolkit_dirs = @(Get-ChildItem $cudaRoot -Directory | Select-Object -ExpandProperty FullName) } catch {}
}

$result.recommendation = @(
    'For PyTorch/Hugging Face on native Windows, a recent NVIDIA Windows driver plus PyTorch CUDA wheels is usually enough.',
    'Install CUDA Toolkit and Visual Studio Build Tools only when you need nvcc or native CUDA extension builds.',
    'TensorFlow GPU on native Windows is legacy-only; use CPU/DirectML or WSL/Linux when available.'
)

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    Write-Host '== Windows Native AI/ML preflight ==' -ForegroundColor Cyan
    $result | ConvertTo-Json -Depth 8
}
