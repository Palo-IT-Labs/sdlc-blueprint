# 04. CI et tests requis avant merge

## Quoi

- Chaque PR déclenche un **build** et les **tests**.
- Ce contrôle est **requis** : s'il échoue, le merge est impossible.
- Les résultats des tests sont consultables dans la PR.
- Le pipeline est un **workflow partagé** (ce repo), appelé par un workflow de quelques lignes dans chaque repo.

## Points du référentiel couverts

| Niveau | Point |
|---|---|
| L1 | Automated build |
| L1 | Build on pull requests |
| L1 | Basic automated tests |
| L1 | Failed tests BLOCK merge |
| L1 | Test results visible |
| L1 | Pipeline logs accessible |
| L2 | Pipeline < 20 min end-to-end |

## Pourquoi

Un test qui échoue sans bloquer le merge n'est qu'un avertissement, que l'on finit par ignorer. Le rendre requis transforme le test en garde-fou. Centraliser le pipeline évite que chaque équipe maintienne sa propre copie, qui finit par diverger.

## Comment

### Le workflow partagé

[`.github/workflows/reusable-ci-java.yml`](../.github/workflows/reusable-ci-java.yml) : build et tests Maven, publication des rapports de tests.

### Le workflow d'appel dans le repo d'équipe

[`templates/repo/.github/workflows/ci.yml`](../templates/repo/.github/workflows/ci.yml) :

```yaml
jobs:
  ci:
    uses: <org>/sdlc-blueprint/.github/workflows/reusable-ci-java.yml@main
    with:
      java-version: "21"
```

### Rendre le contrôle requis

Le nom du contrôle combine le job appelant et le job appelé : **`ci / build-test`**. C'est ce nom que le ruleset exige (`required_status_checks`). `scripts/apply-socle.sh` le renseigne ; il est modifiable avec la variable `CHECK_CONTEXT`.

`strict_required_status_checks_policy: true` impose que la branche soit à jour avec `main` avant le merge : les tests portent sur le code réellement fusionné.

## Comment tester

1. Ouvrir une PR qui casse un test (par exemple, changer la valeur attendue dans un test).
2. Le contrôle `ci / build-test` passe au rouge, le merge est bloqué.
3. Corriger, pousser : le contrôle repasse au vert.

```bash
gh pr checks <numero>
```

## Preuve

```bash
gh api "repos/<owner>/<repo>/rules/branches/main" \
  --jq '.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'
# attendu : ci / build-test

gh run list --repo <owner>/<repo> --workflow ci.yml --branch main --limit 1 --json conclusion
```

## Pièges

- **Nom du contrôle différent** de celui exigé : la PR attend indéfiniment un contrôle qui n'arrivera jamais (« Expected — Waiting for status to be reported »). Vérifier le nom exact dans l'onglet *Checks* de la première PR, puis l'ajuster.
- **Workflow partagé dans un repo privé** : autoriser l'accès dans le repo central (*Settings > Actions > General > Access*).
- **Version du workflow partagé** : `@main` convient pour tester. En usage réel, référencer une version (`@v1`) pour qu'une évolution du workflow central ne casse pas les équipes sans prévenir.
- **Tests longs ou instables** : un contrôle requis lent ou aléatoire pousse les équipes à le contourner. Viser moins de 15 minutes et traiter les tests instables en priorité.
