# 02. Protection de main

## Quoi

Un **ruleset** sur la branche par défaut qui :
- interdit de pousser directement : tout passe par une PR ;
- interdit la réécriture d'historique (force-push) et la suppression de la branche ;
- exige des contrôles verts avant merge (détaillé en fiche 04).

## Points du référentiel couverts

| Niveau | Point |
|---|---|
| L1 | Main branch protected |
| L1 | Changes via pull requests |
| L1 | Branch protection rules enforced |
| L3 | Immutable history on protected branches |

## Pourquoi

C'est le premier garde-fou. Sans lui, aucune autre règle ne s'applique vraiment : une gate de sécurité ou une relecture obligatoire peuvent être contournées par un push direct.

## Comment

Le ruleset est décrit dans [`rulesets/socle-main.json`](../rulesets/socle-main.json). Il cible `~DEFAULT_BRANCH`, c'est-à-dire la branche par défaut quel que soit son nom.

| Règle | Effet |
|---|---|
| `deletion` | La branche ne peut pas être supprimée |
| `non_fast_forward` | Pas de force-push |
| `pull_request` | Merge uniquement par PR (paramètres en fiche 03) |
| `required_status_checks` | Contrôles requis (fiche 04) |

**Rulesets ou « branch protection » classique ?** Les rulesets sont l'approche actuelle : plusieurs rulesets peuvent se cumuler, ils peuvent être définis au niveau de l'organisation et ils sont lisibles par tous les membres du repo.

**Dans l'interface** : *Settings > Rules > Rulesets > New branch ruleset*.

**En ligne de commande** : `scripts/apply-socle.sh` crée ou met à jour le ruleset.

```bash
./scripts/apply-socle.sh <owner>/<repo>
```

## Comment tester

Test négatif : un push direct doit être refusé.

```bash
git checkout main && git pull
echo "test" >> push-direct.txt && git add . && git commit -m "test push direct"
git push origin main
# attendu : remote rejected, "Changes must be made through a pull request"
git reset --hard origin/main
```

Test de force-push :

```bash
git push --force origin main
# attendu : refusé ("Cannot force-push to this branch")
```

## Preuve

Les règles actives sur la branche, y compris celles venant d'un ruleset d'organisation :

```bash
gh api "repos/<owner>/<repo>/rules/branches/main" --jq '.[].type'
# attendu : deletion, non_fast_forward, pull_request, required_status_checks
```

## Pièges

- **Comptes de service et bots** qui poussent sur `main` (bump de version, changelog) : ils seront bloqués. Les recenser avant d'activer, puis les ajouter en `bypass_actors` de façon explicite et limitée.
- **Administrateurs** : par défaut, aucun contournement n'est autorisé dans ce ruleset. C'est voulu. Toute exception doit apparaître dans `bypass_actors`.
- **Pas de mode test hors Enterprise** : sans `evaluate`, le ruleset bloque dès son activation. Prévenir l'équipe avant.
