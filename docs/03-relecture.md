# 03. Relecture obligatoire

## Quoi

- Toute PR vers `main` exige **au moins une approbation**.
- L'approbation est **invalidée** si de nouveaux commits sont poussés après.
- Le **dernier push** doit être approuvé par une autre personne que son auteur.
- Les fils de discussion doivent être résolus avant merge.
- Un fichier **CODEOWNERS** désigne les relecteurs par zone du code.
- Un **modèle de PR** porte la checklist de relecture.

## Points du référentiel couverts

| Niveau | Point |
|---|---|
| L1 | Pull requests mandatory |
| L1 | At least 1 approval required |
| L1 | No self-approval |
| L1 | Review checklist available |
| L1 | Automated checks pass before review |
| L2 | CODEOWNERS enforced per critical path |
| L2 | Review checklist enforced in PR template |

## Pourquoi

Deux regards sur chaque changement : c'est la protection principale contre les erreurs, les failles et les secrets oubliés. Elle devient indispensable quand du code est produit par un assistant ou un agent IA : **un agent qui a « pensé » le code ne dispense pas d'une relecture humaine**.

## Comment

### Paramètres de la règle `pull_request` (dans `rulesets/socle-main.json`)

| Paramètre | Valeur | Effet |
|---|---|---|
| `required_approving_review_count` | 1 | Au moins une approbation |
| `dismiss_stale_reviews_on_push` | true | Un nouveau commit annule les approbations |
| `require_last_push_approval` | true | Celui qui a poussé en dernier ne peut pas valider seul |
| `require_code_owner_review` | true | Un propriétaire de code (CODEOWNERS) doit approuver |
| `required_review_thread_resolution` | true | Les commentaires doivent être traités |

GitHub empêche déjà l'auteur d'une PR de l'approuver. `require_last_push_approval` ferme l'autre porte : pousser un commit sur la PR de quelqu'un d'autre, puis l'approuver.

### Fichiers à ajouter dans le repo

Ils sont dans [`templates/repo/.github/`](../templates/repo/.github/) :
- `CODEOWNERS` : remplacer les comptes d'exemple par une **équipe** GitHub (par exemple `@org/equipe-api`) plutôt que par des personnes ;
- `pull_request_template.md` : description, lien vers la story, checklist de relecture.

## Comment tester

1. Créer une branche, modifier un fichier, ouvrir une PR.
2. **Sans approbation** : le bouton *Merge* est bloqué (« Review required »).
3. Le relecteur approuve. Pousser un nouveau commit : l'approbation disparaît.
4. Le relecteur approuve à nouveau : le merge devient possible une fois les contrôles verts.

```bash
gh pr view <numero> --json reviewDecision,mergeStateStatus
# avant approbation : "REVIEW_REQUIRED", "BLOCKED"
```

## Preuve

```bash
gh api "repos/<owner>/<repo>/rules/branches/main" \
  --jq '.[] | select(.type=="pull_request") | .parameters'
```

Et la présence de `CODEOWNERS` et du modèle de PR (vérifiés par `scripts/check-socle.sh`).

## Pièges

- **Équipe d'une seule personne** : la règle bloque tout merge. Solutions, par ordre de préférence :
  1. un relecteur d'une autre équipe ou le tech lead, ajouté dans CODEOWNERS ;
  2. une exception explicite et datée (`bypass_actors` avec `bypass_mode: pull_request`), validée par le responsable.

  Ne jamais retirer la règle silencieusement.
- **CODEOWNERS qui ne désigne que l'auteur** : avec `require_code_owner_review`, sa PR ne peut pas être validée. Désigner une équipe d'au moins deux personnes.
- **Tester seul** : impossible d'approuver sa propre PR. Prévoir un collègue ou un second compte pour les tests.
- **CODEOWNERS invalide** (compte inexistant, équipe sans accès au repo) : GitHub l'ignore sans bloquer. Vérifier l'onglet *Code* du fichier, qui signale les erreurs.
