#!/usr/bin/env python3
"""Check the advertised release base and delegate existing Git hooks."""

import errno
import json
import os
import sys
import tempfile
from pathlib import Path


def require_advertised_main(payload, expected_head):
    records = [line.split() for line in payload.splitlines()]
    if any(len(record) != 4 for record in records):
        raise ValueError("Malformed pre-push ref advertisement")
    old_heads = [record[3] for record in records if record[2] == b"refs/heads/main"]
    if old_heads != [expected_head.encode("ascii")]:
        raise ValueError(
            "The advertised origin/main changed from the validated release base"
        )


def delegate_hook(context, name, args):
    original = Path(context["hooks_directory"]) / name
    if name == "pre-push":
        payload = sys.stdin.buffer.read()
        require_advertised_main(payload, context["expected_head"])
        with tempfile.TemporaryFile() as replay:
            replay.write(payload)
            replay.seek(0)
            os.dup2(replay.fileno(), sys.stdin.fileno())
    if not original.is_file() or not os.access(original, os.X_OK):
        return 0
    environment = {
        key: value
        for key, value in os.environ.items()
        if key != "GIT_CONFIG_PARAMETERS"
    }
    parameters = context["git_config_parameters"]
    if parameters is not None:
        environment = {**environment, "GIT_CONFIG_PARAMETERS": parameters}
    try:
        os.execve(str(original), [str(original), *args], environment)
    except OSError as error:
        if error.errno != errno.ENOEXEC:
            raise
        shell = context["git_shell"]
        os.execve(shell, [shell, str(original), *args], environment)


def main():
    try:
        context = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
        return delegate_hook(context, sys.argv[2], sys.argv[3:])
    except (OSError, ValueError, KeyError) as error:
        print(f"Release hook refused: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
