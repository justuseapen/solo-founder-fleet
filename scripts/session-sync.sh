#!/opt/homebrew/bin/bash
# Session Sync Hook - Captures git changes and appends to agent state files
# Registered as a Claude Code Stop hook
# No LLM calls - pure bash/git

set -euo pipefail

# --- Configuration ---

# Domain routing: map file path patterns to agent state file names
DOMAIN_ROUTES=(
  "tests/:qa"
  "__tests__/:qa"
  ".test.:qa"
  ".spec.:qa"
  ".github/workflows/:devops"
  "Dockerfile:devops"
  "docker-compose:devops"
  "infrastructure/:devops"
  "deploy/:devops"
  "ci/:devops"
  "docs/:content"
  "public/:design"
  "assets/:design"
  ".css:design"
  ".scss:design"
  "src/:eng"
  "lib/:eng"
  "packages/:eng"
  ".ts:eng"
  ".tsx:eng"
  ".js:eng"
  ".jsx:eng"
  ".py:eng"
  ".go:eng"
  ".rs:eng"
  ".rb:eng"
)

MAX_FILES_PER_LAYER=50

# --- Guard clauses ---

# Must be in a git repo
git rev-parse --git-dir > /dev/null 2>&1 || exit 0

# Must have a HEAD (not an empty repo)
git rev-parse HEAD > /dev/null 2>&1 || exit 0

# Must have a .claude/state/ directory (project initialized)
STATE_DIR=".claude/state"
[ -d "$STATE_DIR" ] || exit 0

MARKER_FILE="$STATE_DIR/.last-sync-sha"
CURRENT_SHA=$(git rev-parse HEAD)

# --- Collect changes ---

COMMITS=""
COMMIT_COUNT=0
STAGED=""
UNSTAGED=""
UNTRACKED=""
UNTRACKED_COUNT=0

# Layer 1: Commits since last sync
if [ -f "$MARKER_FILE" ]; then
  LAST_SHA=$(cat "$MARKER_FILE")
  # Verify the SHA still exists (could be gone after rebase)
  if git cat-file -t "$LAST_SHA" > /dev/null 2>&1; then
    if [ "$LAST_SHA" != "$CURRENT_SHA" ]; then
      COMMITS=$(git log --oneline "$LAST_SHA".."$CURRENT_SHA" 2>/dev/null | head -n "$MAX_FILES_PER_LAYER")
      COMMIT_COUNT=$(git log --oneline "$LAST_SHA".."$CURRENT_SHA" 2>/dev/null | wc -l | tr -d ' ')
    fi
  else
    # SHA gone (rebase, etc.) - just note current HEAD
    COMMITS="(baseline SHA no longer exists - reset to current HEAD)"
  fi
else
  # First run - no baseline, just record marker
  COMMITS="(initial sync - no prior baseline)"
fi

# Layer 2: Staged but uncommitted
STAGED=$(git diff --cached --stat 2>/dev/null | head -n "$MAX_FILES_PER_LAYER")

# Layer 3: Unstaged modifications
UNSTAGED=$(git diff --stat 2>/dev/null | head -n "$MAX_FILES_PER_LAYER")

# Layer 3b: Untracked files
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -n "$MAX_FILES_PER_LAYER")
UNTRACKED_COUNT=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

# If nothing changed, just update marker and exit
if [ -z "$COMMITS" ] && [ -z "$STAGED" ] && [ -z "$UNSTAGED" ] && [ -z "$UNTRACKED" ]; then
  echo "$CURRENT_SHA" > "$MARKER_FILE"
  exit 0
fi

# --- Build sync block ---

TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")

build_sync_block() {
  local domain_label="$1"
  local block=""

  block="<!-- SESSION SYNC -->"$'\n'
  block+="## Session Changes ($TIMESTAMP)"$'\n'$'\n'

  if [ -n "$domain_label" ]; then
    block+="**Domain:** $domain_label"$'\n'$'\n'
  fi

  if [ -n "$COMMITS" ]; then
    block+="### Commits"$'\n'
    block+="\`\`\`"$'\n'
    block+="$COMMITS"$'\n'
    block+="\`\`\`"$'\n'
    if [ "$COMMIT_COUNT" -gt "$MAX_FILES_PER_LAYER" ]; then
      block+="... and $((COMMIT_COUNT - MAX_FILES_PER_LAYER)) more commits"$'\n'
    fi
    block+=$'\n'
  fi

  if [ -n "$STAGED" ]; then
    block+="### Staged (uncommitted)"$'\n'
    block+="\`\`\`"$'\n'
    block+="$STAGED"$'\n'
    block+="\`\`\`"$'\n'$'\n'
  fi

  if [ -n "$UNSTAGED" ]; then
    block+="### Working Directory (modified)"$'\n'
    block+="\`\`\`"$'\n'
    block+="$UNSTAGED"$'\n'
    block+="\`\`\`"$'\n'$'\n'
  fi

  if [ -n "$UNTRACKED" ]; then
    block+="### Untracked (new files)"$'\n'
    block+="\`\`\`"$'\n'
    block+="$UNTRACKED"$'\n'
    block+="\`\`\`"$'\n'
    if [ "$UNTRACKED_COUNT" -gt "$MAX_FILES_PER_LAYER" ]; then
      block+="... and $((UNTRACKED_COUNT - MAX_FILES_PER_LAYER)) more files"$'\n'
    fi
    block+=$'\n'
  fi

  block+="<!-- /SESSION SYNC -->"

  echo "$block"
}

# --- Route changes to domain state files ---

# Collect all changed file paths across all layers
ALL_FILES=""

if [ -f "$MARKER_FILE" ]; then
  LAST_SHA=$(cat "$MARKER_FILE")
  if git cat-file -t "$LAST_SHA" > /dev/null 2>&1 && [ "$LAST_SHA" != "$CURRENT_SHA" ]; then
    COMMIT_FILES=$(git diff --name-only "$LAST_SHA".."$CURRENT_SHA" 2>/dev/null || true)
    ALL_FILES+="${COMMIT_FILES}"$'\n'
  fi
fi

STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)
UNSTAGED_FILES=$(git diff --name-only 2>/dev/null || true)
UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null || true)

ALL_FILES+="${STAGED_FILES}"$'\n'
ALL_FILES+="${UNSTAGED_FILES}"$'\n'
ALL_FILES+="${UNTRACKED_FILES}"

# Determine which domains are affected
declare -A AFFECTED_DOMAINS

while IFS= read -r file; do
  [ -z "$file" ] && continue

  for route in "${DOMAIN_ROUTES[@]}"; do
    pattern="${route%%:*}"
    agent="${route##*:}"

    case "$file" in
      *"$pattern"*)
        AFFECTED_DOMAINS["$agent"]=1
        ;;
    esac
  done
done <<< "$ALL_FILES"

# --- Append sync blocks ---

# Always append to chief-of-staff
if [ -f "$STATE_DIR/chief-of-staff.md" ]; then
  echo "" >> "$STATE_DIR/chief-of-staff.md"
  build_sync_block "all" >> "$STATE_DIR/chief-of-staff.md"
fi

# Append to affected domain state files
for agent in "${!AFFECTED_DOMAINS[@]}"; do
  state_file="$STATE_DIR/$agent.md"
  if [ -f "$state_file" ]; then
    echo "" >> "$state_file"
    build_sync_block "$agent" >> "$state_file"
  fi
done

# --- Update marker ---

echo "$CURRENT_SHA" > "$MARKER_FILE"
