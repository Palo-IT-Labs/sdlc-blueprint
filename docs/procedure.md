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

**Conséquences.**
- Repos de test **publics** : les fonctions de sécurité (détection de secrets, blocage au push) y sont gratuites.
- La couche organisation (propriété personnalisée, ruleset d'organisation) demande le rôle **Owner**.

**Chez le client.** Le plan est en général Enterprise (mode `evaluate` des rulesets disponible, sécurité sous licence sur les repos privés). Les réglages d'organisation appartiennent à l'équipe qui administre la plateforme : prévoir de les faire avec elle.

---

## Phase 2. Mise en ligne des deux repos (À faire)

### 2.1 Créer et pousser le repo central `sdlc-blueprint`

### 2.2 Créer et pousser le repo de démonstration `sdlc-sample-app`

### 2.3 Vérifier la première exécution du pipeline commun

---

## Phase 3. Application du socle (mode repo par repo) (À faire)

### 3.1 Appliquer les règles : `apply-socle.sh`

### 3.2 Contrôler : `check.sh`

### 3.3 Dérouler les scénarios de test

---

## Phase 4. Raccordement d'un repo par PR d'amorçage (À faire)

---

## Phase 5. Couche organisation (Bloqué (rôle Owner)

---

## Phase 6. Collecte planifiée et rapport consolidé (Bloqué (jeton en lecture)
