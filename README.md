# py-ai-precommit

A pre-commit baseline for Python projects that use AI coding agents (Claude
Code, Cursor, GitHub Copilot). Drop it into any repo with existing hooks
and get a curated set of checks tuned for the kinds of issues agents
produce most often: unused imports, mutable defaults, stale syntax,
inconsistent formatting, and security footguns.

## What's included

| File | Purpose |
|------|---------|
| `ruff-defaults.toml` | Shared ruff lint + format config with agent-safe defaults |
| `.pre-commit-hooks.yaml` | Hook definitions so this repo works as a pre-commit source |
| `.pre-commit-config.example.yaml` | Starter config for new repos (file hygiene + ruff + optional mypy) |
| `bootstrap.sh` | One-liner setup for consuming repos |
| `Makefile.consumer` | Drop-in Makefile with lint / fix / update targets |
| `CLAUDE.md.snippet` | Paste into your CLAUDE.md for agent integration |
| `docs/ruff.md` | Rule set rationale, override patterns, agent hook setup |

## Quick start

Run the bootstrap script in any Python repo:

```bash
curl -sSL https://raw.githubusercontent.com/m1no/py-ai-precommit/main/bootstrap.sh | bash
```

This downloads `ruff-defaults.toml`, `Makefile.consumer`, and creates a
starter `.pre-commit-config.yaml` if one doesn't exist. It also tells you
what to add to `pyproject.toml`. The only required change is the `extend`
directive:

```toml
[tool.ruff]
extend = "ruff-defaults.toml"

[tool.ruff.lint.isort]
known-first-party = ["myproject"]   # your package name(s)
```

Then install the hooks:

```bash
pre-commit install
```

## Adding to a repo with existing pre-commit hooks

If the repo already has a `.pre-commit-config.yaml`, the bootstrap script
leaves it untouched. Add the ruff hooks alongside your existing ones:

```yaml
repos:
  # ... your existing hooks ...

  # Ruff: lint then format (order matters when --fix is used)
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.15.1
    hooks:
      - id: ruff-check
        args: [--fix, --exit-non-zero-on-fix, --show-fixes]
      - id: ruff-format
```

Then fetch the shared config and wire it into your `pyproject.toml`:

```bash
curl -sSL https://raw.githubusercontent.com/m1no/py-ai-precommit/main/ruff-defaults.toml -o ruff-defaults.toml
```

That's it. The ruff hooks respect whatever config ruff finds in
`pyproject.toml`, which in turn extends `ruff-defaults.toml`. Your
existing hooks keep running exactly as before.

## Recommended hook ordering

Pre-commit runs hooks top-to-bottom within each repo block. The suggested
order is fast file-level checks first, then ruff (lint before format), and
slow tools like type checkers last. See `.pre-commit-config.example.yaml`
for a complete example.

## Per-project overrides

Ruff's `extend` merges configs. Your `pyproject.toml` can add rules,
ignore rules, or override settings without forking the shared config:

```toml
[tool.ruff]
extend = "ruff-defaults.toml"
target-version = "py311"

[tool.ruff.lint]
extend-select = ["T20", "PT"]      # add print-detection + pytest style
extend-ignore = ["N802"]           # allow non-lowercase function names

[tool.ruff.lint.per-file-ignores]
"migrations/*" = ["E501", "N"]     # relax rules for generated files
```

See [docs/ruff.md](docs/ruff.md) for the full rule set rationale, the
thinking behind `unfixable` rules, `--fix` vs `--unsafe-fixes` safety,
and Claude Code PostToolUse hook setup.

## Updating the shared config

When this repo publishes new defaults, pull them into consuming repos:

```bash
# Via the Makefile
make -f Makefile.consumer update

# Or directly
curl -sSL https://raw.githubusercontent.com/m1no/py-ai-precommit/main/ruff-defaults.toml -o ruff-defaults.toml
```

Review the diff, run `pre-commit run --all-files` to see what changed, and
commit.

## Agent integration

Copy `CLAUDE.md.snippet` into your project's `CLAUDE.md`, `AGENTS.md`, or
`.cursorrules` to tell the agent about the lint workflow and unfixable rule
behavior. For real-time lint feedback in Claude Code, see the PostToolUse
hook instructions in [docs/ruff.md](docs/ruff.md).

## CI

```yaml
# GitHub Actions
- uses: actions/checkout@v4
- uses: actions/setup-python@v5
- run: pip install pre-commit
- run: pre-commit run --all-files
```

Since `ruff-defaults.toml` is committed to the consuming repo, no extra
fetch step is needed in CI.

## Versioning

This repo follows semver. Major version bumps mean new rules that may
introduce violations in consuming repos. Minor bumps are safe config
improvements. Pin `rev` in your `.pre-commit-config.yaml` to control when
you adopt changes.
