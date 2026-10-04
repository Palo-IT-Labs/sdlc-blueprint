# SDLC Blueprint : le produit

## En une phrase

Un socle **prêt à l'emploi** qui rend un repo GitHub conforme aux exigences L1 puis L2 d'un référentiel de maturité DevOps, **sans que l'équipe ait à ouvrir le capot**, **quelle que soit sa stack**, et qui **remonte automatiquement l'état de conformité** aux personnes qui supervisent.

---

## Le problème qu'il résout

| Constat fréquent | Réponse du produit |
|---|---|
| Chaque équipe configure ses repos à sa façon ; les règles divergent | Règles posées une fois au niveau de l'organisation, héritées par les repos |
| Les pipelines sont recopiés d'un projet à l'autre et vieillissent mal | Un pipeline commun, versionné, appelé par chaque repo |
| Les outils de sécurité arrivent sur les repos sans explication | Une PR d'amorçage relue par l'équipe, et une fiche par règle qui explique le pourquoi |
| L'état de conformité est déclaratif, refait à chaque audit | Un collecteur qui mesure chaque point dans les outils, avec preuves, chaque jour |
| Une stack « hors norme » oblige à des exceptions | Détection automatique de la stack, et un fichier de configuration pour le reste |

---

## Les quatre principes

1. **Sans ouvrir le capot.** Une équipe ajoute un fichier et fusionne une PR. Elle ne modifie jamais le socle.
2. **Générique.** Le pipeline détecte Java (Maven, Gradle), Node.js, Python et .NET. Tout le reste s'adapte par `.sdlc.yml`.
3. **Mesuré, pas déclaré.** Chaque point est vérifié dans GitHub. Ce qui ne peut pas l'être (astreinte, runbook) est déclaré sous forme de lien, et sa présence est vérifiée.
4. **Avec les équipes.** Rien n'est posé sur un repo sans une PR que l'équipe relit.

---

## Architecture

```
  RÈGLES D'ORGANISATION (posées une fois par les administrateurs)
  ┌───────────────────────────────────────────────────────────────────┐
  │ Ruleset "sdlc-standard" + configuration de sécurité, appliqués    │
  │ à tout repo portant la propriété  sdlc-profile = standard         │
  │ (org/ruleset-sdlc-standard.json, scripts/apply-org.sh)            │
  └───────────────────────────────┬───────────────────────────────────┘
                                  │ s'appliquent automatiquement
                                  ▼
  REPO D'ÉQUIPE
  ┌───────────────────────────────────────────────────────────────────┐
  │ .github/workflows/sdlc.yml   appel du pipeline commun (5 lignes)  │
  │ .sdlc.yml                    optionnel : stack, commandes, liens  │
  │ CODEOWNERS, modèle de PR     ajoutés par la PR d'amorçage         │
  └──────────────┬────────────────────────────────────────▲───────────┘
                 │ appelle (versionné)                     │ lit l'état
                 ▼                                         │
  REPO CENTRAL sdlc-blueprint                              │
  ┌──────────────────────────────────┐   ┌─────────────────┴─────────┐
  │ Pipeline commun                  │   │ Collecteur (planifié)     │
  │ .github/workflows/sdlc.yml       │   │ .github/workflows/        │
  │ détecte la stack, installe,      │   │   sdlc-collector.yml      │
  │ build, tests, résumé             │   │ collector/sdlc_check.py   │
  └──────────────────────────────────┘   └─────────────┬─────────────┘
                                                       ▼
                                   RAPPORT CONSOLIDÉ (report.json, report.md)
                                   par repo, point par point, L1 et L2
                                   → résumé du job, puis tableau de bord
```

---

## Les composants

| Composant | Fichiers | Rôle | Utilisé par |
|---|---|---|---|
| **Pipeline commun** | `.github/workflows/sdlc.yml` | Détecte la stack, installe l'outillage, build, tests, résumé des tests | Chaque repo, via son workflow d'appel |
| **Ruleset d'organisation** | `org/ruleset-sdlc-standard.json`, `scripts/apply-org.sh` | Protection de main, relecture, contrôle requis, pour tous les repos du profil | Administrateurs de l'organisation |
| **Ruleset de repo** (mode dégradé) | `rulesets/socle-main.json`, `scripts/apply-socle.sh` | Mêmes règles, repo par repo, quand la couche organisation n'est pas disponible | Administrateur du repo |
| **PR d'amorçage** | `scripts/bootstrap-repo.sh`, `templates/repo/` | Ajoute les fichiers manquants dans un repo d'équipe, sans toucher à l'existant | Accompagnant ou équipe |
| **Collecteur** | `collector/sdlc_check.py`, `scripts/check.sh` | Mesure chaque point, produit le rapport | Accompagnant, superviseurs |
| **Collecte planifiée** | `.github/workflows/sdlc-collector.yml` | Lance le collecteur chaque jour ouvré sur tout le périmètre | Automatique |
| **Fiches pas à pas** | `docs/00` à `docs/05` | Quoi, pourquoi, comment, test, preuve, pièges, pour chaque règle | Tout le monde |

---

## Ce que vit une équipe au quotidien

```
 développeur            GitHub                                   superviseur
     │  ouvre une PR       │                                          │
     ├────────────────────▶│ pipeline commun : build + tests           │
     │                     │ ruleset : 1 approbation, contrôle requis  │
     │◀──── relecture ─────┤ (impossible de fusionner sans les deux)   │
     │  fusionne           │                                          │
     ├────────────────────▶│ main reste protégée                       │
     │                     │                                          │
     │                     │  chaque nuit : collecteur ───────────────▶│ rapport
     │                     │                                          │ par repo
```

---

## Prise en main

### Une fois pour toutes, côté administrateurs de l'organisation

| # | Action | Comment |
|---|---|---|
| 1 | Rendre le pipeline commun accessible aux repos de l'organisation | Repo central public, ou *Settings > Actions > General > Access* s'il est privé |
| 2 | Créer la propriété `sdlc-profile` et le ruleset d'organisation | `./scripts/apply-org.sh <organisation>` (rôle Owner) |
| 3 | Activer la configuration de sécurité de l'organisation (détection de secrets, blocage au push, analyse de code, Dependabot) | *Organization settings > Code security > Configurations* |
| 4 | Donner au collecteur un jeton en lecture | Une GitHub App en lecture, ou un jeton à granularité fine, enregistré dans le secret `SDLC_COLLECTOR_TOKEN` du repo central |

### Pour une équipe projet (environ 15 minutes)

| # | Action | Ce qui se passe |
|---|---|---|
| 1 | Donner au repo la propriété `sdlc-profile = standard` et le topic `sdlc` | Les règles d'organisation s'appliquent ; le repo entre dans le périmètre du collecteur |
| 2 | Fusionner la PR d'amorçage (`./scripts/bootstrap-repo.sh <owner>/<repo>`) | Workflow d'appel, `.sdlc.yml`, CODEOWNERS et modèle de PR arrivent, relus par l'équipe |
| 3 | Compléter `.sdlc.yml` si besoin | Stack, commandes, identifiant ServiceNow, liens de documentation et d'astreinte |
| 4 | Ouvrir une première PR | L'équipe voit la configuration détectée, le build, les tests et les règles en action |
| 5 | Le lendemain | Le repo apparaît dans le rapport consolidé, point par point |

### Mode dégradé, sans droits sur l'organisation

Les règles sont appliquées repo par repo par un administrateur du repo :

```bash
./scripts/apply-socle.sh <owner>/<repo>    # ruleset de repo et détection de secrets
./scripts/check.sh <owner>/<repo>          # contrôle immédiat
```

---

## Adapter à sa stack

Le pipeline détecte la stack à partir des fichiers du projet (`pom.xml`, `build.gradle`, `package.json`, `pyproject.toml`, `requirements.txt`, `*.csproj`). Tout se surcharge dans `.sdlc.yml` : dossier, versions, commandes, ou stack `custom` pour une technologie non prévue. Référence : [configuration](configuration.md).

---

## La remontée aux superviseurs

**Périmètre.** Le collecteur parcourt les repos qui portent le topic `sdlc` (ou la propriété `sdlc-profile = standard`).

**Mesure.** Pour chaque repo, chaque point est vérifié dans GitHub, avec son statut :

| Statut | Sens |
|---|---|
| `OK` | Conforme, preuve trouvée |
| `KO` | Non conforme (point L1) |
| `INFO` | Point L2 pas encore atteint, ou information |
| `?` | Non lisible avec les droits du jeton |

**Points mesurés aujourd'hui :**

| Catégorie | Points |
|---|---|
| Source Code Management | `SCM-1` branche par défaut main, `SCM-2` main protégée par PR, `SCM-3` force-push interdit, `SCM-4` suppression interdite, `SCM-5` branches fusionnées supprimées (L2) |
| Code Review | `CR-1` au moins 1 approbation, `CR-2` pas d'auto-approbation, `CR-3` CODEOWNERS, `CR-4` modèle de PR, `CR-5` relecture des propriétaires exigée (L2), `CR-6` approbation annulée après nouveau push (L2) |
| CI/CD | `CI-1` workflow présent, `CI-2` contrôle requis, `CI-3` dernier pipeline réussi, `CI-4` pipeline commun utilisé |
| Security & Quality | `SEC-1` détection de secrets, `SEC-2` blocage au push (L2), `SEC-3` alertes de secrets ouvertes, `SEC-4` Dependabot, `SEC-5` vulnérabilités critiques, `SEC-6` analyse de code |
| Documentation et exploitation | `DOC-1` README, `DOC-2` déploiement, `DOC-3` architecture, `OPS-1` astreinte, `OPS-2` runbook (L2) |
| Traçabilité | `TRA-1` rattachement à une application ServiceNow |

**Restitution.** `report.json` (exploitable par un tableau de bord) et `report.md` (lisible). La collecte planifiée publie le rapport dans le résumé du job et en artefact. Étape suivante : alimenter un tableau de bord existant à partir de `report.json`.

---

## Automatisé ou déclaré

| Automatisé (mesuré dans GitHub) | Déclaré dans `.sdlc.yml` (présence vérifiée) |
|---|---|
| Protection, relecture, contrôles requis, détection de secrets, Dependabot, analyse de code, workflows, résultats de pipeline, fichiers présents | Procédure de déploiement, architecture, contact d'astreinte, runbook, identifiant ServiceNow |

---

## État d'avancement

| Brique | État |
|---|---|
| Fiches 00 à 05 (socle) | Rédigées |
| Pipeline commun générique | Écrit, à éprouver sur le repo de démonstration |
| Ruleset de repo et `apply-socle.sh` | Écrits, à éprouver |
| Collecteur et `check.sh` | Éprouvés en lecture sur des repos publics |
| Collecte planifiée | Écrite, à éprouver (nécessite le jeton) |
| PR d'amorçage | Écrite, à éprouver |
| Couche organisation (`apply-org.sh`) | Écrite, à éprouver avec le rôle Owner |
| Fiches 06 à 09 (dépendances, analyse de code, traçabilité, documentation) | À venir |
| Niveau L2 complet | À venir |
| SDLC assisté par l'IA (instructions d'agents, relecture des PR d'agents) | À venir |

---

## Limites connues

- **Un projet par repo** : un repo contenant plusieurs composants de stacks différentes demande aujourd'hui une stack `custom`.
- **Mode `evaluate` des rulesets** (tester sans bloquer) : réservé à GitHub Enterprise. Ailleurs, prévenir l'équipe avant d'activer.
- **Fonctions de sécurité sur les repos privés** : selon la licence (Secret Protection, Code Security ou Advanced Security).
- **Le collecteur voit ce que voit son jeton** : sans droits suffisants, les points apparaissent en `?`, jamais en faux `OK`.
