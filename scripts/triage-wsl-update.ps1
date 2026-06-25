#requires -Version 5.1
<#
.SYNOPSIS
  Collects WSL install/update diagnostics for failures such as 0x8000FFFF / Catastrophic failure.

.DESCRIPTION
  This script is intentionally conservative by default: it prints diagnostics and does not change
  Windows features or repair the OS unless you pass -RepairSystemImage.
#>
param(
    [switch]$RepairSystemImage,
    [switch]$TryShutdown,
    [switch]$Json
)

$ErrorActionPreference = 'Continue'

function Run-Capture([scriptblock]$Block) {
    try {
        $out = & $Block 2>&1
        return (($out | ForEach-Object { $_.ToString() }) -join "`n")
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Get-FeatureState([string]$Name) {
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName $Name
        return $f.State.ToString()
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

$result = [ordered]@{}
$result.timestamp = (Get-Date).ToString('o')
$result.user = [ordered]@{
    UserName = [Environment]::UserName
    UserDomainName = [Environment]::UserDomainName
    IsElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $result.system = [ordered]@{
        Caption = $os.Caption
        Version = $os.Version
        BuildNumber = $os.BuildNumber
        OSArchitecture = $os.OSArchitecture
        Manufacturer = $cs.Manufacturer
        Model = $cs.Model
        HypervisorPresent = $cs.HypervisorPresent
        VirtualizationFirmwareEnabled = $cpu.VirtualizationFirmwareEnabled
        SecondLevelAddressTranslationExtensions = $cpu.SecondLevelAddressTranslationExtensions
        VMMonitorModeExtensions = $cpu.VMMonitorModeExtensions
    }
} catch {
    $result.system = "ERROR: $($_.Exception.Message)"
}

$result.wsl = [ordered]@{
    path = (Run-Capture { (Get-Command wsl.exe -ErrorAction Stop).Source })
    version = (Run-Capture { wsl.exe --version })
    status = (Run-Capture { wsl.exe --status })
    distros = (Run-Capture { wsl.exe -l -v })
}

$result.optional_features = [ordered]@{
    Microsoft_Windows_Subsystem_Linux = Get-FeatureState 'Microsoft-Windows-Subsystem-Linux'
    VirtualMachinePlatform = Get-FeatureState 'VirtualMachinePlatform'
    HypervisorPlatform = Get-FeatureState 'HypervisorPlatform'
    Microsoft_Hyper_V_All = Get-FeatureState 'Microsoft-Hyper-V-All'
}

$services = 'LxssManager','vmcompute','hns','SharedAccess','AppXSvc','InstallService','wuauserv','BITS'
$result.services = [ordered]@{}
foreach ($svcName in $services) {
    try {
        $svc = Get-Service -Name $svcName -ErrorAction Stop
        $result.services[$svcName] = [ordered]@{ Status = $svc.Status.ToString(); StartType = $svc.StartType.ToString() }
    } catch {
        $result.services[$svcName] = "not found or inaccessible: $($_.Exception.Message)"
    }
}

$result.appx = [ordered]@{
    WSL = (Run-Capture { Get-AppxPackage -Name MicrosoftCorporationII.WindowsSubsystemForLinux | Select-Object Name, PackageFullName, Version, InstallLocation | Format-List })
    AppInstaller = (Run-Capture { Get-AppxPackage -Name Microsoft.DesktopAppInstaller | Select-Object Name, PackageFullName, Version | Format-List })
}

if ($TryShutdown) {
    $result.actions = [ordered]@{
        wsl_shutdown = (Run-Capture { wsl.exe --shutdown })
    }
}

if ($RepairSystemImage) {
    $result.repairs = [ordered]@{
        sfc = (Run-Capture { sfc.exe /SCANNOW })
        dism_restorehealth = (Run-Capture { dism.exe /Online /Cleanup-Image /RestoreHealth })
    }
}

$result.next_steps = @(
    'Run this script from an elevated PowerShell and compare IsElevated=true.',
    'If optional features are Disabled, enable WSL and VirtualMachinePlatform, reboot, then retry.',
    'If AppX/App Installer/Store is blocked by enterprise policy, use the Windows-native bootstrap instead.',
    'If system files look corrupted, rerun with -RepairSystemImage.',
    'If wsl --update keeps failing at the package/MSIX/MSI layer, try the offline MSI from microsoft/WSL releases or ask IT to deploy it.'
)

if ($Json) {
    $result | ConvertTo-Json -Depth 10
} else {
    Write-Host '== WSL update/install triage ==' -ForegroundColor Cyan
    $result | ConvertTo-Json -Depth 10
}
