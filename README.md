# SDLC Blueprint

Socle prêt à l'emploi pour rendre un repo GitHub conforme aux exigences **L1**, puis **L2**, d'un référentiel de maturité DevOps, et préparer un **SDLC assisté par l'IA**.

- **Sans ouvrir le capot** : un repo ajoute un workflow de quelques lignes et hérite des règles.
- **Générique** : Java (Maven, Gradle), Node.js, Python, .NET, détectés automatiquement ; le reste s'adapte par `.sdlc.yml`.
- **Mesuré** : un collecteur vérifie chaque point dans GitHub et produit un rapport consolidé pour les superviseurs.

**Pour comprendre le produit : [docs/vision.md](docs/vision.md).**

---

## Démarrage rapide

```bash
# Contrôler un repo (lecture seule)
./scripts/check.sh <owner>/<repo>

# Raccorder un repo : PR d'amorçage relue par l'équipe
./scripts/bootstrap-repo.sh <owner>/<repo>

# Appliquer les règles repo par repo (si la couche organisation n'est pas en place)
./scripts/apply-socle.sh <owner>/<repo>

# Couche organisation (rôle Owner)
./scripts/apply-org.sh <organisation>
```

Dans un repo d'équipe, le seul fichier indispensable :

```yaml
# .github/workflows/sdlc.yml
name: SDLC
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  sdlc:
    uses: <org>/sdlc-blueprint/.github/workflows/sdlc.yml@main
```

---

## Les fiches pas à pas

| # | Fiche | Statut |
|---|---|---|
| 00 | [Prérequis](docs/00-prerequis.md) | Prête |
| 01 | [Branche par défaut et stratégie de branches](docs/01-branches.md) | Prête |
| 02 | [Protection de main](docs/02-protection-main.md) | Prête |
| 03 | [Relecture obligatoire](docs/03-relecture.md) | Prête |
| 04 | [CI et tests requis avant merge](docs/04-ci-tests.md) | Prête |
| 05 | [Secrets hors du code](docs/05-secrets.md) | Prête |
| 06 | Dépendances (Dependabot, revue des dépendances) | À venir |
| 07 | Analyse de sécurité du code (CodeQL) bloquante | À venir |
| 08 | Traçabilité (ID de story, release notes) | À venir |
| 09 | Documentation (README, déploiement, environnements) | À venir |
| L2 | Niveau 2 | À venir |
| IA | SDLC assisté par l'IA | À venir |

Référence de configuration : [docs/configuration.md](docs/configuration.md). Procédure de mise en place pas à pas : [docs/procedure.md](docs/procedure.md).

---

## Structure

```
.github/workflows/sdlc.yml             Pipeline commun générique
.github/workflows/sdlc-collector.yml   Collecte planifiée de la conformité
collector/sdlc_check.py                Collecteur (lecture seule, rapport JSON et Markdown)
org/ruleset-sdlc-standard.json         Ruleset d'organisation (repos sdlc-profile=standard)
rulesets/socle-main.json               Ruleset de repo (mode dégradé)
templates/repo/                        Fichiers ajoutés par la PR d'amorçage
scripts/                               check, bootstrap-repo, apply-socle, apply-org
docs/                                  Vision, fiches pas à pas, configuration
```
