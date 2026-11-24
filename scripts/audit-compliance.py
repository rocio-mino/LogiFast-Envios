#!/usr/bin/env python3
"""
Auditoría automatizada de cumplimiento — LogiFast-Envios (EP3 · IE5 / IE6).

Revisa el repositorio contra las políticas documentadas en
docs/EP3/07_Politicas_Cumplimiento.md y termina con código 1 si alguna
política obligatoria no se cumple. En el pipeline corre en el job
"Auditoría de cumplimiento": un incumplimiento bloquea imagen y despliegues.

Uso:
    python3 scripts/audit-compliance.py [--report-dir DIR]

Genera DIR/auditoria-cumplimiento.md y DIR/auditoria-cumplimiento.json
(por defecto evidencias-ci/) y agrega el resumen a $GITHUB_STEP_SUMMARY.
Requiere Python 3.9+ y PyYAML.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"
K8S_DIR = ROOT / "deploy" / "k8s"

# Jobs que deben aprobar antes de cualquier despliegue (política CMP-06)
REQUIRED_GATES = {"build-and-test", "security", "sonarcloud", "compliance-audit", "image"}
DEPLOY_JOBS = {"deploy": REQUIRED_GATES, "deploy-eks": REQUIRED_GATES | {"k8s-validate", "deploy"}}
# Pasos que pueden usar continue-on-error porque NO son controles (solo publican información)
NON_GATING_STEPS = ("Snyk Monitor", "Publicar hallazgos")
# Imagen lógica que el pipeline reemplaza por la imagen etiquetada con el SHA
PIPELINE_IMAGE = "logifast-envios"
WORKLOAD_KINDS = {"Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob", "Pod"}
SENSITIVE_ENV = re.compile(r"(PASSWORD|SECRET|TOKEN|API_?KEY|PRIVATE_?KEY)", re.I)

POLICIES = {
    "CMP-01": "Secretos fuera del repositorio",
    "CMP-02": "Imagen de contenedor endurecida",
    "CMP-03": "Workloads Kubernetes endurecidos",
    "CMP-04": "Aislamiento por namespace (Pod Security 'restricted')",
    "CMP-05": "Exposición mínima de servicios",
    "CMP-06": "Controles bloqueantes en el pipeline",
    "CMP-07": "Excepciones de seguridad con caducidad",
    "CMP-08": "Trazabilidad commit → imagen → despliegue",
}


class Audit:
    def __init__(self) -> None:
        self.results: list[dict] = []

    def check(self, policy: str, ok: bool, detail: str) -> None:
        self.results.append({"politica": policy, "ok": bool(ok), "detalle": detail})

    @property
    def failures(self) -> list[dict]:
        return [r for r in self.results if not r["ok"]]


def load_yaml_docs(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as fh:
        return [d for d in yaml.safe_load_all(fh) if isinstance(d, dict)]


def k8s_manifests() -> list[tuple[Path, dict]]:
    docs = []
    for path in sorted(K8S_DIR.rglob("*.yaml")):
        if "release" in path.parts or path.name == "kustomization.yaml":
            continue
        for doc in load_yaml_docs(path):
            if "kind" in doc:
                docs.append((path.relative_to(ROOT), doc))
    return docs


def pod_spec(doc: dict) -> dict | None:
    kind = doc.get("kind")
    if kind not in WORKLOAD_KINDS:
        return None
    if kind == "Pod":
        return doc.get("spec", {})
    if kind == "CronJob":
        return doc["spec"]["jobTemplate"]["spec"]["template"]["spec"]
    return doc.get("spec", {}).get("template", {}).get("spec", {})


# ----------------------------------------------------------------------------- CMP-01
def audit_secrets(a: Audit) -> None:
    gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8", errors="replace").splitlines()
    a.check("CMP-01", ".env" in [l.strip() for l in gitignore], ".env está en .gitignore")

    tracked = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split()
    forbidden = re.compile(r"(^|/)(\.env|.*\.pem|.*\.key|.*\.p12|.*\.pfx|id_rsa.*|kubeconfig.*|credentials(\.json)?)$")
    bad = [f for f in tracked if forbidden.search(f) and not f.endswith(".env.example")]
    a.check("CMP-01", not bad, "sin archivos de credenciales versionados" + (f": {bad}" if bad else ""))

    for path, doc in k8s_manifests():
        name = f"{path}:{doc['kind']}/{doc.get('metadata', {}).get('name')}"
        if doc["kind"] == "Secret":
            a.check("CMP-01", not (doc.get("data") or doc.get("stringData")),
                    f"{name}: los Secrets no se versionan con valores (los crea el pipeline)")
        spec = pod_spec(doc)
        if not spec:
            continue
        for c in spec.get("containers", []) + spec.get("initContainers", []):
            literals = [e["name"] for e in c.get("env", []) if SENSITIVE_ENV.search(e["name"]) and "value" in e]
            a.check("CMP-01", not literals,
                    f"{name}/{c['name']}: variables sensibles desde Secret" + (f" (literal en {literals})" if literals else ""))


# ----------------------------------------------------------------------------- CMP-02
def audit_dockerfile(a: Audit) -> None:
    lines = [l.strip() for l in (ROOT / "Dockerfile").read_text(encoding="utf-8").splitlines()]
    froms = [l.split()[1] for l in lines if l.upper().startswith("FROM ")]
    unpinned = [f for f in froms if ":" not in f or f.endswith(":latest")]
    a.check("CMP-02", not unpinned, f"imágenes base con versión fija ({', '.join(froms)})")
    users = [l.split(None, 1)[1] for l in lines if l.upper().startswith("USER ")]
    last_user = users[-1] if users else "root"
    uid = last_user.split(":")[0]
    a.check("CMP-02", uid.isdigit() and int(uid) > 0,
            f"la etapa final corre con un UID numérico no root (USER {last_user})")
    remote_add = [l for l in lines if re.match(r"ADD\s+https?://", l, re.I)]
    a.check("CMP-02", not remote_add, "sin ADD de URLs remotas (descargas no verificadas)")


# ----------------------------------------------------------------------------- CMP-03 / CMP-04 / CMP-05
def audit_kubernetes(a: Audit) -> None:
    docs = k8s_manifests()
    a.check("CMP-03", any(pod_spec(d) for _, d in docs), f"manifiestos Kubernetes encontrados en {K8S_DIR.relative_to(ROOT)}")

    namespaces = {d["metadata"]["name"]: d for _, d in docs if d["kind"] == "Namespace"}
    for ns in ("logifast", "observability"):
        labels = namespaces.get(ns, {}).get("metadata", {}).get("labels", {})
        a.check("CMP-04", labels.get("pod-security.kubernetes.io/enforce") == "restricted",
                f"namespace {ns} con pod-security.kubernetes.io/enforce=restricted")

    for path, doc in docs:
        spec = pod_spec(doc)
        name = f"{path}:{doc['kind']}/{doc['metadata']['name']}"
        if doc["kind"] == "Service":
            svc = doc.get("spec", {})
            if svc.get("type") in ("LoadBalancer", "NodePort"):
                exposed = [p for p in svc.get("ports", []) if p.get("targetPort") in ("management", 8081)]
                a.check("CMP-05", not exposed, f"{name}: Service público no expone el puerto de administración/métricas")
            continue
        if not spec:
            continue
        psc = spec.get("securityContext", {})
        problems = []
        if psc.get("runAsNonRoot") is not True:
            problems.append("runAsNonRoot")
        if psc.get("seccompProfile", {}).get("type") != "RuntimeDefault":
            problems.append("seccomp RuntimeDefault")
        for flag in ("hostNetwork", "hostPID", "hostIPC"):
            if spec.get(flag):
                problems.append(flag)
        if any("hostPath" in v for v in spec.get("volumes", [])):
            problems.append("volúmenes hostPath")
        if spec.get("automountServiceAccountToken") is not False:
            problems.append("automountServiceAccountToken=false (montar el token solo de forma explícita)")
        a.check("CMP-03", not problems, f"{name}: seguridad del pod" + (f" — falta/incumple: {problems}" if problems else ""))

        for c in spec.get("containers", []):
            cname = f"{name}/{c['name']}"
            image = c.get("image", "")
            repo, _, tag = image.rpartition(":") if ":" in image.split("/")[-1] else (image, "", "")
            pinned = bool(tag) and tag != "latest"
            a.check("CMP-03", pinned or repo == PIPELINE_IMAGE, f"{cname}: imagen con versión fija ({image})")

            res = c.get("resources", {})
            missing = [f"{kind}.{r}" for kind in ("requests", "limits") for r in ("cpu", "memory", "ephemeral-storage")
                       if r not in res.get(kind, {})]
            a.check("CMP-03", not missing, f"{cname}: requests/limits de CPU, memoria y almacenamiento"
                    + (f" — faltan {missing}" if missing else ""))

            sc = c.get("securityContext", {})
            bad = []
            if sc.get("privileged"):
                bad.append("privileged")
            if sc.get("allowPrivilegeEscalation") is not False:
                bad.append("allowPrivilegeEscalation=false")
            if sc.get("readOnlyRootFilesystem") is not True:
                bad.append("readOnlyRootFilesystem=true")
            if "ALL" not in sc.get("capabilities", {}).get("drop", []):
                bad.append("capabilities.drop=[ALL]")
            if sc.get("capabilities", {}).get("add"):
                bad.append("capabilities.add")
            a.check("CMP-03", not bad, f"{cname}: securityContext del contenedor" + (f" — incumple: {bad}" if bad else ""))

            a.check("CMP-03", "readinessProbe" in c, f"{cname}: readinessProbe definida")
            if doc["metadata"].get("labels", {}).get("app.kubernetes.io/component") == "api":
                a.check("CMP-03", "livenessProbe" in c and "startupProbe" in c,
                        f"{cname}: liveness y startup probes en el microservicio")


# ----------------------------------------------------------------------------- CMP-06 / CMP-08
def audit_pipeline(a: Audit) -> None:
    wf = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    jobs = wf.get("jobs", {})
    for gate in sorted(REQUIRED_GATES | {"k8s-validate"}):
        a.check("CMP-06", gate in jobs, f"el workflow define el control '{gate}'")

    for job, required in DEPLOY_JOBS.items():
        if job not in jobs:
            a.check("CMP-06", False, f"el workflow define el job de despliegue '{job}'")
            continue
        needs = jobs[job].get("needs", [])
        needs = {needs} if isinstance(needs, str) else set(needs)
        missing = sorted(required - needs)
        a.check("CMP-06", not missing, f"'{job}' depende de todos los controles" + (f" — faltan {missing}" if missing else ""))
        cond = str(jobs[job].get("if", ""))
        a.check("CMP-06", "always()" not in cond and "failure()" not in cond,
                f"'{job}' no se fuerza a correr si un control falla")

    for jname, job in jobs.items():
        if job.get("continue-on-error") in (True, "true"):
            a.check("CMP-06", False, f"job '{jname}' marcado continue-on-error")
        for step in job.get("steps", []):
            if step.get("continue-on-error") in (True, "true"):
                sname = step.get("name", step.get("uses", "?"))
                allowed = sname.startswith(NON_GATING_STEPS)
                a.check("CMP-06", allowed, f"{jname} › '{sname}': continue-on-error solo en pasos informativos")

    text = WORKFLOW.read_text(encoding="utf-8")
    a.check("CMP-06", text.count("--severity-threshold=") >= 3, "los análisis Snyk declaran umbral de severidad")
    a.check("CMP-06", "sonar.qualitygate.wait=true" in text, "SonarCloud espera el Quality Gate y falla si no se cumple")
    a.check("CMP-06", "gitleaks" in text, "escaneo de secretos (Gitleaks) en el pipeline")

    a.check("CMP-08", "GITHUB_SHA::7" in text and "org.opencontainers.image.revision" in text,
            "la imagen se etiqueta con el SHA del commit y la etiqueta OCI revision")
    a.check("CMP-08", "kubernetes.io/change-cause" in (ROOT / "scripts" / "k8s-deploy.sh").read_text(encoding="utf-8"),
            "el despliegue Kubernetes registra commit, imagen y ejecución en el Deployment")


# ----------------------------------------------------------------------------- CMP-07
def audit_exceptions(a: Audit) -> None:
    snyk = ROOT / ".snyk"
    if not snyk.exists():
        a.check("CMP-07", True, "sin excepciones de Snyk")
        return
    policy = yaml.safe_load(snyk.read_text(encoding="utf-8")) or {}
    now = dt.datetime.now(dt.timezone.utc)
    for vuln, entries in (policy.get("ignore") or {}).items():
        for entry in entries:
            for _, rule in entry.items():
                reason, expires = rule.get("reason"), rule.get("expires")
                if isinstance(expires, str):
                    expires = dt.datetime.fromisoformat(expires.replace("Z", "+00:00"))
                ok = bool(reason) and expires is not None and expires > now
                a.check("CMP-07", ok, f".snyk {vuln}: con motivo y vigente hasta {expires:%Y-%m-%d}" if expires
                        else f".snyk {vuln}: sin fecha de expiración")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    parser.add_argument("--report-dir", default="evidencias-ci")
    args = parser.parse_args()

    a = Audit()
    for fn in (audit_secrets, audit_dockerfile, audit_kubernetes, audit_pipeline, audit_exceptions):
        try:
            fn(a)
        except Exception as exc:  # un error al leer cuenta como incumplimiento, nunca se ignora
            a.check("CMP-06", False, f"error al ejecutar {fn.__name__}: {exc!r}")

    report_dir = ROOT / args.report_dir
    report_dir.mkdir(parents=True, exist_ok=True)
    total, failed = len(a.results), len(a.failures)
    lines = ["## Auditoría de cumplimiento (scripts/audit-compliance.py)", "",
             f"**Resultado: {'APROBADA' if not failed else 'RECHAZADA'}** — {total - failed}/{total} controles cumplidos.", "",
             "| Política | Controles | Fallidos |", "|---|---|---|"]
    for pid, title in POLICIES.items():
        rs = [r for r in a.results if r["politica"] == pid]
        lines.append(f"| {pid} {title} | {len(rs)} | {sum(not r['ok'] for r in rs)} |")
    if failed:
        lines += ["", "### Incumplimientos", ""] + [f"- ❌ **{r['politica']}** {r['detalle']}" for r in a.failures]
    lines += ["", "<details><summary>Detalle de todos los controles</summary>", ""]
    lines += [f"- {'✅' if r['ok'] else '❌'} {r['politica']} — {r['detalle']}" for r in a.results]
    lines += ["", "</details>", ""]
    md = "\n".join(lines)

    (report_dir / "auditoria-cumplimiento.md").write_text(md, encoding="utf-8")
    (report_dir / "auditoria-cumplimiento.json").write_text(json.dumps({
        "fecha": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "commit": os.environ.get("GITHUB_SHA", "local"),
        "aprobada": not failed, "total": total, "fallidos": failed,
        "politicas": POLICIES, "resultados": a.results}, ensure_ascii=False, indent=2), encoding="utf-8")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as fh:
            fh.write(md)

    for r in a.results:
        print(f"[{'OK' if r['ok'] else 'FALLA'}] {r['politica']} {r['detalle']}")
        if not r["ok"] and os.environ.get("GITHUB_ACTIONS"):
            print(f"::error title=Auditoría {r['politica']}::{r['detalle']}")
    print(f"\n{total - failed}/{total} controles cumplidos — auditoría {'APROBADA' if not failed else 'RECHAZADA'}")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
