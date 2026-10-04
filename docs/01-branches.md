# 01. Branche par défaut et stratégie de branches

## Quoi

- La branche par défaut s'appelle `main`.
- Les changements passent par des **branches de feature courtes**, fusionnées dans `main` par PR.
- `main` est la branche déployée en production.

## Points du référentiel couverts

| Niveau | Point |
|---|---|
| L1 | Default branch set to main branch |
| L1 | Basic branching (main + features) |
| L1 | Main branch used to deploy to production |
| L2 | Feature branches short-lived (< 3 days) |

## Pourquoi

Tous les contrôles (protection, relecture, tests, analyses de sécurité) s'appliquent à **la branche par défaut**. Si la production part d'une autre branche, les contrôles ne protègent pas ce qui est réellement déployé.

## Comment

**Stratégie recommandée par défaut** : GitHub Flow.

```
main  ──●──────●──────●──────●──▶  (toujours déployable, déployée en prod)
         \    /  \    /
feature/  ●──●    ●──●             (courte, une PR, supprimée après merge)
```

**Si l'équipe a besoin d'une branche d'intégration** (`develop`, plusieurs environnements) : GitFlow simplifié, où `develop` reçoit les features et `main` reçoit les releases. Dans ce cas, **les deux branches** doivent être protégées (voir fiche 02, paramètre `ref_name`).

**Dans l'interface** : *Settings > General > Default branch*, et cocher *Automatically delete head branches*.

**En ligne de commande** :

```bash
R=<owner>/<repo>
gh api -X PATCH "repos/$R" -f default_branch=main -F delete_branch_on_merge=true
```

## Comment tester

```bash
gh api "repos/$R" --jq '{default_branch, delete_branch_on_merge}'
# attendu : "main" et true
```

Créer une branche, ouvrir une PR, la fusionner : la branche doit être supprimée automatiquement.

## Preuve

`default_branch == "main"` et `delete_branch_on_merge == true` dans la réponse de l'API.

## Pièges

- **Flux `develop` → `main`** avec `develop` comme branche par défaut : les alertes Dependabot et les analyses de code portent sur la branche par défaut. Une équipe qui supprime du code sur `develop` alors que `main` est la branche par défaut (ou l'inverse) voit des **alertes persister sur du code qu'elle croit supprimé**.
- Renommer `master` en `main` : GitHub redirige les anciens liens, mais les pipelines et les scripts qui référencent `master` doivent être mis à jour.
