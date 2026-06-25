# WSL update/install failure triage

This note covers failures like:

```text
wsl --update
Installing: Windows Subsystem for Linux 2.x.x
Catastrophic failure
```

or error code `0x8000FFFF`.

## Why this happens

`wsl --update` is not just a Linux operation. It updates the Windows WSL package / MSI / MSIX layer and depends on Windows components such as optional features, App Installer / Store policy, Windows Update plumbing, virtualization, services, and sometimes corporate endpoint security.

Common root causes:

- PowerShell is not elevated, or the elevated account is different from the user account that will own the WSL distro.
- `Microsoft-Windows-Subsystem-Linux` or `VirtualMachinePlatform` is disabled or half-enabled pending reboot.
- BIOS/UEFI virtualization is disabled, or Hyper-V/VirtualMachinePlatform is blocked by policy.
- Microsoft Store / App Installer / MSIX installation is blocked or broken.
- Windows Update / BITS / AppX deployment services are disabled or restricted by enterprise policy.
- Existing WSL Store package state is corrupt.
- Windows component store or system files are corrupted.
- Security software blocks the WSL MSI/MSIX install or service registration.

## Minimal diagnostics

Run from elevated PowerShell:

```powershell
.\scripts\triage-wsl-update.ps1
```

Optional safe shutdown first:

```powershell
.\scripts\triage-wsl-update.ps1 -TryShutdown
```

System repair path, only when you are allowed to repair the OS image:

```powershell
.\scripts\triage-wsl-update.ps1 -RepairSystemImage
```

Manual commands worth checking:

```powershell
cmd.exe /c ver
wsl --version
wsl --status
wsl -l -v
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux,VirtualMachinePlatform
Get-Service LxssManager,vmcompute,hns,SharedAccess,AppXSvc,InstallService,wuauserv,BITS
```

## Conservative repair sequence

```powershell
wsl --shutdown
wsl --update
```

If that still fails:

```powershell
sfc /scannow
DISM /Online /Cleanup-Image /RestoreHealth
```

If optional features are disabled:

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

Then reboot.

## Offline WSL package path

For restricted Store environments, use the WSL release package from the official Microsoft WSL GitHub releases. Microsoft documents an offline path using the WSL MSI package and enabling `VirtualMachinePlatform` with DISM.

This still may be blocked by enterprise policy. If so, do not keep fighting WSL during onboarding; use the Windows-native bootstrap path:

```powershell
.\scripts\bootstrap.ps1 -Backend native -Profile enterprise
```

or directly:

```powershell
.\scripts\bootstrap-windows-native.ps1 -Profile enterprise
```

## When to stop debugging WSL

Stop and switch to native Windows when:

- You do not control enterprise AppX/MSIX/Store policy.
- You cannot enable virtualization features or reboot freely.
- `sfc`/`DISM` are disallowed by IT policy.
- Your immediate goal is PyTorch/Hugging Face/scikit-learn/Jupyter development rather than Linux-first MLsys work.

Return to WSL later when IT can deploy or repair the WSL package cleanly.
