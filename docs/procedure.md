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

## Phase 2. Mise en ligne des deux repos (À faire)

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

**En cas d'échec.** `gh run view --repo $ORG/sdlc-sample-app --log-failed` affiche les lignes en erreur.

**Chez le client.** Si le repo central est privé ou interne, autoriser son pipeline pour les autres repos : *Settings > Actions > General > Access > Accessible from repositories in the organization*.

---

## Phase 3. Application du socle (mode repo par repo) (À faire)

### 3.1 Appliquer les règles : `apply-socle.sh`

### 3.2 Contrôler : `check.sh`

### 3.3 Dérouler les scénarios de test

---

## Phase 4. Raccordement d'un repo par PR d'amorçage (À faire)

---

## Phase 5. Couche organisation (Non testable ici : plan Enterprise requis, à valider chez le client)

---

## Phase 6. Collecte planifiée et rapport consolidé (Bloqué : jeton en lecture)
