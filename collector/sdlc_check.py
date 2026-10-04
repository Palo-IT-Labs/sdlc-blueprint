#!/usr/bin/env python3
"""Collecteur de conformité SDLC.

Contrôle un ou plusieurs repos GitHub point par point (niveaux L1 et L2) et produit
un rapport lisible (terminal), JSON et Markdown. Lecture seule : aucun réglage n'est modifié.

Exemples :
  python3 collector/sdlc_check.py --repo mon-org/mon-repo
  python3 collector/sdlc_check.py --org mon-org --topic sdlc --out reports
  python3 collector/sdlc_check.py --org mon-org --property sdlc-profile=standard --out reports

Authentification : variable GH_TOKEN ou GITHUB_TOKEN, sinon le jeton de la CLI gh.
Sans dépendance externe (bibliothèque standard Python 3.8+).
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

API = os.environ.get("GITHUB_API_URL", "https://api.github.com")
CENTRAL_PIPELINE = "sdlc-blueprint/.github/workflows/sdlc.yml"

OK, KO, INFO, UNKNOWN = "OK", "KO", "INFO", "?"


# ---------------------------------------------------------------- API GitHub

def token():
    for name in ("GH_TOKEN", "GITHUB_TOKEN"):
        if os.environ.get(name):
            return os.environ[name]
    try:
        return subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        sys.exit("Aucun jeton GitHub : définir GH_TOKEN ou se connecter avec 'gh auth login'.")


class GitHub:
    def __init__(self, tok):
        self.headers = {
            "Authorization": f"Bearer {tok}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "sdlc-blueprint-collector",
        }

    def get(self, path, params=None):
        """Renvoie (code HTTP, contenu JSON ou None)."""
        url = f"{API}/{path.lstrip('/')}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers=self.headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read()
                return resp.status, (json.loads(body) if body else None)
        except urllib.error.HTTPError as err:
            return err.code, None
        except urllib.error.URLError as err:
            sys.exit(f"Erreur réseau : {err.reason}")


# ---------------------------------------------------------------- Lecture de .sdlc.yml

def parse_simple_yaml(text):
    """Lit un YAML simple (clés, sous-clés, valeurs scalaires). Suffisant pour .sdlc.yml."""
    try:
        import yaml  # utilisé s'il est disponible
        data = yaml.safe_load(text)
        return data if isinstance(data, dict) else {}
    except ImportError:
        pass
    root = {}
    stack = [(-1, root)]
    for raw in text.splitlines():
        line = raw.split(" #")[0].rstrip() if not raw.lstrip().startswith("#") else ""
        if not line.strip() or ":" not in line:
            continue
        indent = len(line) - len(line.lstrip())
        key, _, raw = line.strip().partition(":")
        raw = raw.strip()
        value = raw.strip('"').strip("'")
        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent = stack[-1][1]
        if raw == "":   # pas de valeur du tout : début d'une sous-section
            parent[key] = {}
            stack.append((indent, parent[key]))
        else:
            parent[key] = value
    return root


def read_file(gh, repo, path):
    code, data = gh.get(f"repos/{repo}/contents/{path}")
    if code != 200 or not isinstance(data, dict) or "content" not in data:
        return None
    return base64.b64decode(data["content"]).decode("utf-8", errors="replace")


# ---------------------------------------------------------------- Contrôles

class Repo:
    """Données d'un repo, chargées une fois, utilisées par tous les contrôles."""

    def __init__(self, gh, full_name):
        self.gh, self.name = gh, full_name
        code, self.meta = gh.get(f"repos/{full_name}")
        if code != 200:
            raise LookupError(f"repo inaccessible (HTTP {code})")
        self.branch = self.meta["default_branch"]
        self.admin = bool(self.meta.get("permissions", {}).get("admin"))
        _, rules = gh.get(f"repos/{full_name}/rules/branches/{self.branch}")
        self.rules = rules if isinstance(rules, list) else []
        code, classic = gh.get(f"repos/{full_name}/branches/{self.branch}/protection")
        self.classic = classic if code == 200 and isinstance(classic, dict) else {}
        cfg = read_file(gh, full_name, ".sdlc.yml")
        self.config = parse_simple_yaml(cfg) if cfg else {}
        self.has_config = cfg is not None

    # Règles : ruleset (repo ou organisation) ou protection classique
    def rule(self, rtype):
        return any(r.get("type") == rtype for r in self.rules)

    def pr_param(self, name):
        for r in self.rules:
            if r.get("type") == "pull_request":
                value = (r.get("parameters") or {}).get(name)
                if value is not None:
                    return value
        reviews = self.classic.get("required_pull_request_reviews") or {}
        mapping = {
            "required_approving_review_count": "required_approving_review_count",
            "require_last_push_approval": "require_last_push_approval",
            "dismiss_stale_reviews_on_push": "dismiss_stale_reviews",
            "require_code_owner_review": "require_code_owner_reviews",
        }
        return reviews.get(mapping.get(name, name))

    def has_pr_rule(self):
        return self.rule("pull_request") or bool(self.classic.get("required_pull_request_reviews"))

    def required_checks(self):
        names = []
        for r in self.rules:
            if r.get("type") == "required_status_checks":
                names += [c.get("context") for c in (r.get("parameters") or {}).get("required_status_checks", [])]
        if not names:
            names = (self.classic.get("required_status_checks") or {}).get("contexts", [])
        return [n for n in names if n]

    def exists(self, *paths):
        for p in paths:
            if self.gh.get(f"repos/{self.name}/contents/{p}")[0] == 200:
                return p
        return None

    def declared(self, key):
        return str((self.config.get("declarations") or {}).get(key) or "").strip()


def check(cid, level, category, label, status, detail=""):
    return {"id": cid, "level": level, "category": category, "label": label, "status": status, "detail": detail}


def run_checks(repo):
    gh, r, out = repo.gh, repo, []
    na_admin = "non lisible (droits Admin requis)"

    # --- Source Code Management
    out.append(check("SCM-1", "L1", "Source Code Management", "Default branch set to main",
                     OK if r.branch == "main" else KO, r.branch))
    out.append(check("SCM-2", "L1", "Source Code Management", "Main branch protected / changes via PR",
                     OK if r.has_pr_rule() else KO, "règle PR active" if r.has_pr_rule() else "aucune règle PR"))
    forced = r.rule("non_fast_forward") or (r.classic.get("allow_force_pushes") or {}).get("enabled") is False
    out.append(check("SCM-3", "L1", "Source Code Management", "Force-push interdit sur main", OK if forced else KO))
    deletion = r.rule("deletion") or (r.classic.get("allow_deletions") or {}).get("enabled") is False
    out.append(check("SCM-4", "L1", "Source Code Management", "Suppression de main interdite", OK if deletion else KO))
    out.append(check("SCM-5", "L2", "Source Code Management", "Branches fusionnées supprimées automatiquement",
                     OK if r.meta.get("delete_branch_on_merge") else INFO))

    # --- Code Review
    approvals = r.pr_param("required_approving_review_count") or 0
    out.append(check("CR-1", "L1", "Code Review", "At least 1 approval required",
                     OK if approvals >= 1 else KO, f"{approvals} approbation(s)"))
    out.append(check("CR-2", "L1", "Code Review", "No self-approval (dernier push approuvé par un tiers)",
                     OK if r.pr_param("require_last_push_approval") else KO))
    owners = r.exists(".github/CODEOWNERS", "CODEOWNERS", "docs/CODEOWNERS")
    out.append(check("CR-3", "L1", "Code Review", "CODEOWNERS présent", OK if owners else KO, owners or "absent"))
    template = r.exists(".github/pull_request_template.md", ".github/PULL_REQUEST_TEMPLATE.md",
                        "pull_request_template.md", "docs/pull_request_template.md", ".github/PULL_REQUEST_TEMPLATE")
    out.append(check("CR-4", "L1", "Code Review", "Review checklist available (modèle de PR)",
                     OK if template else KO, template or "absent"))
    out.append(check("CR-5", "L2", "Code Review", "CODEOWNERS enforced (relecture des propriétaires exigée)",
                     OK if r.pr_param("require_code_owner_review") else INFO))
    out.append(check("CR-6", "L2", "Code Review", "Approbation annulée après un nouveau push",
                     OK if r.pr_param("dismiss_stale_reviews_on_push") else INFO))

    # --- CI/CD
    code, wf = gh.get(f"repos/{r.name}/contents/.github/workflows")
    workflows = [w for w in wf if w.get("name", "").endswith((".yml", ".yaml"))] if code == 200 and isinstance(wf, list) else []
    out.append(check("CI-1", "L1", "CI/CD Pipeline", "Automated build (workflow présent)",
                     OK if workflows else KO, f"{len(workflows)} workflow(s)"))
    checks = r.required_checks()
    out.append(check("CI-2", "L1", "CI/CD Pipeline", "Failed tests BLOCK merge (contrôle requis)",
                     OK if checks else KO, ", ".join(checks) or "aucun contrôle requis"))
    code, runs = gh.get(f"repos/{r.name}/actions/runs", {"branch": r.branch, "per_page": 1})
    last = (runs or {}).get("workflow_runs", [{}])[0].get("conclusion") if code == 200 and (runs or {}).get("workflow_runs") else None
    out.append(check("CI-3", "L1", "CI/CD Pipeline", f"Dernier pipeline réussi sur {r.branch}",
                     OK if last == "success" else (INFO if last is None else KO), last or "aucune exécution"))
    central = any(CENTRAL_PIPELINE in (read_file(gh, r.name, w["path"]) or "") for w in workflows)
    out.append(check("CI-4", "INFO", "CI/CD Pipeline", "Pipeline SDLC central utilisé",
                     OK if central else INFO, "oui" if central else "non"))

    # --- Security & Quality
    sa = r.meta.get("security_and_analysis") or {}
    ss = (sa.get("secret_scanning") or {}).get("status")
    pp = (sa.get("secret_scanning_push_protection") or {}).get("status")
    out.append(check("SEC-1", "L1", "Security & Quality", "Secret scanning active",
                     OK if ss == "enabled" else (UNKNOWN if ss is None else KO), ss or na_admin))
    out.append(check("SEC-2", "L2", "Security & Quality", "Block push on secret (push protection)",
                     OK if pp == "enabled" else (UNKNOWN if pp is None else INFO), pp or na_admin))
    code, alerts = gh.get(f"repos/{r.name}/secret-scanning/alerts", {"state": "open", "per_page": 100})
    out.append(check("SEC-3", "L1", "Security & Quality", "No hardcoded secrets (alertes ouvertes)",
                     (OK if not alerts else KO) if code == 200 else UNKNOWN,
                     f"{len(alerts)} alerte(s)" if code == 200 else f"non lisible (HTTP {code})"))
    code, _ = gh.get(f"repos/{r.name}/vulnerability-alerts")
    out.append(check("SEC-4", "L1", "Security & Quality", "Dependabot enabled (alertes de dépendances)",
                     OK if code == 204 else (KO if code == 404 and r.admin else UNKNOWN),
                     "activé" if code == 204 else ("désactivé" if code == 404 and r.admin else na_admin)))
    code, dep = gh.get(f"repos/{r.name}/dependabot/alerts", {"state": "open", "severity": "critical", "per_page": 100})
    out.append(check("SEC-5", "L1", "Security & Quality", "Zero critical vulnerabilities (dépendances)",
                     (OK if not dep else KO) if code == 200 else UNKNOWN,
                     f"{len(dep)} critique(s)" if code == 200 else f"non lisible (HTTP {code})"))
    code, analyses = gh.get(f"repos/{r.name}/code-scanning/analyses", {"per_page": 1})
    out.append(check("SEC-6", "L1", "Security & Quality", "SAST active (analyse de code)",
                     OK if code == 200 and analyses else (KO if code in (200, 404) else UNKNOWN),
                     "analyses présentes" if code == 200 and analyses else f"aucune analyse (HTTP {code})"))

    # --- Documentation et exploitation (déclaratif dans .sdlc.yml)
    readme = r.exists("README.md", "readme.md", "README.rst")
    out.append(check("DOC-1", "L1", "Documentation", "README.md with setup instructions", OK if readme else KO, readme or "absent"))
    for cid, cat, label, key in (
        ("DOC-2", "Documentation", "Deployment process documented", "deployment-doc"),
        ("DOC-3", "Documentation", "Basic architecture documented", "architecture"),
        ("OPS-1", "Monitoring & Operations", "On-call contact defined", "on-call"),
        ("OPS-2", "Monitoring & Operations", "Runbook disponible", "runbook"),
    ):
        value = r.declared(key)
        out.append(check(cid, "L1" if cid != "OPS-2" else "L2", cat, label,
                         OK if value else (KO if cid != "OPS-2" else INFO),
                         value or f"non déclaré (declarations.{key} dans .sdlc.yml)"))

    # --- Traçabilité
    app = str(r.config.get("servicenow-app") or "").strip()
    out.append(check("TRA-1", "L1", "Traceability & Governance", "Repo rattaché à une application (ServiceNow)",
                     OK if app else KO, app or "non déclaré (servicenow-app dans .sdlc.yml)"))
    return out


def summarize(results):
    l1 = [c for c in results if c["level"] == "L1"]
    return {
        "l1_ok": sum(c["status"] == OK for c in l1),
        "l1_total": len(l1),
        "l1_ko": sum(c["status"] == KO for c in l1),
        "unknown": sum(c["status"] == UNKNOWN for c in results),
        "l2_todo": sum(c["level"] == "L2" and c["status"] != OK for c in results),
    }


# ---------------------------------------------------------------- Sélection des repos

def select_repos(gh, args):
    if args.repo:
        return args.repo
    if not args.org:
        sys.exit("Préciser --repo, ou --org avec --topic ou --property.")
    if args.topic:
        repos, page = [], 1
        while True:
            code, data = gh.get("search/repositories", {"q": f"org:{args.org} topic:{args.topic}", "per_page": 100, "page": page})
            if code != 200:
                sys.exit(f"Recherche impossible (HTTP {code}).")
            repos += [i["full_name"] for i in data.get("items", [])]
            if len(data.get("items", [])) < 100:
                return repos
            page += 1
    if args.property:
        name, _, value = args.property.partition("=")
        repos, page = [], 1
        while True:
            code, data = gh.get(f"orgs/{args.org}/properties/values", {"per_page": 100, "page": page})
            if code != 200:
                sys.exit(f"Lecture des propriétés impossible (HTTP {code}). Droit de lecture de l'organisation requis.")
            for item in data:
                props = {p["property_name"]: p.get("value") for p in item.get("properties", [])}
                if str(props.get(name)) == value:
                    repos.append(item["repository_full_name"])
            if len(data) < 100:
                return repos
            page += 1
    sys.exit("Avec --org, préciser --topic ou --property.")


# ---------------------------------------------------------------- Rendus

def render_table(report):
    lines = []
    for repo in report["repositories"]:
        lines.append(f"\n{repo['repository']}  (branche par défaut : {repo.get('default_branch', '?')})")
        if "error" in repo:
            lines.append(f"  Erreur : {repo['error']}")
            continue
        lines.append(f"  {'ID':<6} {'NIV.':<5} {'STATUT':<6} {'POINT':<56} DÉTAIL")
        for c in repo["checks"]:
            lines.append(f"  {c['id']:<6} {c['level']:<5} {c['status']:<6} {c['label']:<56} {c['detail']}")
        s = repo["summary"]
        lines.append(f"  L1 : {s['l1_ok']}/{s['l1_total']} conformes, {s['l1_ko']} KO, {s['unknown']} non lisible(s) ; L2 restant : {s['l2_todo']}")
    return "\n".join(lines)


def render_markdown(report):
    md = [f"# Rapport de conformité SDLC", "", f"*Généré le {report['generated_at']}.*", "",
          "| Repo | L1 conformes | L1 KO | Non lisibles | L2 restant |", "|---|---|---|---|---|"]
    for repo in report["repositories"]:
        if "error" in repo:
            md.append(f"| {repo['repository']} | erreur | | | |")
            continue
        s = repo["summary"]
        md.append(f"| {repo['repository']} | {s['l1_ok']} / {s['l1_total']} | {s['l1_ko']} | {s['unknown']} | {s['l2_todo']} |")
    for repo in report["repositories"]:
        if "error" in repo:
            continue
        md += ["", f"## {repo['repository']}", "", "| ID | Niveau | Statut | Point | Détail |", "|---|---|---|---|---|"]
        md += [f"| {c['id']} | {c['level']} | {c['status']} | {c['label']} | {c['detail']} |" for c in repo["checks"]]
    return "\n".join(md) + "\n"


# ---------------------------------------------------------------- Point d'entrée

def main():
    ap = argparse.ArgumentParser(description="Collecteur de conformité SDLC (lecture seule).")
    ap.add_argument("--repo", nargs="+", help="un ou plusieurs repos owner/nom")
    ap.add_argument("--org", help="organisation à parcourir")
    ap.add_argument("--topic", help="ne garder que les repos portant ce topic (ex. sdlc)")
    ap.add_argument("--property", help="ne garder que les repos dont la propriété vaut cette valeur (ex. sdlc-profile=standard)")
    ap.add_argument("--out", help="dossier où écrire report.json et report.md")
    ap.add_argument("--quiet", action="store_true", help="ne pas afficher le tableau")
    args = ap.parse_args()

    gh = GitHub(token())
    report = {"generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"), "repositories": []}
    for name in select_repos(gh, args):
        try:
            repo = Repo(gh, name)
            results = run_checks(repo)
            report["repositories"].append({"repository": name, "default_branch": repo.branch,
                                           "config_file": repo.has_config, "checks": results,
                                           "summary": summarize(results)})
        except LookupError as err:
            report["repositories"].append({"repository": name, "error": str(err)})

    if not args.quiet:
        print(render_table(report))
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        with open(os.path.join(args.out, "report.json"), "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        with open(os.path.join(args.out, "report.md"), "w", encoding="utf-8") as f:
            f.write(render_markdown(report))
        print(f"\nRapport écrit dans {args.out}/report.json et {args.out}/report.md")
    ko = sum(r.get("summary", {}).get("l1_ko", 0) for r in report["repositories"])
    sys.exit(1 if ko else 0)


if __name__ == "__main__":
    main()
