# Procédure de mise en place, pas à pas

Journal des étapes réellement exécutées pour mettre en place le SDLC Blueprint, rédigé pendant le test dans une organisation de démonstration. Il sert de procédure à rejouer dans l'organisation d'un client.

Pour chaque étape : **action**, **commande**, **résultat attendu**, et **chez le client** (ce qui change dans un contexte d'entreprise).

Légende du statut : **Fait** (éprouvé), **À faire**, **Bloqué** (en attente d'un droit ou d'une décision).

---

## Phase 1. Poste de travail

### 1.1 Connecter la CLI GitHub au compte de l'organisation (Fait)

**Action.** `gh` peut garder plusieurs comptes, mais un seul est actif. Ajouter le compte de l'organisation et l'activer.

```bash
gh auth login --hostname github.com --git-protocol ssh --scopes "repo,workflow,read:org"
gh auth switch --user <compte-organisation>   # si plusieurs comptes
```

Pendant la connexion : se connecter dans le navigateur avec le compte de l'organisation ; refuser l'envoi d'une clé SSH si elle est déjà enregistrée sur ce compte.

**Résultat attendu.**

```bash
gh auth status            # le compte de l'organisation est "Active account: true"
gh api user --jq .login   # affiche le compte de l'organisation
```

**Chez le client.**
- Si l'organisation impose le **SSO** (connexion d'entreprise), le jeton de `gh` doit être autorisé pour cette organisation : une invite apparaît à la première commande, ou *Settings > Applications > Authorized OAuth Apps* sur GitHub.
- Avec des **comptes gérés par l'entreprise** (Enterprise Managed Users), le compte est fourni par le client : utiliser celui-là, pas un compte personnel.

### 1.2 Vérifier son rôle et les possibilités de l'organisation (Fait)

**Commande.**

```bash
ORG=<organisation>
gh api "orgs/$ORG/memberships/$(gh api user --jq .login)" --jq '{role, state}'
gh api "orgs/$ORG" --jq '{plan: .plan.name, members_can_create_public_repositories, members_can_create_private_repositories}'
```

**Résultat obtenu sur l'organisation de démonstration.** Rôle `member` ; plan `free` ; création de repos publics et privés autorisée aux membres.

**Ce que le plan permet** (vérifié dans la documentation GitHub et par l'API) :

| Fonction | Free | Pro / Team | Enterprise |
|---|---|---|---|
| Rulesets sur repo public | Oui | Oui | Oui |
| Rulesets sur repo privé | **Non** | Oui | Oui |
| Rulesets d'organisation (plusieurs repos) | Non | Non | **Oui** |
| Détection de secrets sur repo public | Oui | Oui | Oui |
| Détection de secrets sur repo privé | Non | Sous licence | Sous licence |
| Mode `evaluate` des rulesets | Non | Non | Oui |

Sur un repo privé d'une organisation Free, l'API répond : « *Upgrade to GitHub Pro or make this repository public to enable this feature* ».

**Conséquences pour le test.**
- Les repos de test doivent être **publics** pour éprouver le socle (protection, relecture, contrôle requis, détection de secrets).
- La **couche organisation n'est pas testable** sur un plan Free, même avec le rôle Owner : elle sera validée directement dans l'organisation du client, si elle est sur le plan Enterprise.
- Le périmètre du collecteur se définit par le **topic** `sdlc`, modifiable par l'admin d'un repo, plutôt que par la propriété personnalisée.

**Chez le client.** Vérifier le plan de l'organisation dès le départ. En Enterprise : rulesets d'organisation, mode `evaluate` et sécurité sur repos privés (selon licences) sont disponibles. Les réglages d'organisation appartiennent à l'équipe qui administre la plateforme : prévoir de les faire avec elle.

### 1.3 État initial des repos de test (Fait)

**Contexte.** Les deux repos ont été créés par un administrateur de l'organisation, en privé, avec le rôle Admin pour l'accompagnant. Une propriété personnalisée `sdlc-profile` a été créée au niveau de l'organisation.

**Commande.**

```bash
for r in sdlc-blueprint sdlc-sample-app; do
  gh api "repos/$ORG/$r" --jq '{visibility, size, admin: .permissions.admin}'
  gh api "repos/$ORG/$r/properties/values"
  gh api "repos/$ORG/$r/rulesets"
done
gh api "orgs/$ORG/properties/schema"
```

**Résultat obtenu.**
- Repos **privés**, **vides**, rôle Admin confirmé.
- Rulesets refusés (plan Free et repo privé).
- Propriété `sdlc-profile` définie au niveau de l'organisation (type texte, modifiable par les administrateurs de l'organisation uniquement), mais **aucune valeur attribuée** aux deux repos.

**Décision prise.** Les deux repos sont passés en **public** (leur contenu ne contient aucune information client). Vérification :

```bash
gh api "repos/$ORG/sdlc-sample-app" --jq .visibility        # public
gh api "repos/$ORG/sdlc-sample-app/rulesets" --jq length     # 0, sans erreur : les rulesets sont disponibles
```

**Chez le client.** Qui peut attribuer la propriété (`values_editable_by`) est une décision de gouvernance : les administrateurs seuls, ou aussi les équipes sur leurs propres repos.

---

## Phase 2. Mise en ligne des deux repos (Fait)

Ordre important : le repo central d'abord, car le pipeline de l'application l'appelle.

### 2.1 Pousser le repo central `sdlc-blueprint`

```bash
cd ~/Documents/workspace/sdlc-blueprint
git remote add origin git@github.com:$ORG/sdlc-blueprint.git
git push -u origin main
```

**Résultat attendu.** `git push` affiche `main -> main` ; le code est visible sur GitHub.

### 2.2 Mettre en pause la collecte planifiée

La collecte planifiée (`sdlc-collector.yml`) tournerait chaque jour ouvré et échouerait faute de jeton (phase 6). La désactiver jusque-là :

```bash
gh workflow disable "SDLC collector" --repo $ORG/sdlc-blueprint
gh workflow list --repo $ORG/sdlc-blueprint --all     # SDLC collector : disabled_manually
```

### 2.3 Pousser le repo de démonstration `sdlc-sample-app`

```bash
cd ~/Documents/workspace/sdlc-sample-app
git remote add origin git@github.com:$ORG/sdlc-sample-app.git
git push -u origin main
```

**Résultat attendu.** Le push sur `main` déclenche le workflow `SDLC`.

### 2.4 Vérifier la première exécution du pipeline commun

```bash
gh run list --repo $ORG/sdlc-sample-app --limit 1              # statut de l'exécution
gh run watch --repo $ORG/sdlc-sample-app                       # suivre en direct (choisir l'exécution)
gh run view --repo $ORG/sdlc-sample-app --json jobs --jq '.jobs[] | {name, conclusion}'
```

**Résultat attendu.**
- Deux jobs au vert : `sdlc / detect` et `sdlc / build-test`. **Le nom `sdlc / build-test` est celui que le ruleset exigera** (phase 3) : le noter s'il diffère.
- Dans le résumé de l'exécution (onglet *Summary* sur GitHub) : stack `java-maven` détectée, commande `./mvnw -B -ntp verify`, et 3 tests passés (2 dans `HelloControllerTests`, 1 dans `SdlcSampleAppApplicationTests`).

**Résultat obtenu (4 octobre 2026).**
- `sdlc / detect` et `sdlc / build-test` : `success`. Durée totale : 41 secondes.
- Stack `java-maven` détectée ; Spring Boot 4.1.1 compilé en Java 21 ; `Tests run: 3, Failures: 0`.
- Contrôle à exiger dans le ruleset : **`sdlc / build-test`** (confirmé).
- Deux annotations : `actions/upload-artifact@v4` repose sur Node.js 20, déprécié ; le label `ubuntu-latest` passera à Ubuntu 26 à partir du 19 octobre 2026 (information).

**En cas d'échec.** `gh run view --repo $ORG/sdlc-sample-app --log-failed` affiche les lignes en erreur.

### 2.5 Mettre à jour les actions du pipeline commun (À faire)

Suite à l'annotation de l'étape 2.4, toutes les actions passent à leur dernière version majeure (Node.js 24) : `checkout@v7`, `setup-java@v6`, `setup-node@v7`, `setup-python@v7`, `setup-dotnet@v6`, `upload-artifact@v7`. Le commit est prêt en local.

```bash
cd ~/Documents/workspace/sdlc-blueprint
git push
```

**Validation.** Elle se fait au prochain push sur l'application, à l'étape 3.1 : le pipeline doit rester au vert, sans l'avertissement Node.js 20.

```bash
gh run list --repo $ORG/sdlc-sample-app --limit 1
```

**Bonne pratique à retenir.** Vérifier régulièrement les versions des actions : `gh api repos/actions/<action>/releases/latest --jq .tag_name`. Au niveau L2, épingler les actions par empreinte (SHA) plutôt que par version.

**Chez le client.** Si le repo central est privé ou interne, autoriser son pipeline pour les autres repos : *Settings > Actions > General > Access > Accessible from repositories in the organization*.

---

## Phase 3. Application du socle (mode repo par repo) (À faire)

### 3.1 Préparer la relecture (avant d'activer les règles)

Le ruleset exigera l'approbation d'un **propriétaire de code autre que l'auteur**. Si CODEOWNERS ne liste que soi-même, aucune de ses PR ne pourra être fusionnée. Ajouter au moins un relecteur, ayant l'accès en écriture au repo (ici Sami, `shenchiri-palo`, déjà admin du repo).

Cette modification se fait **avant** d'appliquer le ruleset : après, elle devrait elle-même passer par une PR relue.

```bash
cd ~/Documents/workspace/sdlc-sample-app
# Remplacer la ligne "*    @mdabo-palo-it" par :
#   *    @mdabo-palo-it @shenchiri-palo
git add .github/CODEOWNERS
git commit -m "chore: second relecteur dans CODEOWNERS"
git push
gh run list --repo $ORG/sdlc-sample-app --limit 1    # valide aussi l'étape 2.5 : pipeline au vert
```

**Chez le client.** Désigner de préférence une **équipe GitHub** (`@org/equipe`) d'au moins deux personnes plutôt que des comptes individuels. Pour une équipe d'un seul développeur, ajouter un relecteur d'une autre équipe ou le tech lead (voir fiche 03).

### 3.2 Appliquer les règles : `apply-socle.sh`

D'abord à blanc, pour voir ce qui sera fait :

```bash
cd ~/Documents/workspace/sdlc-blueprint
DRY_RUN=1 ./scripts/apply-socle.sh $ORG/sdlc-sample-app
```

Puis pour de bon :

```bash
./scripts/apply-socle.sh $ORG/sdlc-sample-app
```

**Résultat attendu.**

```
== Vérifications préalables
  OK   Droits Admin sur Palo-IT-Labs/sdlc-sample-app
== 01. Branche par défaut et suppression des branches fusionnées
  OK   Branche par défaut : main ; suppression automatique des branches fusionnées
== 02 à 04. Ruleset 'socle-main' (protection, relecture, contrôle requis 'sdlc / build-test')
  OK   Ruleset créé
== 05. Détection des secrets et blocage au push
  OK   Secret scanning et push protection activés
```

Vérification dans l'interface : *Settings > Rules > Rulesets > socle-main*, et *Settings > Advanced Security*.

### 3.3 Contrôler : `check.sh`

```bash
./scripts/check.sh $ORG/sdlc-sample-app
```

**Résultat attendu.**
- **OK** : `SCM-1` à `SCM-5`, `CR-1` à `CR-6`, `CI-1` à `CI-4`, `SEC-1` à `SEC-3`, `DOC-1` à `DOC-3`, `OPS-1`, `TRA-1`.
- **KO attendus à ce stade** : `SEC-4` (Dependabot) et `SEC-6` (analyse de code), qui relèvent des fiches 06 et 07, pas encore appliquées.
- **INFO** : `OPS-2` (runbook non déclaré, point L2).
- `SEC-5` peut apparaître en `?` tant que Dependabot n'est pas activé.

### 3.4 Dérouler les scénarios de test

Chaque scénario vérifie qu'une règle **bloque réellement**. Partir de `main` à jour : `git checkout main && git pull`.

**S1. Push direct sur `main` refusé**

```bash
echo "test" >> push-direct.txt && git add push-direct.txt && git commit -m "test: push direct"
git push origin main
# attendu : refusé, "Changes must be made through a pull request"
git reset --hard origin/main
```

**S2. Force-push refusé**

```bash
git commit --allow-empty -m "test: force push" && git push --force origin main
# attendu : refusé, "Cannot force-push to this branch"
git reset --hard origin/main
```

**S3. PR sans approbation bloquée**

```bash
git checkout -b test/relecture
echo "Scénario de relecture" >> README.md && git commit -am "docs: scénario de relecture"
git push -u origin test/relecture
gh pr create --fill --base main
gh pr view --json reviewDecision,mergeStateStatus
# attendu : "REVIEW_REQUIRED" et "BLOCKED"
gh pr merge --squash
# attendu : refusé
```

**S4. Approbation annulée par un nouveau commit** (avec le relecteur)
1. Le relecteur approuve la PR de S3 (*Files changed > Review changes > Approve*).
2. `gh pr view --json reviewDecision` : `APPROVED`.
3. Pousser un nouveau commit sur la branche :
   ```bash
   echo "Ajout" >> README.md && git commit -am "docs: ajout" && git push
   gh pr view --json reviewDecision    # attendu : de nouveau "REVIEW_REQUIRED"
   ```
4. Le relecteur approuve à nouveau ; une fois `sdlc / build-test` au vert, `gh pr merge --squash` réussit.

**S5. Test cassé : merge bloqué**

```bash
git checkout main && git pull && git checkout -b test/test-casse
# Dans src/test/java/com/paloit/sdlc/sample/HelloControllerTests.java,
# remplacer "Bonjour Lamyaa" par "Bonsoir Lamyaa"
git commit -am "test: test volontairement cassé" && git push -u origin test/test-casse
gh pr create --fill --base main
gh pr checks --watch
# attendu : "sdlc / build-test" en échec ; merge impossible même avec une approbation
gh pr close --delete-branch
```

**S6. Secret bloqué au push**

Utiliser un secret réel mais **inoffensif et jetable** : un jeton GitHub à granularité fine **sans aucune permission**, expirant le lendemain (*Settings > Developer settings > Personal access tokens > Fine-grained tokens*, aucun repo, aucune permission).

```bash
git checkout main && git pull && git checkout -b test/secret
echo "token=<jeton jetable>" > secret.txt && git add secret.txt && git commit -m "test: secret"
git push -u origin test/secret
# attendu : refusé, "GH013: Repository rule violations found... Push cannot contain secrets"
git checkout main && git branch -D test/secret
```

Puis **supprimer le jeton** dans les réglages GitHub.

**S7. Contrôle final**

```bash
cd ~/Documents/workspace/sdlc-blueprint && ./scripts/check.sh $ORG/sdlc-sample-app
```

Résultat attendu : celui de l'étape 3.3.

**Chez le client.** Prévenir l'équipe **avant** l'étape 3.2 : sans mode `evaluate`, les règles bloquent dès leur activation. Recenser au préalable les comptes de service ou pipelines qui poussent directement sur `main`.

---

## Phase 4. Raccordement d'un repo par PR d'amorçage (À faire)

---

## Phase 5. Couche organisation (Non testable ici : plan Enterprise requis, à valider chez le client)

---

## Phase 6. Collecte planifiée et rapport consolidé (Bloqué : jeton en lecture)
