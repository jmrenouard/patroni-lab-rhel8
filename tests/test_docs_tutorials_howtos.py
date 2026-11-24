"""Executable validation tests for documentation, Diátaxis, i18n, Mermaid, and lab assets."""

from __future__ import annotations

import os
import py_compile
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = REPO_ROOT / "docs"

LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)\n]+)\)")
FENCE_RE = re.compile(r"^(?P<indent>[ \t]*)(?P<ticks>`{3,}|~{3,})(?P<info>.*)$")
MAKEFILE_TARGET_RE = re.compile(r"^([a-zA-Z0-9][a-zA-Z0-9_.-]*)\s*:")
MAKE_CMD_RE = re.compile(r"\bmake\s+([a-zA-Z0-9][a-zA-Z0-9_-]*)")
SCRIPT_REF_RE = re.compile(r"((?:mgmt-app/)?scripts/[a-zA-Z0-9_./-]+\.(?:sh|py))")
BOX_CHAR_RE = re.compile(r"[\u2500-\u257f]")

FRENCH_DOC_MARKERS = re.compile(
    r"\b(?:procédure|démarrage|utilisation|prérequis|sauvegarde|récupération|"
    r"restauration|équilibrage|haute\s+disponibilité|retour\s+à\s+l'accueil)\b",
    re.IGNORECASE,
)
ENGLISH_HOWTO_BANNED = re.compile(
    r"(?:;|should\b|would\b|may\b|might\b|shall\b|"
    r"\b(?:don't|doesn't|isn't|aren't|won't|can't|let's)\b)",
    re.IGNORECASE,
)


def _iter_non_venv_markdown() -> list[Path]:
    """Return all Markdown files in the repository excluding ansible/venv."""
    return sorted(
        path
        for path in REPO_ROOT.rglob("*.md")
        if "ansible/venv" not in path.as_posix() and ".git/" not in path.as_posix()
    )


def _strip_fenced_blocks(text: str) -> list[tuple[int, str]]:
    """Return (lineno, line) pairs outside fenced code blocks."""
    lines: list[tuple[int, str]] = []
    fence_char: str | None = None
    fence_len = 0
    for lineno, raw_line in enumerate(text.splitlines(), start=1):
        if fence_char is not None:
            if re.match(rf"^\s*{re.escape(fence_char)}{{{fence_len},}}\s*$", raw_line):
                fence_char = None
                fence_len = 0
            continue
        match = FENCE_RE.match(raw_line)
        if match:
            ticks = match.group("ticks")
            fence_char = ticks[0]
            fence_len = len(ticks)
            continue
        lines.append((lineno, raw_line))
    return lines


def _extract_fenced_blocks(text: str) -> list[dict[str, object]]:
    """Extract all fenced code blocks with line number, indent, info string, and body."""
    blocks: list[dict[str, object]] = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        match = FENCE_RE.match(lines[i])
        if not match:
            i += 1
            continue
        indent = match.group("indent")
        ticks = match.group("ticks")
        info = match.group("info").strip()
        fence_char = ticks[0]
        fence_len = len(ticks)
        start_line = i + 1
        body: list[str] = []
        i += 1
        while i < len(lines):
            if re.match(rf"^\s*{re.escape(fence_char)}{{{fence_len},}}\s*$", lines[i]):
                break
            body.append(lines[i])
            i += 1
        blocks.append(
            {
                "line": start_line,
                "indent": indent,
                "info": info,
                "code": "\n".join(body),
            }
        )
        i += 1
    return blocks


def _parse_makefile_targets() -> set[str]:
    """Return concrete target names declared in the root Makefile."""
    targets: set[str] = set()
    makefile = REPO_ROOT / "Makefile"
    for line in makefile.read_text(encoding="utf-8").splitlines():
        if line.startswith(("\t", "#")):
            continue
        match = MAKEFILE_TARGET_RE.match(line)
        if match and match.group(1) != ".PHONY":
            targets.add(match.group(1))
    return targets


class TestDocsTutorialsAndHowTos(unittest.TestCase):
    """Validate Diátaxis docs, FR/EN isolation, Mermaid hygiene, scripts, and configs."""

    def test_diataxis_structure_links_and_ste_rules(self) -> None:
        required_docs = [
            DOCS_DIR / "index.md",
            DOCS_DIR / "01-tutorials" / "index.md",
            DOCS_DIR / "01-tutorials" / "01-deploy-and-verify-cluster.md",
            DOCS_DIR / "01-tutorials" / "02-failover-and-recovery-lab.md",
            DOCS_DIR / "02-how-to-guides" / "index.md",
            DOCS_DIR / "02-how-to-guides" / "cluster-lifecycle-and-certs.md",
            DOCS_DIR / "02-how-to-guides" / "switchover-and-failover-recovery.md",
            DOCS_DIR / "02-how-to-guides" / "etcd-quorum-and-backup.md",
            DOCS_DIR / "03-reference" / "index.md",
            DOCS_DIR / "03-reference" / "architecture-ports-and-env.md",
            DOCS_DIR / "04-explanation" / "index.md",
            DOCS_DIR / "04-explanation" / "ha-consensus-and-security-model.md",
        ]
        for doc_path in required_docs:
            self.assertTrue(doc_path.is_file(), f"Missing Diátaxis document: {doc_path}")

        repo_resolved = REPO_ROOT.resolve()
        for md_file in _iter_non_venv_markdown():
            text = md_file.read_text(encoding="utf-8")
            self.assertNotIn("file:///home/jmren", text, f"Local file URI leaked in {md_file}")
            for lineno, line in _strip_fenced_blocks(text):
                for match in LINK_RE.finditer(line):
                    raw = match.group(1).strip()
                    target = raw.split()[0] if not raw.startswith("<") else raw[1 : raw.find(">")]
                    target = target.split("#", 1)[0].split("?", 1)[0].strip()
                    if not target or target.startswith(("http://", "https://", "mailto:", "data:")):
                        continue
                    self.assertFalse(
                        target.startswith("file://"),
                        f"Disallowed file:// link at {md_file}:{lineno} -> {target}",
                    )
                    resolved = (md_file.parent / target).resolve()
                    self.assertTrue(
                        resolved.exists() and str(resolved).startswith(str(repo_resolved)),
                        f"Broken relative link at {md_file}:{lineno} -> {target}",
                    )

        howto_files = sorted(
            p for p in (DOCS_DIR / "02-how-to-guides").glob("*.md") if p.name != "index.md"
        )
        self.assertGreaterEqual(len(howto_files), 3)
        for guide in howto_files:
            text = guide.read_text(encoding="utf-8")
            self.assertRegex(text, r"(?m)^##\s+Prerequisites\b", f"Missing Prerequisites in {guide}")
            self.assertRegex(text, r"(?m)^##\s+Verification\b", f"Missing Verification in {guide}")
            self.assertRegex(text, r"(?m)^##\s+Rollback\b", f"Missing Rollback in {guide}")
            self.assertNotRegex(
                text,
                r"(?m)^##+\s+.*(?:Why|Architecture|Theory|Explanation|Background)\b",
                f"Theory heading disallowed in how-to {guide}",
            )
            prose_lines = [line for _, line in _strip_fenced_blocks(text)]
            prose = "\n".join(prose_lines)
            self.assertIsNone(
                ENGLISH_HOWTO_BANNED.search(prose),
                f"Banned STE punctuation/modal/contraction found in {guide}",
            )

        diataxis_script = (
            Path.home() / ".gemini" / "config" / "skills" / "diataxis-docs" / "scripts" / "diataxis_check.py"
        )
        if diataxis_script.is_file():
            proc = subprocess.run(
                [sys.executable, str(diataxis_script), str(DOCS_DIR), "--strict", "--check-ste", "--lang", "en"],
                capture_output=True,
                text=True,
                timeout=60,
            )
            self.assertEqual(
                proc.returncode,
                0,
                f"diataxis_check.py failed:\n{proc.stdout}\n{proc.stderr}",
            )

    def test_fr_en_separation_and_drift_remediation(self) -> None:
        readme_en = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        readme_fr = (REPO_ROOT / "README.fr.md").read_text(encoding="utf-8")

        self.assertIn("[Français](README.fr.md)", readme_en)
        self.assertIn("[English](README.md)", readme_fr)
        self.assertNotRegex(readme_en, FRENCH_DOC_MARKERS)
        self.assertNotIn("Architecture System", readme_en)
        self.assertNotIn("Architecture System", readme_fr)
        self.assertNotIn("Details complets", readme_fr)
        self.assertIn("PgBouncer", readme_en)
        self.assertIn("HAProxy", readme_en)

        for md_file in sorted(DOCS_DIR.rglob("*.md")):
            text = md_file.read_text(encoding="utf-8")
            self.assertIsNone(
                FRENCH_DOC_MARKERS.search(text),
                f"French text mixed into English Diátaxis doc {md_file}",
            )

        issues_doc = (REPO_ROOT / "POTENTIAL_ISSUES.md").read_text(encoding="utf-8")
        self.assertNotIn("performance_schema", issues_doc)
        self.assertNotIn("mgnt-app", issues_doc)

        quickstart = (REPO_ROOT / "documentation" / "QUICKSTART.md").read_text(encoding="utf-8")
        self.assertNotIn("confivgurez", quickstart)
        self.assertNotIn(".env.example", quickstart)
        self.assertIn(".env example", quickstart)

    def test_mermaid_diagrams_and_zero_ascii_art(self) -> None:
        mermaid_blocks: list[tuple[Path, int, str]] = []
        for md_file in _iter_non_venv_markdown():
            text = md_file.read_text(encoding="utf-8")
            for block in _extract_fenced_blocks(text):
                info = str(block["info"]).lower()
                code = str(block["code"])
                indent = str(block["indent"])
                lineno = int(block["line"])
                self.assertIsNone(
                    BOX_CHAR_RE.search(code),
                    f"Box-drawing ASCII art detected in {md_file}:{lineno}",
                )
                if info.startswith("mermaid"):
                    self.assertEqual(indent, "", f"Indented mermaid fence at {md_file}:{lineno}")
                    self.assertRegex(
                        code.lstrip(),
                        r"^(?:graph|flowchart|sequenceDiagram|stateDiagram|classDiagram|erDiagram)\b",
                        f"Invalid Mermaid header at {md_file}:{lineno}",
                    )
                    mermaid_blocks.append((md_file, lineno, code))
                elif re.match(r"^(?:graph|flowchart)\s+(?:TD|LR|TB|RL)\b|^sequenceDiagram\b", code.lstrip()):
                    self.fail(f"Untagged Mermaid diagram block at {md_file}:{lineno}")

        self.assertGreaterEqual(len(mermaid_blocks), 7, "Expected at least 7 verified Mermaid blocks")

        readme_en = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        self.assertNotIn("HAProxy --> PgBouncer", readme_en)
        self.assertRegex(readme_en, r"PgBouncer\s*-->.*HAProxy")

    def test_referenced_scripts_make_targets_compose_and_syntax(self) -> None:
        targets = _parse_makefile_targets()
        self.assertGreater(len(targets), 20)

        docs_to_check = [
            REPO_ROOT / "README.md",
            REPO_ROOT / "README.fr.md",
            *sorted(DOCS_DIR.rglob("*.md")),
        ]
        for md_file in docs_to_check:
            text = md_file.read_text(encoding="utf-8")
            for make_match in MAKE_CMD_RE.finditer(text):
                target = make_match.group(1)
                self.assertIn(target, targets, f"Undocumented/missing Makefile target '{target}' in {md_file}")
            for script_match in SCRIPT_REF_RE.finditer(text):
                script_rel = script_match.group(1)
                if "*" in script_rel:
                    continue
                self.assertTrue(
                    (REPO_ROOT / script_rel).is_file(),
                    f"Missing referenced script '{script_rel}' in {md_file}",
                )

        py_compile.compile(str(REPO_ROOT / "scripts" / "tests" / "stress_test.py"), doraise=True)
        py_compile.compile(str(REPO_ROOT / "scripts" / "manage" / "generate_html_report.py"), doraise=True)

        stress_help = subprocess.run(
            [sys.executable, str(REPO_ROOT / "scripts" / "tests" / "stress_test.py"), "--help"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(stress_help.returncode, 0, stress_help.stderr)
        for flag in ("--type", "--host", "--port", "--user", "--threads", "--delay", "--max-req", "--duration"):
            self.assertIn(flag, stress_help.stdout)

        try:
            import yaml  # type: ignore
        except ImportError:
            yaml = None
        if yaml is not None:
            for yml_file in sorted(REPO_ROOT.rglob("*.y*ml")):
                if "ansible/venv" in yml_file.as_posix():
                    continue
                yaml.safe_load(yml_file.read_text(encoding="utf-8"))

        compose_file = REPO_ROOT / "docker-compose.yml"
        compose_text = compose_file.read_text(encoding="utf-8")
        for svc in ("etcd1:", "etcd2:", "etcd3:", "node1:", "node2:", "node3:", "haproxy:", "pgbouncer:"):
            self.assertIn(svc, compose_text)

        if os.name != "nt" and shutil.which("docker"):
            compose_check = subprocess.run(
                ["docker", "compose", "-f", str(compose_file), "config", "-q"],
                cwd=str(REPO_ROOT),
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertEqual(compose_check.returncode, 0, compose_check.stderr)

        if os.name != "nt" and shutil.which("bash"):
            sh_files = sorted(
                p for p in REPO_ROOT.rglob("*.sh") if "ansible/venv" not in p.as_posix()
            )
            self.assertGreaterEqual(len(sh_files), 48)
            for sh_file in sh_files:
                res = subprocess.run(["bash", "-n", str(sh_file)], capture_output=True, text=True, timeout=15)
                self.assertEqual(res.returncode, 0, f"bash -n failed on {sh_file}: {res.stderr}")

        if os.name != "nt" and shutil.which("go"):
            go_res = subprocess.run(
                ["go", "test", "./..."],
                cwd=str(REPO_ROOT / "mgmt-app"),
                capture_output=True,
                text=True,
                timeout=60,
            )
            self.assertEqual(go_res.returncode, 0, f"go test failed:\n{go_res.stdout}\n{go_res.stderr}")


if __name__ == "__main__":
    unittest.main()
