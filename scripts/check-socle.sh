#!/usr/bin/env bash
# Contrôle de conformité du socle (fiches 01 à 05) sur un repo GitHub.
# Lit uniquement : aucune modification n'est faite.
#
# Usage : ./scripts/check-socle.sh <owner>/<repo>
# Code de retour : 0 si aucun point en échec, 1 sinon.
#
# Les règles sont lues via l'API "rules/branches" (rulesets du repo et de l'organisation),
# complétée par la protection de branche "classique" quand elle est lisible (droits Admin).
set -uo pipefail

R="${1:?Usage : $0 <owner>/<repo>}"
FAILS=0

line() { printf '%-6s %-44s %s\n' "$1" "$2" "$3"; }
pass() { line "OK" "$1" "$2"; }
fail() { line "KO" "$1" "$2"; FAILS=$((FAILS + 1)); }
info() { line "INFO" "$1" "$2"; }

repo_json="$(gh api "repos/$R" 2>/dev/null)" || { echo "Repo $R inaccessible avec le compte actif."; exit 1; }
BR="$(printf '%s' "$repo_json" | jq -r .default_branch)"
# En cas d'erreur, gh api écrit le message sur la sortie standard : on remplace alors
# toute la valeur par un repli, au lieu de concaténer erreur et repli.
rules="$(gh api "repos/$R/rules/branches/$BR" 2>/dev/null)" || rules='[]'
classic="$(gh api "repos/$R/branches/$BR/protection" 2>/dev/null)" || classic='{}'
protected_flag="$(gh api "repos/$R/branches/$BR" --jq .protected 2>/dev/null)" || protected_flag=false

# Règle présente dans un ruleset, ou équivalent dans la protection classique
has_rule() {
  printf '%s' "$rules" | jq -e --arg t "$1" 'any(.[]; .type == $t)' >/dev/null && return 0
  case "$1" in
    pull_request)           printf '%s' "$classic" | jq -e '.required_pull_request_reviews != null' >/dev/null ;;
    non_fast_forward)       printf '%s' "$classic" | jq -e '.allow_force_pushes.enabled == false' >/dev/null ;;
    deletion)               printf '%s' "$classic" | jq -e '.allow_deletions.enabled == false' >/dev/null ;;
    *) return 1 ;;
  esac
}
# Paramètre de la règle pull_request, depuis un ruleset ou la protection classique
param() {
  local v
  v="$(printf '%s' "$rules" | jq -r --arg t "$1" --arg p "$2" \
        '[.[] | select(.type == $t) | .parameters[$p]] | map(select(. != null)) | first // empty')"
  if [ -z "$v" ] && [ "$1" = "pull_request" ]; then
    case "$2" in
      required_approving_review_count) v="$(printf '%s' "$classic" | jq -r '.required_pull_request_reviews.required_approving_review_count // empty')" ;;
      require_last_push_approval)      v="$(printf '%s' "$classic" | jq -r '.required_pull_request_reviews.require_last_push_approval // empty')" ;;
      dismiss_stale_reviews_on_push)   v="$(printf '%s' "$classic" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // empty')" ;;
      require_code_owner_review)       v="$(printf '%s' "$classic" | jq -r '.required_pull_request_reviews.require_code_owner_reviews // empty')" ;;
    esac
  fi
  printf '%s' "$v"
}
exists()   { gh api "repos/$R/contents/$1" >/dev/null 2>&1; }

echo "Contrôle du socle : $R (branche par défaut : $BR)"
if [ "$protected_flag" = "true" ] && [ "$classic" = "{}" ] && ! has_rule pull_request; then
  echo "Note : la branche est protégée, mais une partie du détail n'est lisible qu'avec des droits Admin."
  echo "       Les points marqués KO ci-dessous peuvent être couverts par une protection non visible."
fi
echo
line "STATUT" "POINT" "DÉTAIL"
line "------" "-----" "------"

# 01. Branches
[ "$BR" = "main" ] && pass "Default branch set to main" "main" || fail "Default branch set to main" "branche par défaut : $BR"
[ "$(printf '%s' "$repo_json" | jq -r .delete_branch_on_merge)" = "true" ] \
  && pass "Branches fusionnées supprimées (L2)" "activé" \
  || info "Branches fusionnées supprimées (L2)" "désactivé"

# 02. Protection
has_rule pull_request     && pass "Main branch protected / changes via PR" "règle pull_request active" \
                          || fail "Main branch protected / changes via PR" "aucune règle pull_request"
has_rule non_fast_forward && pass "Force-push interdit" "règle non_fast_forward" \
                          || fail "Force-push interdit" "absent"
has_rule deletion         && pass "Suppression de main interdite" "règle deletion" \
                          || fail "Suppression de main interdite" "absent"

# 03. Relecture
approvals="$(param pull_request required_approving_review_count)"
[ "${approvals:-0}" -ge 1 ] 2>/dev/null && pass "At least 1 approval required" "$approvals approbation(s)" \
                                        || fail "At least 1 approval required" "${approvals:-0}"
[ "$(param pull_request require_last_push_approval)" = "true" ] \
  && pass "No self-approval (dernier push)" "require_last_push_approval" \
  || fail "No self-approval (dernier push)" "require_last_push_approval absent"
[ "$(param pull_request dismiss_stale_reviews_on_push)" = "true" ] \
  && pass "Approbation annulée après nouveau push" "activé" \
  || info "Approbation annulée après nouveau push" "désactivé"
codeowners=""
for p in .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS; do exists "$p" && codeowners="$p" && break; done
[ -n "$codeowners" ] && pass "CODEOWNERS présent" "$codeowners" || fail "CODEOWNERS présent" "absent"
[ "$(param pull_request require_code_owner_review)" = "true" ] \
  && pass "Relecture CODEOWNERS exigée (L2)" "activé" \
  || info "Relecture CODEOWNERS exigée (L2)" "désactivé"
template=""
for p in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md pull_request_template.md docs/pull_request_template.md .github/PULL_REQUEST_TEMPLATE; do
  exists "$p" && template="$p" && break
done
[ -n "$template" ] && pass "Review checklist available" "$template" || fail "Review checklist available" "modèle de PR absent"

# 04. CI et tests requis
checks="$(printf '%s' "$rules" | jq -r '[.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context] | join(", ")')"
[ -z "$checks" ] && checks="$(printf '%s' "$classic" | jq -r '(.required_status_checks.contexts // []) | join(", ")')"
[ -n "$checks" ] && pass "Failed tests BLOCK merge" "contrôles requis : $checks" \
                 || fail "Failed tests BLOCK merge" "aucun contrôle requis"
workflows="$(gh api "repos/$R/contents/.github/workflows" --jq 'length' 2>/dev/null)" || workflows=0
[ "${workflows:-0}" -ge 1 ] && pass "Automated build" "$workflows workflow(s)" || fail "Automated build" "aucun workflow"
last_run="$(gh api "repos/$R/actions/runs?branch=$BR&per_page=1" --jq '.workflow_runs[0].conclusion // "aucune exécution"' 2>/dev/null)" || last_run="inconnu"
[ "$last_run" = "success" ] && pass "Dernier pipeline sur $BR" "success" || info "Dernier pipeline sur $BR" "$last_run"

# 05. Secrets
ss="$(printf '%s' "$repo_json" | jq -r '.security_and_analysis.secret_scanning.status // "inconnu"')"
pp="$(printf '%s' "$repo_json" | jq -r '.security_and_analysis.secret_scanning_push_protection.status // "inconnu"')"
case "$ss" in enabled) pass "Secret scanning active" "enabled" ;; inconnu) info "Secret scanning active" "non lisible (droits Admin requis)" ;; *) fail "Secret scanning active" "$ss" ;; esac
case "$pp" in enabled) pass "Block push on secret (L2)" "enabled" ;; inconnu) info "Block push on secret (L2)" "non lisible (droits Admin requis)" ;; *) fail "Block push on secret (L2)" "$pp" ;; esac
if alerts="$(gh api "repos/$R/secret-scanning/alerts?state=open&per_page=100" --jq 'length' 2>/dev/null)"; then
  [ "$alerts" -eq 0 ] && pass "No hardcoded secrets (alertes ouvertes)" "0" || fail "No hardcoded secrets (alertes ouvertes)" "$alerts alerte(s)"
else
  info "No hardcoded secrets (alertes ouvertes)" "alertes non lisibles avec ce compte"
fi

echo
if [ "$FAILS" -eq 0 ]; then echo "Résultat : socle conforme."; else echo "Résultat : $FAILS point(s) en échec."; fi
[ "$FAILS" -eq 0 ]
