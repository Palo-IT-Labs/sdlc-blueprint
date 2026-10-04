# 00. Prérequis

## Quoi

Disposer d'un environnement de test qui reproduit la situation d'une équipe : une organisation GitHub, un repo central (ce kit) et un repo consommateur (une application).

## Ce qu'il faut

| Élément | Pourquoi | Vérification |
|---|---|---|
| Une organisation GitHub | Les règles se posent au niveau de l'organisation chez la plupart des clients | Tu en es membre |
| Rôle **Admin** sur les repos de test | Créer des rulesets et activer les réglages de sécurité d'un repo | Onglet *Settings* visible sur le repo |
| Rôle **Owner** de l'organisation (plus tard) | Rulesets et configurations de sécurité d'organisation | *Organization settings* accessible |
| CLI `gh` connectée **au bon compte** | Les scripts passent par l'API GitHub | `gh auth status` |
| `jq` | Lecture des réponses de l'API dans les scripts | `jq --version` |
| Un second compte relecteur | Tester la relecture obligatoire : on ne peut pas approuver sa propre PR | Un collègue ajouté au repo |

## Comment

### Connecter `gh` au compte de l'organisation

La clé SSH sert à `git push`. Les scripts, eux, utilisent l'API et demandent une connexion `gh`.

```bash
# Ajouter le compte (ouvre le navigateur)
gh auth login --hostname github.com --git-protocol ssh --scopes "repo,workflow,read:org"

# Si plusieurs comptes sont connectés, activer le bon
gh auth switch --user <compte-organisation>
gh auth status
```

Le scope `admin:org` ne sera nécessaire que pour les rulesets d'organisation.

### Créer les deux repos

```bash
ORG=<organisation>

# Repo central (ce kit)
gh repo create "$ORG/sdlc-blueprint" --public --description "Kit de configuration SDLC L1/L2"

# Repo consommateur (application de démonstration)
gh repo create "$ORG/sdlc-sample-app" --public --description "Application de démonstration du SDLC Blueprint"
```

**Public ou privé ?** En public, la détection de secrets est gratuite et le workflow partagé est accessible sans réglage. Ne mettre dans ces repos **aucune information client**. En privé, voir les pièges ci-dessous.

## Comment tester

```bash
gh auth status                        # le compte actif est celui de l'organisation
gh repo view "$ORG/sdlc-sample-app"   # le repo existe
gh api "repos/$ORG/sdlc-sample-app" --jq .permissions.admin   # doit afficher true
```

## Pièges

- **Mauvais compte actif dans `gh`** : les commandes échouent en 404 ou agissent sur le mauvais compte. Toujours vérifier `gh auth status`.
- **Repos privés** : le workflow partagé n'est appelable depuis un autre repo privé que si le repo central l'autorise (*Settings > Actions > General > Access*). La détection de secrets peut demander une licence.
- **Organisation partagée avec des collègues** : ne jamais créer de règle d'organisation sans la restreindre aux repos de test.
