#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/common.sh"

usage="Usage: check-prerequisites.sh [--paths-only] [--require-spec] [--require-plan] [--require-tasks] [--include-tasks] [--template NAME]"
PATHS_ONLY=false; REQUIRE_SPEC=false; REQUIRE_PLAN=false; REQUIRE_TASKS=false; INCLUDE_TASKS=false; TEMPLATE_NAME=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --paths-only) PATHS_ONLY=true ;;
        --require-spec) REQUIRE_SPEC=true ;;
        --require-plan) REQUIRE_PLAN=true ;;
        --require-tasks) REQUIRE_TASKS=true ;;
        --include-tasks) INCLUDE_TASKS=true ;;
        --template) shift; TEMPLATE_NAME="${1:?--template requires a name}" ;;
        -h|--help) echo "$usage"; exit 0 ;;
        *) echo "ERROR: Unknown option '$1'. $usage" >&2; exit 1 ;;
    esac
    shift
done

REPO_ROOT="$(project_root)"
STATE="$REPO_ROOT/.stratum/state.json"
[[ -f "$STATE" ]] || { echo "ERROR: $STATE not found. Run st-define first." >&2; exit 1; }
FEATURE_DIR="$(sed -n 's/.*"feature_directory"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE" | head -n 1)"
[[ -n "$FEATURE_DIR" ]] || { echo "ERROR: No feature_directory in $STATE. Run st-define first." >&2; exit 1; }
[[ "$FEATURE_DIR" == /* ]] || FEATURE_DIR="$REPO_ROOT/$FEATURE_DIR"
FEATURE_DIR="${FEATURE_DIR%/}"

if ! $PATHS_ONLY; then
    [[ -d "$FEATURE_DIR" ]] || { echo "ERROR: Feature directory not found: $FEATURE_DIR. Run st-define first." >&2; exit 1; }
    $REQUIRE_SPEC && [[ ! -f "$FEATURE_DIR/spec.md" ]] && { echo "ERROR: spec.md not found in $FEATURE_DIR. Run st-define first." >&2; exit 1; }
    $REQUIRE_PLAN && [[ ! -f "$FEATURE_DIR/plan.md" ]] && { echo "ERROR: plan.md not found in $FEATURE_DIR. Run st-plan first." >&2; exit 1; }
    $REQUIRE_TASKS && [[ ! -f "$FEATURE_DIR/tasks.md" ]] && { echo "ERROR: tasks.md not found in $FEATURE_DIR. Run st-plan first." >&2; exit 1; }
fi

docs=()
[[ -f "$FEATURE_DIR/research.md" ]] && docs+=("research.md")
[[ -f "$FEATURE_DIR/data-model.md" ]] && docs+=("data-model.md")
[[ -n "$(ls -A "$FEATURE_DIR/contracts" 2>/dev/null)" ]] && docs+=("contracts/")
[[ -f "$FEATURE_DIR/quickstart.md" ]] && docs+=("quickstart.md")
$INCLUDE_TASKS && [[ -f "$FEATURE_DIR/tasks.md" ]] && docs+=("tasks.md")
json_docs=""
for d in "${docs[@]}"; do json_docs+="\"$d\","; done

TEMPLATE=""
[[ -n "$TEMPLATE_NAME" ]] && TEMPLATE="$("$SCRIPT_DIR/resolve-template.sh" "$TEMPLATE_NAME")"

printf '{"REPO_ROOT":"%s","FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s","AVAILABLE_DOCS":[%s],"TEMPLATE":"%s"}\n' \
    "$(json_escape "$REPO_ROOT")" "$(json_escape "$FEATURE_DIR")" "$(json_escape "$FEATURE_DIR/spec.md")" \
    "$(json_escape "$FEATURE_DIR/plan.md")" "$(json_escape "$FEATURE_DIR/tasks.md")" "${json_docs%,}" "$(json_escape "$TEMPLATE")"
