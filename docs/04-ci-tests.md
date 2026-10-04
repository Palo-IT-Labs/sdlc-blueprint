# 04. CI et tests requis avant merge

## Quoi

- Chaque PR déclenche l'installation des dépendances, le **build** et les **tests**.
- Ce contrôle est **requis** : s'il échoue, le merge est impossible.
- Les résultats des tests sont résumés dans la PR.
- Le pipeline est **commun et générique** : il vit dans ce repo, détecte la stack du projet et s'adapte via `.sdlc.yml`. Le repo d'équipe ne contient qu'un workflow d'appel de quelques lignes.

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

Un test qui échoue sans bloquer le merge n'est qu'un avertissement, que l'on finit par ignorer. Le rendre requis transforme le test en garde-fou. Un pipeline commun évite que chaque équipe maintienne sa propre copie, qui finit par diverger.

## Comment

### Le pipeline commun

[`.github/workflows/sdlc.yml`](../.github/workflows/sdlc.yml) enchaîne deux jobs :

| Job | Rôle |
|---|---|
| `detect` | Lit `.sdlc.yml` s'il existe, détecte la stack, choisit les commandes |
| `build-test` | Installe l'outillage (Java, Node, Python ou .NET), puis installation, build, tests et résumé |

**Détection de la stack** (si `stack: auto` ou pas de `.sdlc.yml`) :

| Fichier trouvé | Stack | Commande de test par défaut |
|---|---|---|
| `pom.xml` | `java-maven` | `./mvnw -B -ntp verify` (ou `mvn`) |
| `build.gradle(.kts)` | `java-gradle` | `./gradlew build` (ou `gradle`) |
| `package.json` | `node` | `npm test --if-present` (pnpm ou yarn selon le fichier de verrou) |
| `pyproject.toml` ou `requirements.txt` | `python` | `pytest` |
| `*.sln` ou `*.csproj` | `dotnet` | `dotnet test` |
| Aucun | erreur explicite | déclarer `stack` et `commands` dans `.sdlc.yml` |

**Adapter sans modifier le pipeline** : toutes les commandes et versions se surchargent dans `.sdlc.yml` (voir [configuration](configuration.md)). Pour une stack non prévue, `stack: custom` avec ses propres commandes.

### Le workflow d'appel dans le repo d'équipe

[`templates/repo/.github/workflows/sdlc.yml`](../templates/repo/.github/workflows/sdlc.yml) :

```yaml
jobs:
  sdlc:
    uses: <org>/sdlc-blueprint/.github/workflows/sdlc.yml@main
```

### Rendre le contrôle requis

Le nom du contrôle combine le job appelant et le job appelé : **`sdlc / build-test`**. C'est ce nom que le ruleset exige. `scripts/apply-socle.sh` le renseigne ; il reste modifiable avec la variable `CHECK_CONTEXT`.

`strict_required_status_checks_policy: true` impose que la branche soit à jour avec `main` avant le merge : les tests portent sur le code réellement fusionné.

## Comment tester

1. Ouvrir une PR qui casse un test.
2. Le contrôle `sdlc / build-test` passe au rouge, le merge est bloqué.
3. Corriger, pousser : le contrôle repasse au vert.
4. Ouvrir le résumé du job : configuration détectée et résultats des tests.

```bash
gh pr checks <numero>
```

## Preuve

```bash
gh api "repos/<owner>/<repo>/rules/branches/main" \
  --jq '.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'
# attendu : sdlc / build-test
```

Et dans le rapport de conformité : `CI-1`, `CI-2`, `CI-3` et `CI-4` (pipeline commun utilisé).

## Pièges

- **Nom du contrôle différent** de celui exigé : la PR attend indéfiniment un contrôle qui n'arrivera jamais (« Expected — Waiting for status to be reported »). Vérifier le nom exact dans l'onglet *Checks* de la première PR.
- **Repo central privé** : autoriser l'accès au pipeline dans le repo central (*Settings > Actions > General > Access*).
- **Version du pipeline commun** : `@main` convient pour tester. En usage réel, référencer une version (`@v1`) pour qu'une évolution du pipeline ne casse pas les équipes sans prévenir.
- **Projet dans un sous-dossier** : renseigner `working-directory` dans `.sdlc.yml`, sinon la détection échoue.
- **Plusieurs projets dans un même repo** : le pipeline traite un projet par repo pour l'instant. Pour plusieurs composants, un repo par composant ou une stack `custom` qui enchaîne les commandes.
- **Tests longs ou instables** : un contrôle requis lent ou aléatoire pousse les équipes à le contourner. Viser moins de 15 minutes et traiter les tests instables en priorité.
