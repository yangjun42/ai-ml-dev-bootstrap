from __future__ import annotations

import importlib.util
import json
import os
import platform
import subprocess
import sys
from pathlib import Path


def has_module(name: str) -> bool:
    return importlib.util.find_spec(name) is not None


def run(cmd: list[str]) -> str | None:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True, timeout=10).strip()
    except Exception:
        return None


def run_nvidia_smi(args: list[str]) -> tuple[str | None, str | None]:
    candidates = [
        ["nvidia-smi", *args],
        ["/usr/lib/wsl/lib/nvidia-smi", *args],
    ]
    for cmd in candidates:
        output = run(cmd)
        if output is not None:
            return cmd[0], output
    return None, None


def main() -> None:
    info: dict[str, object] = {
        "python": sys.version.split()[0],
        "executable": sys.executable,
        "platform": platform.platform(),
        "machine": platform.machine(),
        "profile": os.environ.get("AI_DEV_PROFILE"),
        "hf_home": os.environ.get("HF_HOME"),
        "mlflow_tracking_uri": os.environ.get("MLFLOW_TRACKING_URI"),
        "project": str(Path.cwd()),
    }

    for mod in ["numpy", "pandas", "sklearn", "torch", "transformers", "datasets"]:
        if has_module(mod):
            m = __import__(mod)
            info[mod] = getattr(m, "__version__", "installed")
        else:
            info[mod] = None

    if has_module("torch"):
        import torch

        info["torch_cuda_available"] = torch.cuda.is_available()
        info["torch_cuda_build"] = torch.version.cuda
        info["torch_mps_available"] = bool(
            getattr(torch.backends, "mps", None) and torch.backends.mps.is_available()
        )
        if torch.cuda.is_available():
            info["torch_cuda_device"] = torch.cuda.get_device_name(0)

    smi_path, smi_output = run_nvidia_smi(["--query-gpu=name,driver_version", "--format=csv,noheader"])
    info["nvidia_smi_path"] = smi_path
    info["nvidia_smi"] = smi_output
    info["uv"] = run(["uv", "--version"])
    info["git"] = run(["git", "--version"])

    print(json.dumps(info, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
