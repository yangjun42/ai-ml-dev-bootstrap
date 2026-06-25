# MLsys optional tools

The `mlsys` feature installs a conservative set of profiling, benchmarking, and model export/runtime tools that work on common developer machines.

## Included by default in `mlsys`

| Tool | Purpose | Notes |
|---|---|---|
| `torch.profiler` | PyTorch CPU/GPU profiling | Built into PyTorch; examples in `scripts/profile_torch.py`. |
| `tensorboard` | Visualize scalar metrics/profiles | Local by default. |
| `torch-tb-profiler` | PyTorch profiler TensorBoard plugin | Optional helper; version compatibility can vary. |
| `scalene` | Python CPU/GPU/memory profiler | Good first profiler for Python overhead. |
| `py-spy` | Sampling profiler | Useful when you cannot modify code. |
| `memray` | Memory profiler | macOS/Linux only; not installed on Windows native. |
| `viztracer` | Trace viewer | Good for async/data pipeline overhead. |
| `line_profiler` | Function line-level profiling | Useful for CPU hotspots. |
| `pytest-benchmark` | Regressions/benchmarks | Good for microbenchmarks. |
| `onnx`, `onnxruntime` | Model export/runtime smoke tests | GPU runtime is not installed by default. |

## Not installed by default

| Tool/framework | Why optional |
|---|---|
| `flash-attn` | Often needs exact CUDA + PyTorch + compiler match. |
| `xformers` | Wheel availability and ABI compatibility vary. |
| `bitsandbytes` | Useful for LLM quantization/fine-tuning, but GPU/platform support varies. |
| NVIDIA Nsight Systems/Compute | Excellent for CUDA profiling, but OS/driver/toolkit setup is heavier. |
| `perf` / eBPF | Linux-only and often restricted in enterprise or WSL. |
| Ray | Useful for distributed workloads, but overkill for default laptop bootstrap. |

## Suggested profiling order

1. Start with wall-clock and data-loader sanity checks.
2. Use `torch.profiler` for model step breakdown.
3. Use `scalene` / `py-spy` for Python overhead.
4. Use `memray` if memory grows unexpectedly.
5. Use Nsight Systems/Compute only when optimizing CUDA kernels or GPU utilization.
