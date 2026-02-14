# Ruff Configuration Reference

This document explains the rule set, agent-specific settings, and override
patterns used by the shared `ruff-defaults.toml` in this repository.

## Rule set

The selected rules balance coverage with signal-to-noise ratio. They are
drawn from the Ruff documentation's recommended starting point and extended
with rules that catch the most common defects in AI-generated Python code.

### Core rules (E, W, F)

Pycodestyle errors/warnings and Pyflakes form the foundation. These catch
syntax issues, undefined names, unused imports, and basic style violations.
`E501` (line length) is explicitly ignored because the formatter handles it.

### Modernization (UP)

Pyupgrade rules rewrite legacy syntax to match your `target-version`. This
includes things like replacing `dict()` with `{}`, using f-strings instead
of `%` formatting, and adopting `X | Y` union syntax on Python 3.10+.

### Bug detection (B)

Flake8-bugbear catches real bugs that are easy to miss in review: mutable
default arguments (`B006`), `zip()` without `strict=True` (`B905`),
redundant exception handling, and similar patterns. AI agents produce
mutable defaults (`def process(items=[])`) frequently enough that this
rule set alone justifies its inclusion.

### Simplification (SIM)

Flake8-simplify flags unnecessarily complex constructs: `if x == True`
instead of `if x`, nested ternaries, collapsible `if` statements. Keeps
agent-generated code from accumulating accidental complexity.

### Import sorting (I)

Isort integration provides deterministic import ordering with effectively
zero false positives. Fully auto-fixable. Set `known-first-party` in your
project's `pyproject.toml` to ensure local imports are grouped correctly.

### Naming conventions (N)

PEP 8 naming rules enforce consistent casing: `snake_case` for functions
and variables, `PascalCase` for classes. Catches cross-language
contamination where agents write `camelCase` from JavaScript habits.

### Comprehensions (C4)

Prefers comprehensions and generator expressions over `map()`/`filter()`
calls and unnecessary `list()`/`dict()`/`set()` constructor wrapping.

### Security (S)

Flake8-bandit rules detect common security issues: hardcoded passwords,
`eval()` usage, insecure temp file creation. `S101` (assert in production
code) is relaxed in test files via `per-file-ignores`.

### Ruff-native rules (RUF)

Ruff's own rules, most notably `RUF100` which detects unused `# noqa`
comments. Also includes rules for mutable class variables and other
patterns unique to Ruff's analysis.

## Rules deliberately excluded

Some popular rule sets are excluded from the baseline because they are
either too noisy, redundant with other tooling, or context-dependent:

`FBT` (boolean trap) produces many false positives on legitimate keyword
arguments. `ANN` (type annotations) is redundant if you run mypy or
pyright separately. `COM` and `Q` (trailing commas and quote style)
conflict with `ruff format`. `D` (docstrings) is valuable for libraries
but too noisy for application code — enable it per-project if needed.
`PLR` (Pylint refactoring) includes rules like `PLR0913` (too many
arguments) that don't understand keyword-only parameters and `PLR2004`
(magic numbers) that flags well-known constants like HTTP status codes.

## Unfixable rules

`F401` (unused imports) and `F841` (unused variables) are marked
`unfixable` in the shared config. This is intentional and particularly
important for agent workflows.

When an AI agent auto-fixes `F401`, it may silently remove imports that
exist as intentional re-exports (common in `__init__.py` files, which are
separately handled via `per-file-ignores`) or imports needed for side
effects. Similarly, `F841` removal can delete variables that indicate
incomplete logic the agent should finish rather than clean up.

By marking these unfixable, the agent (or developer) sees the diagnostic
and must make a conscious decision. To override this in a specific project:

```toml
[tool.ruff.lint]
unfixable = []  # Allow all safe fixes
```

## Fix safety: --fix vs --unsafe-fixes

The pre-commit hook uses `--fix` which applies only safe fixes —
transformations that preserve runtime semantics. `--unsafe-fixes` enables
changes that may alter behavior: replacing `list(...)[0]` with
`next(iter(...))` (different on empty iterables), removing imports that
may have side effects, or simplifying expressions with edge-case
differences.

The rule: **never use `--unsafe-fixes` in automated or unattended
contexts**. If a specific unsafe fix is desirable, promote it explicitly:

```toml
[tool.ruff.lint]
extend-safe-fixes = ["UP038"]  # Promote a specific rule's fix to safe
```

## Per-project overrides

Ruff's `extend` merges configs, so your project's `pyproject.toml` can
add to or override any setting from `ruff-defaults.toml`:

```toml
[tool.ruff]
extend = "ruff-defaults.toml"
target-version = "py311"            # Override the default py312

[tool.ruff.lint]
extend-select = ["T20", "PT"]      # Add print-detection + pytest style
extend-ignore = ["N802"]           # Allow non-lowercase function names

[tool.ruff.lint.per-file-ignores]
"migrations/*" = ["E501", "N"]     # Relax rules for generated files

[tool.ruff.lint.isort]
known-first-party = ["myproject"]
```

## Claude Code PostToolUse hook

For real-time lint feedback during agent sessions, the community
`ruff-claude-hook` package runs ruff automatically after every file edit
and feeds errors back to the agent:

```bash
pip install ruff-claude-hook
```

In `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit",
      "hooks": [{"type": "command", "command": "ruff-claude-hook"}]
    }]
  }
}
```

This creates a tight correction loop where the agent reads the lint error,
opens the file, and fixes the issue within the same context window —
significantly more effective than catching issues only at commit time.
