from __future__ import annotations

import time
from pathlib import Path

import torch
from torch.profiler import ProfilerActivity, profile, schedule, tensorboard_trace_handler


def device() -> torch.device:
    if torch.cuda.is_available():
        return torch.device("cuda")
    if getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


def main() -> None:
    dev = device()
    print(f"Profiling on {dev}")
    model = torch.nn.Sequential(
        torch.nn.Linear(4096, 4096),
        torch.nn.GELU(),
        torch.nn.Linear(4096, 4096),
    ).to(dev)
    opt = torch.optim.AdamW(model.parameters(), lr=1e-3)
    x = torch.randn(64, 4096, device=dev)

    logdir = Path("runs/torch-profiler")
    logdir.mkdir(parents=True, exist_ok=True)

    activities = [ProfilerActivity.CPU]
    if dev.type == "cuda":
        activities.append(ProfilerActivity.CUDA)

    with profile(
        activities=activities,
        schedule=schedule(wait=1, warmup=1, active=3, repeat=1),
        on_trace_ready=tensorboard_trace_handler(str(logdir)),
        record_shapes=True,
        profile_memory=True,
        with_stack=False,
    ) as prof:
        for step in range(8):
            opt.zero_grad(set_to_none=True)
            y = model(x).square().mean()
            y.backward()
            opt.step()
            prof.step()
            if dev.type == "cuda":
                torch.cuda.synchronize()
            time.sleep(0.05)
            print(f"step={step} loss={y.item():.4f}")

    print(f"Trace written to {logdir}")
    print("View with: uv run tensorboard --logdir runs")


if __name__ == "__main__":
    main()
