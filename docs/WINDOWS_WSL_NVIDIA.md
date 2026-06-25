# Windows 11 + WSL2 + NVIDIA/CUDA

## What carries over from Windows into WSL2?

WSL2 uses the NVIDIA **Windows** display/compute driver. When the driver supports WSL2, Windows exposes the CUDA driver interface into each WSL2 Linux distro under:

```text
/usr/lib/wsl/lib/
  libcuda.so
  nvidia-smi
```

That means most Python ML workloads can use the GPU in WSL2 after you install the Linux distro and install a CUDA-enabled PyTorch wheel. You normally do **not** need to install a Linux NVIDIA display driver or a full CUDA Toolkit inside WSL2 for PyTorch/Hugging Face development.

## What does not carry over?

The Windows CUDA Toolkit installation, such as `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\...`, is not a Linux CUDA Toolkit. Do not rely on Windows `nvcc.exe`, Windows headers, or Windows libraries for compiling Linux binaries inside WSL2.

For native CUDA compilation inside WSL2, install the **WSL-Ubuntu CUDA Toolkit** packages inside the Linux distro. The safe package family is:

```bash
sudo apt-get install cuda-toolkit-13-3
# or another toolkit version that your Windows NVIDIA driver supports
```

Avoid these inside WSL2:

```text
cuda
cuda-12-x
cuda-13-x
cuda-drivers
nvidia-driver-*
```

Those can try to install a Linux NVIDIA driver and conflict with WSL2's Windows-driver bridge.

## Recommended default

For AI/ML Python development:

```powershell
.\scripts\bootstrap.ps1 -Profile personal
```

This detects `/usr/lib/wsl/lib/nvidia-smi` after the distro is installed and installs the CUDA PyTorch wheel when the GPU is visible.

## Optional: install CUDA Toolkit for nvcc / native CUDA development

Only use this when you need `nvcc`, CUDA headers, CUDA samples, or native CUDA extension compilation:

```powershell
.\scripts\bootstrap.ps1 -Profile personal -Features core,ai,conda,cuda-toolkit -CudaToolkitVersion 13-3
```

You can override `-CudaToolkitVersion`, for example:

```powershell
.\scripts\bootstrap.ps1 -Profile personal -Features core,ai,conda,cuda-toolkit -CudaToolkitVersion 12-9
```

Choose a toolkit version supported by the Windows NVIDIA driver shown in `nvidia-smi`.

## Troubleshooting checklist

From PowerShell:

```powershell
nvidia-smi
wsl --update
wsl --shutdown
wsl -d Ubuntu-24.04 -- /usr/lib/wsl/lib/nvidia-smi -L
```

Inside WSL:

```bash
/usr/lib/wsl/lib/nvidia-smi -L
python - <<'PY'
import torch
print(torch.__version__)
print(torch.version.cuda)
print(torch.cuda.is_available())
print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else None)
PY
```

Common fixes:

1. Update the Windows NVIDIA driver.
2. Run `wsl --update`.
3. Run `wsl --shutdown` and start the distro again.
4. Ensure the distro is WSL2 with `wsl -l -v`.
5. Do not install Linux NVIDIA display drivers inside WSL2.

## References

- NVIDIA CUDA on WSL User Guide: https://docs.nvidia.com/cuda/wsl-user-guide/index.html
- Microsoft WSL install guide: https://learn.microsoft.com/windows/wsl/install
- Microsoft GPU accelerated ML training in WSL: https://learn.microsoft.com/windows/wsl/tutorials/gpu-compute
- PyTorch local install selector: https://pytorch.org/get-started/locally/
