#!/usr/bin/env python3
"""What is installed on this machine, and would installing it twice cause trouble?

    python core/runtime-census/census.py --scan     # write one file for the profile you are in
    python core/runtime-census/census.py --report   # read all files, print the picture
    python core/runtime-census/census.py --self-test

Why it exists: on this machine there are two dsh runtimes (the npm one and the one bundled
inside the desktop app) and many profiles. "Installed" is a word people say about the machine,
but the fact lives per profile, so nobody can answer "is it installed?" without asking
"installed where?". This writes down what each profile has, one file per profile, and reads
them back together when asked.

Rules it follows:
  * one writer per file  -> no locks, no lost updates, no clobbering another profile's format;
  * read-time merge      -> the combined picture is computed, never stored twice;
  * if something can't be read, say so -> never report "fine" because a file was unreadable.

Reads only. Writes exactly one file: `~/.dsh/runtime-census/<profile>.json` (per profile).
"""
import argparse
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

HOME = Path.home()
SHARD_DIR = HOME / ".dsh" / "runtime-census"

# Where a dsh runtime may live. Kept short on purpose: every extra root is another guess.
RUNTIME_ROOTS = [
    HOME / "AppData/Roaming/npm/node_modules/@deepseek-ai/dsh",
    HOME / "AppData/Local/Programs/DeepSeek Harness/resources/app.asar.unpacked/dsh",
    Path("/usr/local/lib/node_modules/@deepseek-ai/dsh"),
    Path("/usr/lib/node_modules/@deepseek-ai/dsh"),
]
PROFILE_DIR = HOME / ".dsh" / "profiles"


# ── reading ──────────────────────────────────────────────────────────────────────
def read_json(path: Path):
    try:
        return json.loads(path.read_bytes().decode("utf-8-sig"))
    except Exception:
        return None


def find_runtimes() -> list:
    """Where the dsh runtimes are, and which version each one is."""
    out = []
    for root in RUNTIME_ROOTS:
        pj = root / "package.json"
        if pj.is_file():
            j = read_json(pj) or {}
            out.append({"where": str(root), "version": j.get("version") or "?"})
    return out


def find_profiles() -> list:
    if not PROFILE_DIR.is_dir():
        return []
    return sorted(d.name for d in PROFILE_DIR.iterdir() if (d / "package.json").is_file())


def installed_packages(profile: str) -> list:
    """What this profile says it has, plus where each one really points."""
    pj = PROFILE_DIR / profile / "package.json"
    j = read_json(pj)
    if j is None:
        return []
    declared = list((j.get("dsh", {}).get("profile", {}) or {}).get("bundles", []) or [])
    declared += [k for k in (j.get("dependencies") or {})]
    root = PROFILE_DIR / profile / "node_modules"
    out = []
    for name in sorted(set(declared)):
        d = root / name
        entry = {"package": name, "declared_by": f"{pj} (bundles/dependencies)"}
        if d.exists():
            pkg = read_json(d / "package.json") or {}
            entry["version"] = pkg.get("version") or "?"
            try:
                entry["folder"] = str(Path(os.path.realpath(d)))
            except OSError:
                entry["folder"] = None
            entry["writes_outside_profile"] = resources_touched(Path(os.path.realpath(d)))
        else:
            entry["version"] = None
            entry["folder"] = None
            entry["writes_outside_profile"] = None      # not on disk yet: nothing to scan
        out.append(entry)
    return out


OUTSIDE = re.compile(
    r"""homedir\(\)|USERPROFILE|os\.tmpdir\(\)|tmpdir\(\)|/\.dsh[/\\]|\\\.dsh\\|"""
    r"""localhost:\d+|127\.0\.0\.1:\d+|listen\(\s*\d{2,5}""")
SKIP = {".git", "node_modules", "dist", "build", "__pycache__", ".venv", "target"}


def resources_touched(pkg_dir: Path, limit=400):
    """Places the package writes or connects to that are not inside its own profile."""
    if not pkg_dir or not pkg_dir.is_dir():
        return None
    hits, scanned = [], 0
    for f in sorted(pkg_dir.rglob("*")):
        if not f.is_file() or f.suffix not in (".js", ".mjs", ".cjs", ".py", ".ts"):
            continue
        if any(part in SKIP for part in f.parts):
            continue
        scanned += 1
        if scanned > limit:
            break
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for m in OUTSIDE.finditer(text):
            line = text[:m.start()].count("\n") + 1
            hits.append(f"{f.relative_to(pkg_dir)}:{line} {m.group(0)}")
    return sorted(set(hits))


# ── one file per profile ─────────────────────────────────────────────────────────
def save(profile: str, payload: dict) -> Path:
    SHARD_DIR.mkdir(parents=True, exist_ok=True)
    target = SHARD_DIR / f"{profile}.json"
    fd, tmp = tempfile.mkstemp(dir=SHARD_DIR, suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    os.replace(tmp, target)          # atomic on Windows and POSIX
    return target


def load_all() -> tuple:
    shards, unreadable = [], []
    if not SHARD_DIR.is_dir():
        return shards, unreadable
    for f in sorted(SHARD_DIR.glob("*.json")):
        j = read_json(f)
        if j is None:
            unreadable.append(str(f))          # never treated as "nothing to report"
        else:
            shards.append(j)
    return shards, unreadable


# ── the three checks ─────────────────────────────────────────────────────────────
def check_installs(shards: list) -> list:
    """Same package in several places: same version? same folder?"""
    by_pkg = {}
    for s in shards:
        for e in s.get("packages", []):
            by_pkg.setdefault(e["package"], []).append((s.get("profile"), e))
    out = []
    for pkg, places in sorted(by_pkg.items()):
        versions = {e.get("version") for _, e in places}
        folders = {e.get("folder") for _, e in places if e.get("folder")}
        if len(places) == 1:
            result = "ok"
        elif len(versions) > 1:
            result = "version_mismatch"
        elif len(folders) == 1:
            result = "same_folder"
        else:
            result = "ok"
        out.append({"package": pkg, "installed_in": [p for p, _ in places],
                    "versions": sorted(v for v in versions if v),
                    "folders": sorted(folders), "result": result})
    return out


def check_double_install(shards: list) -> list:
    """Installed in more than one profile AND writing somewhere shared -> trouble."""
    by_pkg = {}
    for s in shards:
        for e in s.get("packages", []):
            by_pkg.setdefault(e["package"], []).append(e)
    out = []
    for pkg, entries in sorted(by_pkg.items()):
        if len(entries) < 2:
            continue
        places = sorted({h for e in entries for h in (e.get("writes_outside_profile") or [])})
        if places:
            out.append({"package": pkg, "installed_times": len(entries),
                        "writes_outside_profile": places[:8], "result": "risk"})
        elif any(e.get("writes_outside_profile") is None for e in entries):
            out.append({"package": pkg, "installed_times": len(entries),
                        "writes_outside_profile": [], "result": "cannot_check"})
    return out


# ── self-test ────────────────────────────────────────────────────────────────────
def self_test() -> int:
    ok = True

    def chk(cond, what, detail=""):
        nonlocal ok
        ok &= bool(cond)
        print(f"  {'ok ' if cond else 'FAIL'} {what}" + (f"  <- {detail}" if detail and not cond else ""))

    def shard(profile, packages):
        return {"profile": profile, "packages": packages}

    def pkg(name, version, folder, outside):
        return {"package": name, "version": version, "folder": folder,
                "writes_outside_profile": outside}

    print("1. two profiles, same version, own folders -> ok (must not warn)")
    r = check_installs([shard("web", [pkg("p", "1.0", "/a/p", [])]),
                        shard("desktop", [pkg("p", "1.0", "/b/p", [])])])[0]
    chk(r["result"] == "ok", "no warning", r["result"])

    print("2. two profiles, different versions -> version_mismatch")
    r = check_installs([shard("web", [pkg("p", "1.0", "/a/p", [])]),
                        shard("desktop", [pkg("p", "2.0", "/b/p", [])])])[0]
    chk(r["result"] == "version_mismatch", "reported", r["result"])

    print("3. two profiles pointing at the same folder -> same_folder")
    r = check_installs([shard("web", [pkg("p", "1.0", "/same/p", [])]),
                        shard("desktop", [pkg("p", "1.0", "/same/p", [])])])[0]
    chk(r["result"] == "same_folder", "reported", r["result"])

    print("4. one profile only, writes outside -> ok (single install is not a risk)")
    chk(check_double_install([shard("web", [pkg("p", "1.0", "/a/p", ["~/.dsh/x.json"])])]) == [],
        "no risk reported", "")

    print("5. two profiles, writes outside -> risk, places listed")
    r = check_double_install([shard("web", [pkg("p", "1.0", "/a/p", ["~/.dsh/x.json"])]),
                              shard("desktop", [pkg("p", "1.0", "/b/p", ["~/.dsh/x.json"])])])
    chk(r and r[0]["result"] == "risk" and "~/.dsh/x.json" in r[0]["writes_outside_profile"],
        "risk with the shared file named", json.dumps(r, ensure_ascii=False)[:120])

    print("6. unreadable file -> cannot_check, never 'fine'")
    tmp = Path(tempfile.mkdtemp(prefix="census-"))
    try:
        global SHARD_DIR
        keep = SHARD_DIR
        SHARD_DIR = tmp
        (tmp / "web.json").write_text("{ broken", encoding="utf-8")
        shards, unreadable = load_all()
        chk(unreadable and shards == [], "the broken file is listed, not skipped",
            json.dumps(unreadable))
        SHARD_DIR = keep
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print(f"\n{'all good' if ok else 'FAILURES above'}")
    return 0 if ok else 1


def scan(profile=None) -> int:
    profile = profile or os.environ.get("DSH_PROFILE") or "unknown"
    payload = {"profile": profile,
               "runtimes": find_runtimes(),
               "packages": installed_packages(profile)}
    path = save(profile, payload)
    print(f"wrote {path}")
    print(f"  runtimes: {len(payload['runtimes'])}; packages: {len(payload['packages'])}")
    return 0


def report() -> int:
    shards, unreadable = load_all()
    runtimes, seen = {}, set()
    for s in shards:
        for r in s.get("runtimes", []):
            runtimes[r["where"]] = r["version"]
    print("dsh runtimes on this machine:")
    for where, ver in sorted(runtimes.items()):
        print(f"  {ver:14} {where}")
    print(f"profiles with a snapshot: {', '.join(sorted(s.get('profile', '?') for s in shards)) or '(none)'}")
    print("\ninstalls:")
    for r in check_installs(shards):
        if len(r["installed_in"]) > 1:
            print(f"  [{r['result']}] {r['package']}: {', '.join(r['installed_in'])}"
                  f"  versions={r['versions']}")
    risks = check_double_install(shards)
    print("\ninstalling twice:")
    for r in risks:
        print(f"  [{r['result']}] {r['package']} x{r['installed_times']}")
        for h in r["writes_outside_profile"][:5]:
            print(f"        {h}")
    if not risks:
        print("  nothing (or nothing installed twice)")
    if unreadable:
        print("\ncould not read:")
        for u in unreadable:
            print(f"  {u}   <- treated as unknown, not as 'fine'")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--scan", action="store_true")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--profile")
    a = ap.parse_args()
    if a.self_test:
        sys.exit(self_test())
    if a.scan:
        sys.exit(scan(a.profile))
    if a.report:
        sys.exit(report())
    print(__doc__)
