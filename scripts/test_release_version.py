#!/usr/bin/env python3
"""Exercise the release command with disposable local Git repositories."""

import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

COMMAND = Path(__file__).with_name("release_version.py").resolve()
README = """Unrelated version 9.8.7 stays here.
<!-- release-version:start -->
Premise is versioned for Swift Package Manager. The current release is `1.0.2`;
.package(url: "https://github.com/brunogama/Premise.git", from: "1.0.2")
If you want to pin exactly to the `1.0.2` tag for package tracking, use `exact` instead:
.package(url: "https://github.com/brunogama/Premise.git", exact: "1.0.2")
In Xcode, set the version to `1.0.2`.
[Release tag v1.0.2](https://github.com/brunogama/Premise/tree/v1.0.2).
<!-- release-version:end -->
Unrelated macro URL /v1.0.2/binary.zip stays pinned.
"""


class ReleaseCommandTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="premise-release-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / "checkout"
        self.origin = self.root / "origin.git"
        self.env = {
            **os.environ,
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_AUTHOR_NAME": "Release test",
            "GIT_AUTHOR_EMAIL": "release-test@example.invalid",
            "GIT_COMMITTER_NAME": "Release test",
            "GIT_COMMITTER_EMAIL": "release-test@example.invalid",
        }
        self.git("init", "--bare", str(self.origin), cwd=self.root)
        self.git("init", "-b", "main", str(self.repo), cwd=self.root)
        (self.repo / "README.md").write_text(README)
        self.git("add", "README.md")
        self.git("commit", "-m", "chore: baseline")
        self.git("tag", "v1.0.2")
        self.git("remote", "add", "origin", str(self.origin))
        self.git("push", "-u", "origin", "main", "--tags")

    def git(self, *args, cwd=None):
        result = subprocess.run(
            ["git", *args],
            cwd=cwd or self.repo,
            env=self.env,
            text=True,
            capture_output=True,
            check=True,
        )
        return result.stdout.strip()

    def commit(self, message, push=True):
        self.git("commit", "--allow-empty", "-m", message)
        if push:
            self.git("push", "origin", "main")
        return self.git("rev-parse", "HEAD")

    def run_release(self, *args):
        return subprocess.run(
            [sys.executable, "-B", str(COMMAND), *args],
            cwd=self.repo,
            env=self.env,
            text=True,
            capture_output=True,
        )

    def release(self, *args):
        result = self.run_release(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def refused(self, *args):
        result = self.run_release(*args)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        return result.stderr

    def test_fix_plans_patch_without_mutating_files_or_refs(self):
        self.commit("fix: repair replay")
        before = self.git("show-ref")
        plan = self.release()
        self.assertEqual(plan["version"], "1.0.3")
        self.assertEqual(plan["status"], "planned")
        self.assertEqual(self.git("show-ref"), before)
        self.assertEqual((self.repo / "README.md").read_text(), README)
        self.assertEqual(self.git("status", "--porcelain"), "")

    def assert_version(self, messages, expected):
        for message in messages:
            self.commit(message)
        self.assertEqual(self.release()["version"], expected)

    def test_feat_plans_minor(self):
        self.assert_version(["feat(replay): add trace support"], "1.1.0")

    def test_mixed_case_feature_type_plans_minor(self):
        self.assert_version(["Feat: add option"], "1.1.0")

    def test_uppercase_fix_type_plans_patch(self):
        self.assert_version(["FIX: repair replay"], "1.0.3")

    def test_mixed_case_breaking_header_plans_major(self):
        self.assert_version(["ReFaCtOr(core)!: remove API"], "2.0.0")

    def test_mixed_case_type_with_uppercase_breaking_footer_plans_major(self):
        self.assert_version(
            ["Chore: revise API\n\nBREAKING CHANGE: rename replay"], "2.0.0"
        )

    def test_mixed_case_breaking_change_wins_over_lowercase_fix(self):
        self.assert_version(["Refactor!: remove API", "fix: unrelated repair"], "2.0.0")

    def test_lowercase_breaking_footer_does_not_request_major(self):
        self.assert_version(["fix: repair\n\nbreaking change: quoted example"], "1.0.3")

    def test_lowercase_hyphen_breaking_footer_does_not_request_major(self):
        self.assert_version(["fix: repair\n\nbreaking-change: quoted example"], "1.0.3")

    def test_breaking_header_plans_major_for_any_type(self):
        self.assert_version(["refactor(core)!: change API"], "2.0.0")

    def test_breaking_change_footer_plans_major(self):
        self.assert_version(
            ["fix: revise API\n\nBREAKING CHANGE: rename replay"], "2.0.0"
        )

    def test_breaking_hyphen_footer_plans_major(self):
        self.assert_version(
            ["chore: revise API\n\nBREAKING-CHANGE: rename replay"], "2.0.0"
        )

    def test_mixed_history_chooses_highest_bump(self):
        self.assert_version(
            ["fix: first", "feat: next", "docs!: new contract", "fix: last"], "2.0.0"
        )

    def test_features_win_over_fixes(self):
        self.assert_version(
            ["feat: new option", "fix: repair", "docs: explain"], "1.1.0"
        )

    def test_commit_content_is_not_executed_as_shell(self):
        self.assert_version(
            ["fix: $(touch injected) `touch injected` ; touch injected"], "1.0.3"
        )
        self.assertFalse((self.repo / "injected").exists())

    def test_docs_chore_and_nonconventional_history_does_not_publish(self):
        for message in (
            "docs: clarify",
            "chore: tidy",
            "Merge pull request #1",
            "update stuff",
        ):
            self.commit(message)
        before = self.git("show-ref")
        self.assertEqual(self.release("--publish")["status"], "skipped")
        self.assertEqual(self.git("show-ref"), before)
        self.assertEqual((self.repo / "README.md").read_text(), README)

    def test_nonconventional_breaking_prose_does_not_bump(self):
        self.assert_version(["Update docs\n\nBREAKING CHANGE: quoted example"], None)

    def test_merge_commit_analyzes_child_commits(self):
        self.git("switch", "-c", "feature")
        self.commit("feat: child feature", push=False)
        self.git("switch", "main")
        self.git("merge", "--no-ff", "feature", "-m", "Merge pull request #5")
        self.git("push", "origin", "main")
        self.assertEqual(self.release()["version"], "1.1.0")

    def test_highest_reachable_stable_baseline_ignores_other_tags(self):
        (self.repo / "README.md").write_text(README.replace("1.0.2", "1.0.10"))
        self.git("add", "README.md")
        self.commit("chore: released baseline", push=False)
        self.git("tag", "v1.0.10")
        self.commit("chore: newer commit", push=False)
        self.git("tag", "v1.0.3")
        self.git("tag", "v100.0.0-beta.1")
        self.git("tag", "v01.0.0")
        tree = self.git("rev-parse", "HEAD^{tree}")
        orphan = self.git("commit-tree", tree, "-m", "feat: unrelated root")
        self.git("tag", "v90.0.0", orphan)
        self.commit("fix: repair")
        self.assertEqual(self.release()["version"], "1.0.11")

    def test_no_valid_baseline_fails_without_bootstrapping(self):
        self.git("tag", "-d", "v1.0.2")
        self.commit("feat: add")
        before = self.git("show-ref")
        self.assertIn("baseline", self.refused())
        self.assertEqual(self.git("show-ref"), before)

    def test_publish_updates_only_owned_readme_and_pushes_annotated_tag(self):
        parent = self.commit("fix: repair")
        self.git("checkout", "--detach", parent)
        result = self.release("--publish")
        self.assertEqual(result["status"], "published")
        expected = README.replace("1.0.2", "1.0.3", 7)
        self.assertEqual((self.repo / "README.md").read_text(), expected)
        head = self.git("rev-parse", "HEAD")
        self.assertNotEqual(head, parent)
        self.assertEqual(self.git("rev-parse", "HEAD^"), parent)
        self.assertEqual(
            self.git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"),
            "README.md",
        )
        self.assertEqual(self.git("cat-file", "-t", "refs/tags/v1.0.3"), "tag")
        self.assertEqual(self.git("rev-parse", "v1.0.3^{}"), head)
        self.assertEqual(
            self.git("rev-parse", "refs/heads/main", cwd=self.origin), head
        )
        self.assertEqual(self.git("rev-parse", "v1.0.3^{}", cwd=self.origin), head)
        self.assertEqual(
            self.git("show", "main:README.md", cwd=self.origin), expected.rstrip()
        )
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_successful_publish_rerun_does_not_increment(self):
        self.commit("feat: add")
        self.release("--publish")
        before = self.git("show-ref")
        self.assertEqual(self.release("--publish")["status"], "skipped")
        self.assertEqual(self.git("show-ref"), before)
        self.assertEqual(self.git("tag", "--list"), "v1.0.2\nv1.1.0")

    def test_stale_checkout_skips_even_with_outdated_tracking_ref(self):
        old = self.commit("fix: first")
        self.commit("feat: later")
        self.git("checkout", "--detach", old)
        self.git("update-ref", "refs/remotes/origin/main", old)
        self.assertEqual(self.release("--publish")["status"], "stale")
        self.assertEqual(self.git("rev-parse", "HEAD"), old)
        self.assertEqual((self.repo / "README.md").read_text(), README)
        self.assertEqual(self.git("tag", "--list"), "v1.0.2")

    def test_unpushed_checkout_is_stale(self):
        self.commit("fix: unpushed", push=False)
        self.assertEqual(self.release("--publish")["status"], "stale")

    def test_dirty_tree_refuses_and_preserves_unrelated_staged_content(self):
        self.commit("fix: repair")
        (self.repo / "unrelated.txt").write_text("do not stage or commit me\n")
        self.git("add", "unrelated.txt")
        before = self.git("show-ref")
        self.assertIn("clean", self.refused("--publish"))
        self.assertEqual(self.git("show-ref"), before)
        self.assertEqual(self.git("diff", "--cached", "--name-only"), "unrelated.txt")
        self.assertEqual((self.repo / "README.md").read_text(), README)

    def test_unstaged_readme_edit_refuses_publish(self):
        self.commit("fix: repair")
        changed = README + "Keep the user's pending edit.\n"
        (self.repo / "README.md").write_text(changed)
        self.assertIn("clean", self.refused("--publish"))
        self.assertEqual((self.repo / "README.md").read_text(), changed)

    def test_readme_symlink_refuses_publish_without_writing_target(self):
        target = self.root / "external-readme.md"
        target.write_text(README)
        (self.repo / "README.md").unlink()
        (self.repo / "README.md").symlink_to(target)
        self.git("add", "README.md")
        self.commit("fix: repair")
        self.assertIn("symlink", self.refused("--publish"))
        self.assertEqual(target.read_text(), README)

    def test_untracked_file_refuses_publish(self):
        self.commit("fix: repair")
        (self.repo / "untracked.txt").write_text("keep me\n")
        self.assertIn("clean", self.refused("--publish"))
        self.assertEqual((self.repo / "untracked.txt").read_text(), "keep me\n")

    def assert_bad_readme_refused(self, readme):
        (self.repo / "README.md").write_text(readme)
        self.git("add", "README.md")
        self.commit("fix: repair")
        before = self.git("show-ref")
        self.assertIn("README", self.refused("--publish"))
        self.assertEqual(self.git("show-ref"), before)
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertEqual((self.repo / "README.md").read_text(), readme)

    def test_missing_markers_fail_safely(self):
        self.assert_bad_readme_refused(
            README.replace("<!-- release-version:start -->", "")
        )

    def test_reversed_markers_fail_safely(self):
        self.assert_bad_readme_refused(
            README.replace("release-version:start", "temporary")
            .replace("release-version:end", "release-version:start")
            .replace("temporary", "release-version:end")
        )

    def test_duplicate_markers_fail_safely(self):
        self.assert_bad_readme_refused(README + "<!-- release-version:end -->\n")

    def test_inconsistent_versions_fail_safely(self):
        self.assert_bad_readme_refused(README.replace('from: "1.0.2"', 'from: "1.0.1"'))

    def test_missing_version_reference_fails_safely(self):
        self.assert_bad_readme_refused(
            README.replace("[Release tag v1.0.2]", "[Release tag]")
        )

    def test_existing_unrelated_version_tag_is_immutable(self):
        self.commit("fix: repair")
        tree = self.git("rev-parse", "HEAD^{tree}")
        unrelated = self.git("commit-tree", tree, "-m", "chore: unrelated")
        self.git("tag", "v1.0.3", unrelated)
        self.git("push", "origin", "refs/tags/v1.0.3")
        self.git("tag", "-d", "v1.0.3")
        head = self.git("rev-parse", "HEAD")
        self.assertIn("exists", self.refused("--publish"))
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.assertEqual(self.git("rev-parse", "v1.0.3", cwd=self.origin), unrelated)
        self.assertEqual((self.repo / "README.md").read_text(), README)

    def test_preexisting_local_tag_is_not_moved_or_pushed(self):
        parent = self.commit("fix: repair")
        tree = self.git("rev-parse", "HEAD^{tree}")
        before = self.git("commit-tree", tree, "-m", "chore: unrelated local tag")
        self.git("tag", "v1.0.3", before)
        self.assertIn("exists", self.refused("--publish"))
        self.assertEqual(self.git("rev-parse", "HEAD"), parent)
        self.assertEqual(self.git("rev-parse", "v1.0.3"), before)
        self.assertEqual(self.git("tag", "--list", "v1.0.3", cwd=self.origin), "")

    def test_remote_without_atomic_support_publishes_neither_ref(self):
        parent = self.commit("fix: repair")
        self.git("config", "receive.advertiseAtomic", "false", cwd=self.origin)
        self.assertIn("atomic", self.refused("--publish"))
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), parent)
        self.assertEqual(self.git("tag", "--list", "v1.0.3", cwd=self.origin), "")

    def test_missing_remote_main_refuses_publish(self):
        self.commit("fix: repair")
        self.git("update-ref", "-d", "refs/heads/main", cwd=self.origin)
        self.assertIn("origin/main", self.refused("--publish"))
        self.assertEqual((self.repo / "README.md").read_text(), README)

    def test_shallow_clone_refuses_to_infer_release_history(self):
        self.commit("fix: repair")
        shallow = self.root / "shallow"
        self.git(
            "clone",
            "--depth",
            "1",
            "--branch",
            "main",
            self.origin.as_uri(),
            str(shallow),
            cwd=self.root,
        )
        self.repo = shallow
        self.assertIn("Full Git history", self.refused())

    def test_readme_bytes_outside_region_remain_unchanged(self):
        original = (README + "Trailing CRLF survives.\r\n").encode("utf-8")
        (self.repo / "README.md").write_bytes(original)
        self.git("add", "README.md")
        self.commit("fix: repair")
        self.release("--publish")
        self.assertEqual(
            (self.repo / "README.md").read_bytes(),
            original.replace(b"1.0.2", b"1.0.3", 7),
        )

    def test_atomic_rejection_does_not_publish_branch_or_tag(self):
        parent = self.commit("fix: repair")
        hook = self.origin / "hooks" / "pre-receive"
        hook.write_text('#!/bin/sh\necho "test rejects publication" >&2\nexit 1\n')
        hook.chmod(0o755)
        self.assertIn("reject", self.refused("--publish"))
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), parent)
        self.assertEqual(self.git("tag", "--list", "v1.0.3", cwd=self.origin), "")

    def test_main_race_does_not_partially_publish_tag(self):
        parent = self.commit("fix: repair")
        tree = self.git("rev-parse", "HEAD^{tree}")
        concurrent = self.git(
            "commit-tree", tree, "-p", parent, "-m", "chore: concurrent main"
        )
        self.git("push", "origin", f"{concurrent}:refs/heads/concurrent")
        hook = self.repo / ".git" / "hooks" / "pre-push"
        hook.write_text(
            f"#!/bin/sh\ngit --git-dir={shlex.quote(str(self.origin))} "
            f"update-ref refs/heads/main {concurrent} {parent}\n"
        )
        hook.chmod(0o755)
        self.assertIn("atomic", self.refused("--publish"))
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), concurrent)
        self.assertEqual(self.git("tag", "--list", "v1.0.3", cwd=self.origin), "")

    def test_tag_creation_race_does_not_publish_branch(self):
        parent = self.commit("fix: repair")
        hook = self.repo / ".git" / "hooks" / "pre-push"
        hook.write_text(
            f"#!/bin/sh\ngit --git-dir={shlex.quote(str(self.origin))} "
            f"update-ref refs/tags/v1.0.3 {parent}\n"
        )
        hook.chmod(0o755)
        self.assertIn("atomic", self.refused("--publish"))
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), parent)
        self.assertEqual(self.git("rev-parse", "v1.0.3", cwd=self.origin), parent)

    def test_before_advertisement_ancestor_rewind_is_not_overwritten(self):
        baseline = self.git("rev-parse", "HEAD")
        validated = self.commit("fix: repair replay")
        real_git = shutil.which("git")
        shim_dir = self.root / "shim"
        shim_dir.mkdir()
        shim = shim_dir / "git"
        shim.write_text(
            f"#!{sys.executable}\nimport os, subprocess, sys\n"
            "if 'push' in sys.argv[1:]:\n"
            f"    subprocess.run([{real_git!r}, '--git-dir={self.origin}', "
            f"'update-ref', 'refs/heads/main', {baseline!r}, {validated!r}], check=True)\n"
            f"os.execv({real_git!r}, [{real_git!r}, *sys.argv[1:]])\n"
        )
        shim.chmod(0o755)
        self.env = {**self.env, "PATH": str(shim_dir) + os.pathsep + self.env["PATH"]}
        self.assertIn("advertised", self.refused("--publish"))
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), baseline)
        self.assertEqual(self.git("tag", "--list", "v1.0.3", cwd=self.origin), "")

    def test_custom_default_pre_push_rejection_is_honored(self):
        parent = self.commit("fix: repair")
        trace = self.root / "rejected-push-trace.jsonl"
        self.env = {**self.env, "GIT_TRACE2_EVENT": str(trace)}
        hook = self.repo / ".git" / "hooks" / "pre-push"
        hook.write_text('#!/bin/sh\necho "custom pre-push rejection" >&2\nexit 37\n')
        hook.chmod(0o755)
        self.assertIn("custom pre-push rejection", self.refused("--publish"))
        events = [json.loads(line) for line in trace.read_text().splitlines()]
        self.assertTrue(
            any(
                event.get("event") == "child_exit" and event.get("code") == 37
                for event in events
            )
        )
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), parent)
        self.assertEqual(self.git("tag", "--list", "v1.0.3", cwd=self.origin), "")

    def install_observing_hooks(self, configured_path):
        hooks = self.root / "configured hooks"
        hooks.mkdir()
        log = self.root / "hook-observations.jsonl"
        source = (
            f"#!{sys.executable}\nimport json, os, subprocess, sys\n"
            f"with open({str(log)!r}, 'a') as output:\n"
            "    output.write(json.dumps({'hook': os.path.basename(sys.argv[0]), "
            "'argv': sys.argv[1:], 'stdin': sys.stdin.read(), "
            "'config': subprocess.check_output(['git', 'config', 'core.hooksPath'], text=True).strip(), "
            "'parameters': os.environ.get('GIT_CONFIG_PARAMETERS'), "
            "'cwd': os.getcwd()}) + '\\n')\n"
        )
        for name in ("pre-push", "reference-transaction"):
            path = hooks / name
            path.write_text(source)
            path.chmod(0o755)
        self.git("config", "core.hooksPath", configured_path)
        return hooks, log

    def assert_configured_hooks_preserved(self, configured_path):
        parent = self.commit("fix: repair")
        hooks, log = self.install_observing_hooks(configured_path)
        before = {path.name: path.read_bytes() for path in hooks.iterdir()}
        self.assertEqual(self.release("--publish")["status"], "published")
        events = [json.loads(line) for line in log.read_text().splitlines()]
        pre_push = [event for event in events if event["hook"] == "pre-push"]
        self.assertEqual(len(pre_push), 1)
        event = pre_push[0]
        self.assertEqual(event["argv"], ["origin", str(self.origin)])
        self.assertEqual(event["parameters"], self.env.get("GIT_CONFIG_PARAMETERS"))
        records = [line.split() for line in event["stdin"].splitlines()]
        head = self.git("rev-parse", "HEAD")
        tag = self.git("rev-parse", "v1.0.3")
        self.assertCountEqual(
            records,
            [
                ["HEAD", head, "refs/heads/main", parent],
                ["refs/tags/v1.0.3", tag, "refs/tags/v1.0.3", "0" * len(parent)],
            ],
        )
        self.assertTrue(all(event["config"] == configured_path for event in events))
        self.assertTrue(
            all(Path(event["cwd"]).resolve() == self.repo.resolve() for event in events)
        )
        callbacks = [
            event for event in events if event["hook"] == "reference-transaction"
        ]
        self.assertTrue(
            any(
                event["argv"] == ["committed"]
                and f"{head} refs/remotes/origin/main" in event["stdin"]
                for event in callbacks
            ),
            callbacks,
        )
        self.assertEqual(self.git("config", "core.hooksPath"), configured_path)
        self.assertEqual(
            {path.name: path.read_bytes() for path in hooks.iterdir()}, before
        )

    def test_absolute_configured_hooks_and_push_callbacks_are_preserved(self):
        self.assert_configured_hooks_preserved(str(self.root / "configured hooks"))

    def test_relative_configured_hooks_and_push_callbacks_are_preserved(self):
        self.assert_configured_hooks_preserved("../configured hooks")

    def test_existing_command_configuration_is_preserved_in_hooks(self):
        self.env = {
            **self.env,
            "GIT_CONFIG_PARAMETERS": "'test.release-sentinel'='original value'",
        }
        self.assert_configured_hooks_preserved("../configured hooks")

    def test_after_advertisement_ancestor_rewind_is_not_overwritten(self):
        baseline = self.git("rev-parse", "HEAD")
        validated = self.commit("fix: repair")
        hook = self.repo / ".git" / "hooks" / "pre-push"
        hook.write_text(
            f"#!/bin/sh\ngit --git-dir={shlex.quote(str(self.origin))} "
            f"update-ref refs/heads/main {baseline} {validated}\n"
        )
        hook.chmod(0o755)
        self.assertIn("atomic", self.refused("--publish"))
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), baseline)
        self.assertEqual(self.git("tag", "--list", "v1.0.3", cwd=self.origin), "")

    def test_configured_pre_push_rejection_is_honored(self):
        parent = self.commit("fix: repair")
        hooks, _ = self.install_observing_hooks("../configured hooks")
        (hooks / "pre-push").write_text(
            '#!/bin/sh\necho "configured pre-push rejection" >&2\nexit 41\n'
        )
        self.assertIn("configured pre-push rejection", self.refused("--publish"))
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), parent)
        self.assertEqual(self.git("tag", "--list", "v1.0.3", cwd=self.origin), "")

    def install_no_shebang_hook(self, exit_code, configured=False):
        hooks = (
            self.root / "shell hooks" if configured else self.repo / ".git" / "hooks"
        )
        hooks.mkdir(exist_ok=True)
        if configured:
            self.git("config", "core.hooksPath", str(hooks))
        log = self.root / "no-shebang-observations.jsonl"
        observer = (
            "import json, os, subprocess, sys; "
            f"output = open({str(log)!r}, 'a'); "
            "output.write(json.dumps({'argv': sys.argv[1:-1], 'shell': sys.argv[-1], "
            "'stdin': sys.stdin.read(), 'cwd': os.getcwd(), "
            "'parameters': os.environ.get('GIT_CONFIG_PARAMETERS'), "
            "'hooks': subprocess.run(['git', 'config', 'core.hooksPath'], "
            "text=True, capture_output=True).stdout.strip()}) + '\\n'); output.close()"
        )
        hook = hooks / "pre-push"
        hook.write_text(
            f'{shlex.quote(sys.executable)} -B -c {shlex.quote(observer)} "$@" "${{BASH-}}"\n'
            f"printf 'no-shebang hook exit {exit_code}\\n' >&2\nexit {exit_code}\n"
        )
        hook.chmod(0o755)
        return log

    def assert_no_shebang_observation(self, event, records, configured=False):
        self.assertEqual(event["argv"], ["origin", str(self.origin)])
        self.assertEqual(
            event["stdin"], "".join(" ".join(record) + "\n" for record in records)
        )
        self.assertEqual(Path(event["cwd"]).resolve(), self.repo.resolve())
        self.assertEqual(event["parameters"], self.env.get("GIT_CONFIG_PARAMETERS"))
        self.assertEqual(
            event["hooks"], str(self.root / "shell hooks") if configured else ""
        )

    def test_native_git_runs_executable_pre_push_without_shebang(self):
        baseline = self.git("rev-parse", "HEAD")
        validated = self.commit("fix: repair", push=False)
        log = self.install_no_shebang_hook(0)
        self.git("push", "origin", "main")
        events = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(events), 1)
        self.assert_no_shebang_observation(
            events[0],
            [
                ["refs/heads/main", validated, "refs/heads/main", baseline],
            ],
        )
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), validated)

    def test_guarded_publish_preserves_no_shebang_hook_success(self):
        validated = self.commit("fix: repair", push=False)
        self.env = {
            **self.env,
            "GIT_CONFIG_PARAMETERS": "'test.release-sentinel'='fallback preserved'",
        }
        log = self.install_no_shebang_hook(0)
        self.git("push", "origin", "main")
        self.assertEqual(self.release("--publish")["status"], "published")
        events = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(events), 2)
        self.assertEqual(events[1]["shell"], events[0]["shell"])
        head = self.git("rev-parse", "HEAD")
        tag = self.git("rev-parse", "v1.0.3")
        self.assert_no_shebang_observation(
            events[1],
            [
                ["HEAD", head, "refs/heads/main", validated],
                ["refs/tags/v1.0.3", tag, "refs/tags/v1.0.3", "0" * len(validated)],
            ],
        )
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), head)
        self.assertEqual(self.git("rev-parse", "v1.0.3^{}", cwd=self.origin), head)

    def test_guarded_publish_preserves_no_shebang_hook_rejection(self):
        validated = self.commit("fix: repair", push=False)
        log = self.install_no_shebang_hook(0, configured=True)
        self.git("push", "origin", "main")
        self.install_no_shebang_hook(29, configured=True)
        trace = self.root / "no-shebang-rejection-trace.jsonl"
        self.env = {**self.env, "GIT_TRACE2_EVENT": str(trace)}
        self.assertIn("no-shebang hook exit 29", self.refused("--publish"))
        events = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(events), 2)
        self.assertEqual(events[1]["shell"], events[0]["shell"])
        head = self.git("rev-parse", "HEAD")
        tag = self.git("rev-parse", "v1.0.3")
        self.assert_no_shebang_observation(
            events[1],
            [
                ["HEAD", head, "refs/heads/main", validated],
                ["refs/tags/v1.0.3", tag, "refs/tags/v1.0.3", "0" * len(validated)],
            ],
            configured=True,
        )
        trace_events = [json.loads(line) for line in trace.read_text().splitlines()]
        self.assertTrue(
            any(
                event.get("event") == "child_exit" and event.get("code") == 29
                for event in trace_events
            )
        )
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), validated)
        self.assertEqual(self.git("tag", "--list", "v1.0.3", cwd=self.origin), "")

    def assert_interpreter_failure_has_no_shell_fallback(self, interpreter):
        validated = self.commit("fix: repair")
        marker = self.root / "must-not-run-as-shell"
        hook = self.repo / ".git" / "hooks" / "pre-push"
        hook.write_text(
            f"#!{interpreter}\nprintf 'incorrect fallback' > {shlex.quote(str(marker))}\nexit 0\n"
        )
        hook.chmod(0o755)
        self.assertIn("Release hook refused", self.refused("--publish"))
        self.assertFalse(marker.exists())
        self.assertEqual(self.git("rev-parse", "main", cwd=self.origin), validated)
        self.assertEqual(self.git("tag", "--list", "v1.0.3", cwd=self.origin), "")

    def test_missing_hook_interpreter_does_not_fall_back_to_shell(self):
        self.assert_interpreter_failure_has_no_shell_fallback(
            self.root / "missing-interpreter"
        )

    def test_inaccessible_hook_interpreter_does_not_fall_back_to_shell(self):
        interpreter = self.root / "nonexecutable-interpreter"
        interpreter.write_text("#!/bin/sh\nexit 0\n")
        interpreter.chmod(0o644)
        self.assert_interpreter_failure_has_no_shell_fallback(interpreter)


if __name__ == "__main__":
    unittest.main()
