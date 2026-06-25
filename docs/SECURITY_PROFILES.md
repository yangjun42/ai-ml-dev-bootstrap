# Security and information-flow profiles

## personal

For personal research/dev machines where code, model names, metrics, and artifacts may be sent to external services.

Still, this repo does not store tokens automatically. Run logins manually:

```bash
huggingface-cli login
wandb login
```

## enterprise

For environments where source code, data, model weights, prompts, metrics, traces, or artifacts should not leave the machine/network by default.

Defaults:

```bash
HF_HUB_DISABLE_TELEMETRY=1
WANDB_MODE=offline
MLFLOW_TRACKING_URI=file://$HOME/mlruns
DO_NOT_TRACK=1
```

Recommended additions for real enterprises:

- private PyPI mirror and `UV_INDEX_URL` / `UV_EXTRA_INDEX_URL` policy;
- private conda mirror and `.condarc` channel allowlist;
- SBOM generation with `cyclonedx-bom`;
- secret scanning with `detect-secrets` or organization tooling;
- dependency vulnerability scans with `pip-audit` and/or central scanners;
- license allowlist policy;
- no direct internet from build machines unless proxied and audited.
