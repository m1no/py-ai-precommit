#!/usr/bin/env bash
# bootstrap.sh — One-time setup for consuming repos.
#
# Downloads the shared ruff-defaults.toml and a starter .pre-commit-config.yaml
# into the repo root, and wires the extend directive into pyproject.toml.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/m1no/py-ai-precommit/main/bootstrap.sh | bash
#
# Or from a local clone:
#   ./bootstrap.sh
set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/m1no/py-ai-precommit/main"
PYPROJECT="pyproject.toml"

# ── Download shared configs ──────────────────────────────────────────────────
echo "Fetching shared pre-commit baseline..."

curl -sSL "$BASE_URL/ruff-defaults.toml" -o ruff-defaults.toml
echo "  → ruff-defaults.toml"

if [ ! -f ".pre-commit-config.yaml" ]; then
    curl -sSL "$BASE_URL/.pre-commit-config.example.yaml" -o .pre-commit-config.yaml
    echo "  → .pre-commit-config.yaml (starter config)"
else
    echo "  → .pre-commit-config.yaml already exists — skipping"
    echo "    See .pre-commit-config.example.yaml in the repo for the recommended hook setup."
fi

# ── Wire the extend directive into pyproject.toml ────────────────────────────
if [ ! -f "$PYPROJECT" ]; then
    cat > "$PYPROJECT" <<'EOF'
[tool.ruff]
extend = "ruff-defaults.toml"

[tool.ruff.lint.isort]
known-first-party = ["myproject"]   # ← Change this
EOF
    echo "  → Created $PYPROJECT with extend directive"
else
    if grep -q 'extend.*ruff-defaults' "$PYPROJECT"; then
        echo "  → $PYPROJECT already extends ruff-defaults.toml"
    else
        echo ""
        echo "Add the following to your $PYPROJECT under [tool.ruff]:"
        echo ""
        echo '  extend = "ruff-defaults.toml"'
        echo ""
        echo "And optionally set your first-party packages:"
        echo ""
        echo "  [tool.ruff.lint.isort]"
        echo '  known-first-party = ["myproject"]'
    fi
fi

echo ""
echo "Done. Commit ruff-defaults.toml and .pre-commit-config.yaml, then run:"
echo "  pre-commit install"
