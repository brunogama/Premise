#!/usr/bin/env python3
"""Plan stable Conventional Commit releases, or publish with --publish."""

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path

STABLE_VERSION = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
START = "<!-- release-version:start -->"
END = "<!-- release-version:end -->"
REFERENCE_PATTERNS = (
    r"(The current release is `)([^`]+)(`)",
    r'(from: ")([^"]+)(")',
    r"(pin exactly to the `)([^`]+)(` tag)",
    r'(exact: ")([^"]+)(")',
    r"(set the version to `)([^`]+)(`)",
    r"(\[Release tag v)([^\]]+)(\])",
    r"(https://github\.com/brunogama/Premise/tree/v)([^)\s]+)(\))",
)
HEADER = re.compile(
    r"([a-z][a-z0-9-]*)(?:\([^\r\n()]+\))?(!)?: .+", re.IGNORECASE | re.ASCII
)
BREAKING = re.compile(r"^BREAKING(?: CHANGE|-CHANGE):[ \t]+\S", re.MULTILINE)


class ReleaseError(Exception):
    """The release cannot safely proceed."""


@dataclass(frozen=True, order=True)
class Version:
    major: int
    minor: int
    patch: int

    @classmethod
    def from_tag(cls, tag):
        match = re.fullmatch("v" + STABLE_VERSION, tag)
        return cls(*(int(part) for part in match.groups())) if match else None

    def __str__(self):
        return f"{self.major}.{self.minor}.{self.patch}"

    def bumped(self, bump):
        if bump == 3:
            return Version(self.major + 1, 0, 0)
        if bump == 2:
            return Version(self.major, self.minor + 1, 0)
        return Version(self.major, self.minor, self.patch + 1)


@dataclass(frozen=True)
class ReleasePlan:
    head: str
    baseline: Version
    version: Version | None
    readme: str

    def output(self, status):
        return {
            "status": status,
            "head": self.head,
            "baseline": str(self.baseline),
            "version": str(self.version) if self.version else None,
            "tag": f"v{self.version}" if self.version else None,
        }


def git(*args):
    result = subprocess.run(["git", *args], text=True, capture_output=True)
    if result.returncode:
        raise ReleaseError(result.stderr.strip() or "Git command failed")
    return result.stdout.rstrip("\n")


def commit_bump(message):
    header = HEADER.fullmatch(message.split("\n", 1)[0])
    if not header:
        return 0
    if header.group(2) or BREAKING.search(message):
        return 3
    return {"feat": 2, "fix": 1}.get(header.group(1).lower(), 0)


def versioned_readme(text, baseline, version):
    if text.count(START) != 1 or text.count(END) != 1:
        raise ReleaseError("README requires exactly one release-version marker pair")
    start = text.index(START) + len(START)
    end = text.index(END)
    if end < start:
        raise ReleaseError("README release-version markers are reversed")
    region = text[start:end]
    for pattern in REFERENCE_PATTERNS:
        matches = list(re.finditer(pattern, region))
        if len(matches) != 1 or matches[0].group(2) != str(baseline):
            raise ReleaseError(
                "README version references must all match the baseline tag"
            )
    updated = region
    for pattern in REFERENCE_PATTERNS:
        updated = re.sub(
            pattern, lambda match: match[1] + str(version) + match[3], updated
        )
    return text[:start] + updated + text[end:]


def plan_release():
    head = git("rev-parse", "HEAD")
    versions = tuple(
        version
        for tag in git("tag", "--merged", head).splitlines()
        if (version := Version.from_tag(tag)) is not None
    )
    if not versions:
        raise ReleaseError("No reachable stable vMAJOR.MINOR.PATCH baseline tag")
    baseline = max(versions)
    messages = git("log", "--no-merges", "--format=%B%x00", f"v{baseline}..{head}")
    bump = max(
        (commit_bump(message.strip("\n")) for message in messages.split("\0")),
        default=0,
    )
    version = baseline.bumped(bump) if bump else None
    readme_path = Path("README.md")
    if readme_path.is_symlink():
        raise ReleaseError("README must be a regular tracked file, not a symlink")
    git("ls-files", "--error-unmatch", "--", "README.md")
    readme = readme_path.read_bytes().decode("utf-8")
    updated = versioned_readme(readme, baseline, version or baseline)
    return ReleasePlan(head, baseline, version, updated)


BOT_CONFIG = (
    "-c",
    "user.name=github-actions[bot]",
    "-c",
    "user.email=41898282+github-actions[bot]@users.noreply.github.com",
)


def require_clean_tree():
    if git("status", "--porcelain", "--untracked-files=all"):
        raise ReleaseError("Publish requires a clean worktree and index")


def remote_main():
    refs = git("ls-remote", "--refs", "origin", "refs/heads/main").splitlines()
    if len(refs) != 1:
        raise ReleaseError("origin/main must exist")
    return refs[0].split()[0]


def prepare_publish():
    require_clean_tree()
    if remote_main() != git("rev-parse", "HEAD"):
        return False
    git(
        "fetch",
        "--no-tags",
        "origin",
        "refs/heads/main:refs/remotes/origin/main",
        "refs/tags/*:refs/tags/*",
    )
    return git("rev-parse", "HEAD") == remote_main()


@contextmanager
def guarded_push_hooks(expected_head):
    original = Path(git("rev-parse", "--path-format=absolute", "--git-path", "hooks"))
    with tempfile.TemporaryDirectory(prefix="premise-release-hooks-") as temporary:
        root = Path(temporary)
        hooks = root / "hooks"
        hooks.mkdir()
        context = root / "context.json"
        context.write_text(
            json.dumps(
                {
                    "expected_head": expected_head,
                    "hooks_directory": str(original),
                    "git_shell": git("var", "GIT_SHELL_PATH"),
                    "git_config_parameters": os.environ.get("GIT_CONFIG_PARAMETERS"),
                }
            ),
            encoding="utf-8",
        )
        helper = Path(__file__).with_name("release_push.py").resolve()
        command = shlex.join([sys.executable, "-B", str(helper), str(context)])
        entries = tuple(original.iterdir()) if original.is_dir() else ()
        names = {entry.name for entry in entries} | {"pre-push"}
        for name in names:
            source = original / name
            target = hooks / name
            if name == "pre-push" or (source.is_file() and os.access(source, os.X_OK)):
                target.write_text(
                    f'#!/bin/sh\nexec {command} {shlex.quote(name)} "$@"\n',
                    encoding="utf-8",
                )
                target.chmod(0o700)
            else:
                target.symlink_to(source, target_is_directory=source.is_dir())
        yield hooks


def publish(plan):
    if plan.version is None:
        return plan.output("skipped")
    tag = f"v{plan.version}"
    if git("tag", "--list", tag) or git(
        "ls-remote", "--refs", "origin", f"refs/tags/{tag}"
    ):
        raise ReleaseError(f"Tag {tag} already exists; tags are immutable")
    require_clean_tree()
    if remote_main() != plan.head:
        return plan.output("stale")
    Path("README.md").write_bytes(plan.readme.encode("utf-8"))
    git("add", "--", "README.md")
    git(*BOT_CONFIG, "commit", "-m", f"chore(release): {tag}")
    git(*BOT_CONFIG, "tag", "-a", tag, "-m", f"Release {tag}")
    with guarded_push_hooks(plan.head) as hooks:
        git(
            "-c",
            f"core.hooksPath={hooks}",
            "push",
            "--atomic",
            "origin",
            "HEAD:refs/heads/main",
            f"refs/tags/{tag}:refs/tags/{tag}",
        )
    return {**plan.output("published"), "release_commit": git("rev-parse", "HEAD")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--publish",
        action="store_true",
        help="Commit README and atomically push main and tag",
    )
    args = parser.parse_args()
    try:
        if git("rev-parse", "--show-prefix"):
            raise ReleaseError("Run from the repository root")
        if git("rev-parse", "--is-shallow-repository") != "false":
            raise ReleaseError("Full Git history and stable tags are required")
        if args.publish and not prepare_publish():
            print(json.dumps({"status": "stale", "head": git("rev-parse", "HEAD")}))
            return 0
        plan = plan_release()
        result = (
            publish(plan)
            if args.publish
            else plan.output("planned" if plan.version else "skipped")
        )
        print(json.dumps(result))
    except (ReleaseError, OSError, UnicodeError) as error:
        print(f"Release refused: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
