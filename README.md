# SDLC Blueprint

Kit de configuration GitHub pour amener un repo au niveau **L1** d'un référentiel de maturité DevOps, puis **L2**, puis vers un **SDLC assisté par l'IA**.

Chaque étape est décrite de la même façon : **quoi**, **pourquoi**, **comment** (interface puis ligne de commande), **comment tester**, **preuve attendue**, **pièges**. Les réglages sont appliqués par script et vérifiés par un script de contrôle.

---

## Le principe : trois couches et un contrôle

| Couche | Contenu | Où ça vit |
|---|---|---|
| **1. Réglages d'organisation** | Rulesets, configurations de sécurité | Au niveau de l'organisation GitHub (droits Owner requis). En attendant, le kit les applique **repo par repo** (`rulesets/`, `scripts/apply-socle.sh`). |
| **2. Code partagé** | Workflows réutilisables, modèles | **Ce repo**, appelé par les repos d'équipe (`.github/workflows/`). |
| **3. Fichiers minimaux par repo** | Workflow d'appel, CODEOWNERS, modèle de PR | Dans chaque repo, ajoutés **par une PR relue par l'équipe** (`templates/repo/`). |
| **Contrôle** | État de conformité point par point, avec preuves | `scripts/check-socle.sh` |

Un repo n'a donc presque rien à copier : il hérite des règles d'organisation et appelle le code partagé.

---

## Les étapes

| # | Étape | Statut |
|---|---|---|
| 00 | [Prérequis](docs/00-prerequis.md) | Prêt |
| 01 | [Branche par défaut et stratégie de branches](docs/01-branches.md) | Prêt |
| 02 | [Protection de main](docs/02-protection-main.md) | Prêt |
| 03 | [Relecture obligatoire](docs/03-relecture.md) | Prêt |
| 04 | [CI et tests requis avant merge](docs/04-ci-tests.md) | Prêt |
| 05 | [Secrets hors du code](docs/05-secrets.md) | Prêt |
| 06 | Dépendances (Dependabot, revue des dépendances) | À venir |
| 07 | Analyse de sécurité du code (CodeQL) bloquante | À venir |
| 08 | Traçabilité (ID de story, release notes) | À venir |
| 09 | Documentation (README, déploiement, environnements) | À venir |
| L2 | Niveau 2 (taille des PR, signatures, SBOM, environnements protégés) | À venir |
| IA | SDLC assisté par l'IA (instructions d'agents, relecture des PR d'agents) | À venir |

Les étapes 02 à 05 forment le **socle** : protection de main, relecture obligatoire, tests requis, secrets hors du code.

---

## Démarrage rapide

```bash
# 1. Appliquer le socle sur un repo
./scripts/apply-socle.sh <owner>/<repo>

# 2. Vérifier la conformité
./scripts/check-socle.sh <owner>/<repo>
```

Le détail, les tests et les pièges sont dans les fiches `docs/`.

---

## Structure

```
.github/workflows/reusable-ci-java.yml   Workflow partagé : build et tests (Java, Maven)
rulesets/socle-main.json                 Ruleset du socle pour la branche par défaut
templates/repo/                          Fichiers à ajouter dans un repo d'équipe (couche 3)
scripts/apply-socle.sh                   Application du socle sur un repo
scripts/check-socle.sh                   Contrôle de conformité du socle
docs/                                    Fiches pas à pas
```

## Limites connues

- Le mode `evaluate` des rulesets (tester sans bloquer) n'est disponible qu'avec GitHub Enterprise. Ailleurs, un ruleset est actif ou désactivé.
- La détection de secrets est gratuite sur les repos publics. Sur un repo privé, elle dépend de la licence (GitHub Secret Protection ou Advanced Security).
- Les rulesets d'organisation demandent le rôle Owner. Le kit fonctionne aussi au niveau du repo, avec le rôle Admin sur le repo.
