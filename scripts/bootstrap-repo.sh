#!/usr/bin/env bash
# Ouvre une PR d'amorçage dans un repo d'équipe : ajoute les fichiers SDLC manquants
# (workflow d'appel, .sdlc.yml, CODEOWNERS, modèle de PR). L'équipe relit et fusionne.
# Les fichiers déjà présents ne sont jamais modifiés.
#
# Usage   : ./scripts/bootstrap-repo.sh <owner>/<repo>
# Options : TEAM="@org/equipe"       relecteurs à inscrire dans CODEOWNERS
#           BLUEPRINT_ORG="mon-org"  organisation qui héberge sdlc-blueprint (défaut : owner du repo)
#           ADD_TOPIC=1              ajoute le topic "sdlc" au repo (droits Admin requis)
#
# Prérequis : gh connecté, droit d'écriture sur le repo.
set -euo pipefail

R="${1:?Usage : $0 <owner>/<repo>}"
OWNER="${R%%/*}"
BLUEPRINT_ORG="${BLUEPRINT_ORG:-$OWNER}"
TEAM="${TEAM:-}"
BRANCH="sdlc/bootstrap"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$ROOT/templates/repo"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== Clonage de $R"
gh repo clone "$R" "$WORK/repo" -- --quiet
cd "$WORK/repo"
git checkout -q -b "$BRANCH"

added=()
add_file() {   # source, destination
  if [ -e "$2" ]; then
    echo "  déjà présent, conservé : $2"
  else
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
    added+=("$2")
    echo "  ajouté : $2"
  fi
}

echo "== Ajout des fichiers manquants"
add_file "$TPL/.github/workflows/sdlc.yml"        ".github/workflows/sdlc.yml"
add_file "$TPL/.sdlc.yml"                          ".sdlc.yml"
add_file "$TPL/.github/pull_request_template.md"  ".github/pull_request_template.md"
if [ -e ".github/CODEOWNERS" ] || [ -e "CODEOWNERS" ] || [ -e "docs/CODEOWNERS" ]; then
  echo "  déjà présent, conservé : CODEOWNERS"
else
  add_file "$TPL/.github/CODEOWNERS" ".github/CODEOWNERS"
fi

# Personnalisation des fichiers ajoutés
for f in "${added[@]}"; do
  sed -i.bak "s#__ORG__/sdlc-blueprint#$BLUEPRINT_ORG/sdlc-blueprint#g" "$f" && rm -f "$f.bak"
  if [ -n "$TEAM" ] && [ "$f" = ".github/CODEOWNERS" ]; then
    sed -i.bak "s#@__ORG__/__TEAM__#$TEAM#g" "$f" && rm -f "$f.bak"
  fi
done

if [ ${#added[@]} -eq 0 ]; then
  echo "== Rien à ajouter : le repo contient déjà tous les fichiers SDLC."
  exit 0
fi

echo "== Création de la PR"
git add "${added[@]}"
git commit -q -m "chore(sdlc): amorçage du SDLC Blueprint"
git push -q -u origin "$BRANCH"

body="Cette PR ajoute les fichiers qui raccordent le repo au SDLC Blueprint :

$(printf -- '- `%s`\n' "${added[@]}")

**À vérifier avant de fusionner :**
- \`.github/CODEOWNERS\` : les relecteurs doivent être une équipe d'au moins deux personnes.
- \`.sdlc.yml\` : stack, commandes, identifiant ServiceNow et liens de documentation.

Après la fusion, chaque PR lancera build, tests et contrôles via le pipeline commun.
Aucun fichier existant n'a été modifié."

gh pr create --repo "$R" --head "$BRANCH" --title "chore(sdlc): amorçage du SDLC Blueprint" --body "$body"

if [ "${ADD_TOPIC:-0}" = "1" ]; then
  gh repo edit "$R" --add-topic sdlc && echo "  topic 'sdlc' ajouté : le repo entre dans le périmètre du collecteur"
fi
