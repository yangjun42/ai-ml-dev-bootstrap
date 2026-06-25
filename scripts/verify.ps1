param(
    [string]$Distro = 'Ubuntu-24.04',
    [string]$Project = '~/projects/ai-ml-starter'
)
wsl -d $Distro -- bash -lc "cd $Project && uv run python scripts/check_env.py"
