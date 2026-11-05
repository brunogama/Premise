# Scaffold an Agent Repository

This guide documents the `scaffold-agent-repository` workflow for adopting or generating sealed agent guidance for a repository. The scaffold is driven by one JSON configuration. Given the same configuration and assets, it produces identical managed file bytes and SHA-256 hashes. Mechanical generation and verification do not require a model.

## Requirements

- macOS 27 or later, Swift 6.4 or later, and Git.
- Apple Intelligence enabled only for the optional `review` and `pipeline` operations. `generate`, `check`, `qa`, and `context` do not require a model.

## Adopt an existing repository

1. Inventory harnesses and skills:

   ```sh
   bootstrap --target <repository>
   ```

   Review the report and confirm every discovered harness and skill is accounted for.

2. Copy `assets/default.json` to a project-specific configuration file. Read `references/configuration.md` before changing its schema or adapter paths. Validate the configuration through the generator. Unknown harnesses, duplicate entries, empty fields, and control characters are rejected.

3. For a non-Swift target, generation adds only missing generic `AGENTS.md` guidance and `.agent-scaffold.json`; it does not add a Swift package, source code, tests, QA script, or CI.

## Preview and generate

Preview the managed file list before writing:

```sh
swift run --package-path <skill-root> scaffold generate \
  --config <config.json> --output <repository> --dry-run
```

Check that the preview contains the intended files. Then run the same command without `--dry-run`. Existing managed files that differ from generated output cause an error unless `--force` is authorized. `--preserve-existing` accepts local edits and cannot be combined with `--force`. Confirm every file listed by the preview exists afterward.

## Verify

For Swift packages and Xcode projects, run the mechanical checks:

```sh
swift run --package-path <skill-root> scaffold check \
  --config <config.json> --output <repository>
swift <repository>/scripts/qa_repository.swift <repository>
swift test --package-path <repository> --disable-xctest
```

For the non-Swift fallback, run `scaffold check` and the target project's native verification instead. Do not run the Swift QA script or Swift tests when the fallback did not generate them. Resolve or account for every failing command.

Give `<repository>/qa/QA_AGENT.md` to an independent reviewer and require the rubric in `references/qa-rubric.md`. A missing or blocked review is not a pass. Report each rubric category as PASS, FAIL, or NOT RUN with evidence, and list blocking issues. Model review is optional and separate from mechanical verification:

```sh
swift run --package-path <skill-root> scaffold doctor
swift run --package-path <skill-root> scaffold review \
  --output <repository> --report <review-report.json>
```

Before adopting the result, inspect the diff and confirm that every change is understood.

## Managed-file and safety behavior

- `scaffold check` and `qa` compare managed files against SHA-256 hashes recorded in `.agent-scaffold.json`. Drifted or tampered managed files fail verification.
- Path traversal and symlink resolution are refused at every path component.
- `--force` overwrites managed files; it does not promote candidate skills or install external sources.
- Each file is published from a staging descriptor, but generation is not an all-or-nothing transaction across the output tree.
- Model reviews use bounded context and validated in-scope findings. Unavailable models, malformed reports, or budget failures block a passing verdict.

## Harness paths

| Harness | Instructions | Skills | Commands | Agents |
| --- | --- | --- | --- | --- |
| Claude | `CLAUDE.md` | `.claude/skills/` | `.claude/commands/` | `.claude/agents/` |
| Pi | `AGENTS.md` and `CLAUDE.md` | `.pi/skills/` | `.pi/prompts/` | `.agents/agents/` |
| Codex | `AGENTS.md` | `.agents/skills/` | `.codex/prompts/` | `.agents/agents/` |

## References

- The installed skill's `README.md` contains CLI and development details.
- `references/configuration.md` documents configuration schema and adapter paths.
- `references/qa-rubric.md` defines the independent review rubric.
- `references/new-scaffolding.md` contains the original research.
