#!/usr/bin/env bash
# Applique le socle (fiches 01 à 05) sur un repo GitHub.
#
# Usage   : ./scripts/apply-socle.sh <owner>/<repo>
# Options : CHECK_CONTEXT="sdlc / build-test"   nom du contrôle requis
#           REQUIRE_CODE_OWNER=false          désactive la relecture obligatoire par CODEOWNERS
#           DRY_RUN=1                         affiche les appels sans les exécuter
#
# Prérequis : gh connecté au bon compte, jq, droits Admin sur le repo.
set -euo pipefail

R="${1:?Usage : $0 <owner>/<repo>}"
CHECK_CONTEXT="${CHECK_CONTEXT:-sdlc / build-test}"
REQUIRE_CODE_OWNER="${REQUIRE_CODE_OWNER:-true}"
DRY_RUN="${DRY_RUN:-0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULESET_FILE="$ROOT/rulesets/socle-main.json"
RULESET_NAME="$(jq -r .name "$RULESET_FILE")"

step() { printf '\n== %s\n' "$*"; }
ok()   { printf '  OK   %s\n' "$*"; }
warn() { printf '  !!   %s\n' "$*"; }

# Appel API en écriture : method, chemin, corps JSON sur l'entrée standard (optionnel)
api_write() {
  local method="$1" path="$2"
  if [ "$DRY_RUN" = "1" ]; then
    printf '  [dry-run] gh api -X %s %s\n' "$method" "$path"
    cat >/dev/null
    return 0
  fi
  gh api -X "$method" "$path" --input - >/dev/null
}

step "Vérifications préalables"
gh auth status >/dev/null 2>&1 || { warn "gh n'est pas connecté"; exit 1; }
admin="$(gh api "repos/$R" --jq .permissions.admin 2>/dev/null || echo "false")"
if [ "$admin" != "true" ]; then
  warn "Droits Admin requis sur $R (compte actif : $(gh api user --jq .login))"
  exit 1
fi
ok "Droits Admin sur $R"

step "01. Branche par défaut et suppression des branches fusionnées"
if gh api "repos/$R/branches/main" >/dev/null 2>&1; then
  printf '{"default_branch":"main","delete_branch_on_merge":true}' | api_write PATCH "repos/$R"
  ok "Branche par défaut : main ; suppression automatique des branches fusionnées"
else
  warn "La branche main n'existe pas encore : pousser un premier commit sur main, puis relancer"
fi

step "02 à 04. Ruleset '$RULESET_NAME' (protection, relecture, contrôle requis '$CHECK_CONTEXT')"
payload="$(jq --arg ctx "$CHECK_CONTEXT" --argjson owner "$REQUIRE_CODE_OWNER" '
  (.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks) = [{"context": $ctx}]
  | (.rules[] | select(.type == "pull_request") | .parameters.require_code_owner_review) = $owner
' "$RULESET_FILE")"
existing="$(gh api "repos/$R/rulesets?includes_parents=false" \
  --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" 2>/dev/null || true)"
if [ -n "$existing" ]; then
  printf '%s' "$payload" | api_write PUT "repos/$R/rulesets/$existing"
  ok "Ruleset mis à jour (id $existing)"
else
  printf '%s' "$payload" | api_write POST "repos/$R/rulesets"
  ok "Ruleset créé"
fi

step "05. Détection des secrets et blocage au push"
secrets_payload='{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}'
if out="$(printf '%s' "$secrets_payload" | api_write PATCH "repos/$R" 2>&1)"; then
  ok "Secret scanning et push protection activés"
else
  warn "Activation refusée par GitHub (licence requise sur un repo privé ?) : $out"
fi

step "Terminé"
echo "  Vérifier avec : $ROOT/scripts/check.sh $R"
