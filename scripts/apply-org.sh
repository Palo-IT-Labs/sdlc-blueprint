#!/usr/bin/env bash
# Couche organisation : crée la propriété "sdlc-profile" et le ruleset d'organisation
# qui s'applique à tout repo portant sdlc-profile=standard.
# Une fois en place, une équipe n'a qu'à donner cette propriété à son repo.
#
# Usage   : ./scripts/apply-org.sh <organisation>
# Options : DRY_RUN=1   affiche les appels sans les exécuter
#
# Prérequis : rôle Owner sur l'organisation, gh connecté avec le scope admin:org.
# Statut   : non encore éprouvé sur une organisation réelle. Lancer d'abord avec DRY_RUN=1.
set -euo pipefail

ORG="${1:?Usage : $0 <organisation>}"
DRY_RUN="${DRY_RUN:-0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULESET_FILE="$ROOT/org/ruleset-sdlc-standard.json"
RULESET_NAME="$(jq -r .name "$RULESET_FILE")"

api_write() {
  if [ "$DRY_RUN" = "1" ]; then printf '  [dry-run] gh api -X %s %s\n' "$1" "$2"; cat >/dev/null; return 0; fi
  gh api -X "$1" "$2" --input - >/dev/null
}

echo "== Propriété personnalisée 'sdlc-profile'"
printf '%s' '{"value_type":"single_select","allowed_values":["standard"],"description":"Profil SDLC appliqué au repo","values_editable_by":"org_and_repo_actors"}' \
  | api_write PUT "orgs/$ORG/properties/schema/sdlc-profile"
echo "  OK"

echo "== Ruleset d'organisation '$RULESET_NAME'"
existing="$(gh api "orgs/$ORG/rulesets" --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" 2>/dev/null || true)"
if [ -n "$existing" ]; then
  api_write PUT "orgs/$ORG/rulesets/$existing" < "$RULESET_FILE"
  echo "  mis à jour (id $existing)"
else
  api_write POST "orgs/$ORG/rulesets" < "$RULESET_FILE"
  echo "  créé"
fi

echo
echo "Pour faire entrer un repo dans le périmètre :"
echo "  gh api -X PATCH repos/$ORG/<repo>/properties/values -f 'properties[][property_name]=sdlc-profile' -f 'properties[][value]=standard'"
echo "ou, dans le repo : Settings > Custom properties."
