# Référence : le fichier `.sdlc.yml`

Fichier optionnel, à la racine du repo d'équipe. Il permet d'adapter le pipeline commun et de déclarer ce qui ne s'automatise pas, **sans modifier le blueprint**. Sans ce fichier, la stack est détectée et les commandes par défaut s'appliquent.

Modèle complet : [`templates/repo/.sdlc.yml`](../templates/repo/.sdlc.yml).

## Clés

| Clé | Défaut | Rôle |
|---|---|---|
| `stack` | `auto` | `auto`, `java-maven`, `java-gradle`, `node`, `python`, `dotnet` ou `custom` |
| `working-directory` | `.` | Dossier du projet si ce n'est pas la racine |
| `versions.java` | `21` | Version de Java |
| `versions.node` | `22` | Version de Node.js |
| `versions.python` | `3.12` | Version de Python |
| `versions.dotnet` | `8.0.x` | Version du SDK .NET |
| `commands.install` | selon la stack | Installation des dépendances |
| `commands.build` | selon la stack | Build |
| `commands.test` | selon la stack | Tests (obligatoire pour `custom`) |
| `team` | vide | Équipe responsable, reprise dans le rapport |
| `servicenow-app` | vide | Identifiant de l'application dans ServiceNow (point `TRA-1`) |
| `declarations.deployment-doc` | vide | Lien vers la procédure de déploiement (point `DOC-2`) |
| `declarations.architecture` | vide | Lien vers l'architecture (point `DOC-3`) |
| `declarations.on-call` | vide | Contact d'astreinte ou groupe d'affectation (point `OPS-1`) |
| `declarations.runbook` | vide | Lien vers le runbook (point `OPS-2`, L2) |

## Exemples

**API Java dans un sous-dossier :**

```yaml
working-directory: mission-control
servicenow-app: APM00XXXXX
declarations:
  deployment-doc: docs/deploiement.md
  on-call: groupe-support-citizen-day
```

**Front Node avec pnpm, tests sans lancer le build :**

```yaml
stack: node
versions:
  node: "20"
commands:
  build: ""
  test: pnpm vitest run
```

**Stack non prévue (ici Terraform) :**

```yaml
stack: custom
commands:
  install: terraform -chdir=infra init -backend=false
  test: terraform -chdir=infra validate && terraform fmt -check -recursive infra
```

Pour la stack `custom`, l'outillage (Terraform, etc.) doit être disponible sur le runner ou installé par `commands.install`.
