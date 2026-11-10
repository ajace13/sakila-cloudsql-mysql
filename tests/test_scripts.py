"""The shell scripts parse, and none of them contains a password or a project id."""
import re
import shutil
import subprocess

import pytest
from conftest import ROOT

SCRIPTS = sorted((ROOT / "infra").glob("*.sh"))
BASH = shutil.which("bash")
NO_WORKING_BASH = BASH is None or subprocess.run([BASH, "-c", "true"], capture_output=True).returncode != 0


@pytest.mark.skipif(NO_WORKING_BASH, reason="no working bash (e.g. the WSL stub on Windows)")
@pytest.mark.parametrize("path", SCRIPTS, ids=lambda p: p.name)
def test_bash_syntax(path):
    assert subprocess.run([BASH, "-n", str(path)], capture_output=True).returncode == 0


def test_deploy_script_safety():
    text = (ROOT / "infra" / "deploy_sakila.sh").read_text(encoding="utf-8")
    assert "set -euo pipefail" in text
    assert "already exists; skipping create" in text           # idempotent create
    assert re.search(r"--root-password=\"\$MYSQL_ROOT_PW\"", text)  # password only from a hidden prompt or env var
    assert "Type 'delete' to confirm" in text                    # teardown asks first


@pytest.mark.parametrize("path", SCRIPTS, ids=lambda p: p.name)
def test_no_secrets(path):
    text = path.read_text(encoding="utf-8")
    assert not re.search(r"(?i)(password|passwd|pw)\s*=\s*['\"]?[^\s'\"$]{4,}", text)
    assert not re.search(r"(?m)^\s*export PROJECT_ID=(?!your-project-id)\S+", text)


@pytest.mark.skipif(not shutil.which("shellcheck"), reason="shellcheck not installed")
def test_shellcheck_deploy_script():
    r = subprocess.run(["shellcheck", "-S", "warning", str(ROOT / "infra" / "deploy_sakila.sh")], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout
