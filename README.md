# ai-ml-dev-bootstrap

Windows 11 / WSL2 与 macOS 的 AI/ML 开发环境一键 bootstrap 仓库。

设计目标：

- **默认用 uv 管 Python 项目依赖**，速度快、项目化、适合 PyTorch / Hugging Face / scikit-learn / Jupyter。
- **保留 Miniforge + mamba 作为 conda-forge 二进制生态入口**，用于 GDAL、HDF5、R、Qt、复杂 C/C++/Fortran 依赖、团队 `environment.yml` 复现。
- **Windows 默认走 WSL2 Ubuntu**，避免 Windows 原生 CUDA / 编译链坑。
- **macOS 原生安装**，Apple Silicon 可选 MLX / MPS 路线。
- **容器化可选**，不把 Docker/Podman/Rancher 设为必选前提。
- **两套 profile**：`personal` 更自由，允许外部模型/实验追踪；`enterprise` 默认本地、少遥测、少外部信息传递。

> 本仓库不替代公司的安全、合规、许可证审查。`enterprise` profile 只是保守默认值模板。

---

## 一句话结论：Miniforge + mamba 是否重复？

不完全重复。**Miniforge 是发行版/安装器/入口**，它把 conda、mamba、conda-forge 默认 channel 等预配置好；**mamba 是 conda 环境和包的快速 CLI/求解器**。安装 Miniforge 后通常就能直接使用 `conda` 和 `mamba`，日常创建/安装环境时优先用 `mamba`，需要兼容旧文档时再用 `conda`。

本仓库的实践是：

```text
uv        -> 绝大多数 Python/AI 项目的主包管理器
Miniforge -> 提供 conda-forge 二进制生态入口
mamba     -> 用于快速创建/更新 conda 环境
容器       -> 复现/隔离/部署前验证，可选
```

---

## 快速开始

### Windows 11：推荐 WSL2 Ubuntu

以管理员 PowerShell 执行首次安装更稳。若 WSL 首装要求重启，重启后重新执行同一命令。

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force

git clone https://github.com/YOUR_ORG_OR_USER/ai-ml-dev-bootstrap.git
cd ai-ml-dev-bootstrap

# 个人开发版：默认 core, ai, conda
.\scripts\bootstrap.ps1 -Profile personal

# 企业/受限版：默认 core, ai, conda，但更保守的环境变量和工具选择
.\scripts\bootstrap.ps1 -Profile enterprise

# 可选：加 MLsys profiling/benchmark 工具
.\scripts\bootstrap.ps1 -Profile personal -Features core,ai,conda,mlsys

# 可选：再安装容器桌面工具
.\scripts\bootstrap.ps1 -Profile personal -Features core,ai,conda,containers
```

Windows 侧会安装基础桌面工具，并在 WSL2 Ubuntu 内配置真正的 AI/ML 开发环境。

### macOS

```bash
git clone https://github.com/YOUR_ORG_OR_USER/ai-ml-dev-bootstrap.git
cd ai-ml-dev-bootstrap

# 个人开发版
./scripts/bootstrap-macos.sh --profile personal

# 企业/受限版
./scripts/bootstrap-macos.sh --profile enterprise

# 可选：加 MLsys 工具
./scripts/bootstrap-macos.sh --profile personal --features core,ai,conda,mlsys

# 可选：容器工具
./scripts/bootstrap-macos.sh --profile personal --features core,ai,conda,containers
```

Apple Silicon 机器会额外尝试安装 MLX 相关包。

---

## Bootstrap 之后会得到什么？

默认会创建：

```text
~/projects/ai-ml-starter/
  pyproject.toml
  requirements/
  notebooks/
  src/
  scripts/
```

常用命令：

```bash
cd ~/projects/ai-ml-starter
uv run python scripts/check_env.py
uv run jupyter lab
```

如果安装了 Miniforge/mamba：

```bash
mamba env list
mamba activate ai-native
uv pip install -r requirements/base.txt
```

---

## Features

`-Features` / `--features` 是逗号分隔列表：

| feature | 默认 | 说明 |
|---|---:|---|
| `core` | ✅ | Git、shell、uv、基础构建工具、编辑器 |
| `ai` | ✅ | 创建 uv AI starter 项目，安装 PyTorch、Jupyter、scikit-learn、Hugging Face 常用包 |
| `conda` | ✅ | 安装 Miniforge，创建 `ai-native` conda 环境，作为 native deps fallback |
| `mlsys` | ❌ | profiling/benchmark 工具，如 PyTorch Profiler 辅助、TensorBoard、Scalene、py-spy、memray、ONNX Runtime |
| `containers` | ❌ | 安装/配置容器桌面工具；仓库内有 Dockerfile/compose/devcontainer 模板 |
| `cuda-extras` | ❌ | Linux/WSL NVIDIA CUDA 实验性额外包，如 bitsandbytes/xformers；失败会跳过 |
| `all` | ❌ | 启用全部可选项 |

---

## Profiles

### personal

适合个人电脑、开源研究、允许把模型/metrics/artifacts 传到外部服务的场景。

- 可安装 Hugging Face、W&B、MLflow、DVC、Gradio、Streamlit 等。
- 默认 `MLFLOW_TRACKING_URI=file://$HOME/mlruns`，但不阻止你配置远程 tracking。
- 保留云服务 CLI 的空间，但不默认写入 token。

### enterprise

适合代码、数据、模型权重、metrics 不应随意外传的场景。

- 默认禁用 Hugging Face Hub 遥测环境变量。
- 默认 `WANDB_MODE=offline`。
- 默认 MLflow 使用本地文件 tracking。
- conda 默认 `conda-forge + nodefaults + strict channel priority`。
- 不自动登录任何外部服务，不保存 token，不默认安装闭源 SaaS agent。

---

## 推荐日常工作流

### uv-only 项目

```bash
uv init --python 3.12 my-project
cd my-project
uv add numpy pandas scikit-learn jupyterlab
uv add transformers datasets accelerate
uv add --dev ruff pytest
```

### conda native + uv Python 层

```bash
mamba create -n geo -c conda-forge -c nodefaults python=3.12 uv gdal geopandas rasterio hdf5
mamba activate geo
uv pip install transformers datasets accelerate
```

### 接同事的 Anaconda 配置

优先让同事导出：

```bash
conda env export --from-history > environment.yml
```

你用 Miniforge/mamba：

```bash
mamba env create -f environment.yml
```

如果同事给的是同平台 explicit spec：

```bash
mamba create -n legacy --file explicit-win-64.txt
```

如果只是 `requirements.txt`：

```bash
uv pip install -r requirements.txt
```

---

## 仓库结构

```text
.
├── scripts/
│   ├── bootstrap.ps1               # Windows entrypoint
│   ├── bootstrap-wsl.sh            # Windows WSL Ubuntu bootstrap
│   ├── bootstrap-macos.sh          # macOS entrypoint
│   ├── install-miniforge.sh        # Unix/WSL Miniforge installer
│   ├── install-cuda-extras.sh      # optional Linux CUDA packages
│   ├── verify.sh
│   └── verify.ps1
├── envs/
│   ├── ai-native.yml               # minimal conda-native bridge env
│   └── geo-native.yml              # example native-heavy env
├── profiles/
│   ├── personal.env
│   └── enterprise.env
├── templates/
│   └── ai-starter/
│       ├── pyproject.toml
│       ├── requirements/
│       ├── scripts/check_env.py
│       └── notebooks/00_smoke_test.ipynb
├── containers/
│   ├── Dockerfile.cpu
│   ├── Dockerfile.gpu-wheel
│   ├── compose.cpu.yml
│   └── compose.gpu.yml
├── .devcontainer/
│   └── devcontainer.json
└── docs/
```

---

## 注意事项

- Windows 项目文件建议放在 WSL Linux 文件系统，例如 `~/projects/...`，不要把训练项目长期放在 `/mnt/c/...`。
- 不要让 conda 和 uv 同时管理同一批核心大包。尤其是 `numpy/scipy/torch` 这类，要么都在 conda-forge，要么都在 uv/PyPI wheel。
- `cuda-extras` 是实验项，因为 `flash-attn`、`xformers`、`bitsandbytes` 与 CUDA/PyTorch ABI 组合强相关。默认不会安装这些包。
- 企业场景请把 `requirements/*.txt`、`envs/*.yml` 接入私有镜像源/制品库，并开启 SBOM、license scan、secret scan。
