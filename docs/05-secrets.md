# 05. Secrets hors du code

## Quoi

- **Détection des secrets** (secret scanning) activée sur le repo.
- **Blocage au push** (push protection) : un commit contenant un secret reconnu est refusé avant d'arriver sur GitHub.
- Les secrets de l'application vivent dans un **coffre** (Key Vault, secrets GitHub Actions), jamais dans le code ni dans les fichiers de configuration (y compris Dockerfile, docker-compose, manifestes Kubernetes, fichiers `.env`).

## Points du référentiel couverts

| Niveau | Point |
|---|---|
| L1 | SAST / SCA / Secret scanning active (volet secrets) |
| L1 | No hardcoded secrets |
| L1 | Secrets not in code |
| L2 | Secret scanning on push, block push on hit |
| L2 | All secrets in Key Vault / GitHub Secrets |

## Pourquoi

Un secret poussé est compromis, même s'il est supprimé au commit suivant : il reste dans l'historique et dans les copies du repo. Le bloquer au push coûte quelques secondes. Le rattraper après coup impose une rotation de la clé et une analyse d'impact.

## Comment

**Dans l'interface** : *Settings > Code security > Secret Protection*, activer *Secret scanning* puis *Push protection*.

**En ligne de commande** (fait par `scripts/apply-socle.sh`) :

```bash
gh api -X PATCH "repos/<owner>/<repo>" --input - <<'JSON'
{ "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" } } }
JSON
```

**Dans l'application** : lire les secrets depuis l'environnement ou un coffre. Pour Spring Boot, par exemple `spring.datasource.password=${DB_PASSWORD}`, la valeur étant injectée au déploiement depuis le coffre.

## Comment tester

Utiliser un **secret de test fourni par l'éditeur**, jamais un vrai secret. Par exemple, une clé d'accès AWS d'exemple tirée de la documentation AWS, que GitHub reconnaît.

```bash
git checkout -b test/push-protection
echo "aws_secret_access_key=<valeur d'exemple de la documentation AWS>" > leak.txt
git add leak.txt && git commit -m "test push protection"
git push origin test/push-protection
# attendu : push refusé, "GH013: Repository rule violations found... Push cannot contain secrets"
git reset --hard HEAD~1 && git checkout main && git branch -D test/push-protection
```

Si le push passe, la protection n'est pas active : vérifier l'état avec la commande de preuve.

## Preuve

```bash
gh api "repos/<owner>/<repo>" --jq '.security_and_analysis'
# attendu : secret_scanning et secret_scanning_push_protection à "enabled"

gh api "repos/<owner>/<repo>/secret-scanning/alerts?state=open" --jq 'length'
# attendu : 0
```

## Pièges

- **Repo privé sans licence** : l'activation est refusée par l'API. Le script le signale ; c'est un sujet de licence, à remonter.
- **Secrets non reconnus** : la détection couvre les formats connus (clés de fournisseurs cloud, jetons). Un mot de passe « maison » dans un fichier de configuration passe inaperçu. La relecture (fiche 03) et la checklist de PR restent nécessaires.
- **Contournement du blocage** : un développeur peut déclarer un faux positif au moment du push. Ces contournements sont tracés ; les suivre.
- **Historique existant** : activer la détection sur un vieux repo fait remonter les secrets passés. Chaque alerte ouverte doit être traitée (rotation de la clé), pas seulement fermée.
