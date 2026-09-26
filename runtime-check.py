#!/usr/bin/env python3
"""可逆性检查机：装一次、卸一次，看看有没有留下东西。

    python runtime-check.py --self-test   # 自检
    python runtime-check.py --demo        # 三种结果各印一遍

它在做什么，用人话说：

  1. 先说清**要看哪些东西**（watch：哪些目录/文件、哪些登记项）；
  2. 装之前看一次 → 装完看一次 → 卸完看一次（三张快照）；
  3. **三次对照**：
       加了什么      vs  说加了什么
       删了什么      vs  说删了什么
       装之前看到的  vs  卸之后看到的
  4. 给一个结果：`clean` / `declared` / `unknown`，并列出**留下的东西**。

规矩两条：
  · **拿不准就说拿不准**：任何一次对照做不了，结果就是 unknown，默认永远不是 clean；
  · **检查不能住在被检查的插件里**：watch 必须由外面声明，包括插件系统管不到的地方；
    没有外面的人在看，就不许说 clean。

依据的规则：`roundTrip_iff_leftInverseOnRange_comp`
（github.com/goatliamia/dsh-observable-reversibility，Reversibility/Statements.lean）。
本文件只是把它跑起来，规则本身不在这个文件里。

**保证**：在这份 watch 清单和这三次对照上，结果判得准。
**不保证**：watch 清单铺满了 —— 清单之外的改动不在结果里。
"""
import argparse
import json
import sys
from pathlib import Path

CLEAN, DECLARED, UNKNOWN = "clean", "declared", "unknown"


def snapshot(watch: dict) -> set:
    """按 watch 清单看一次：每个文件一条，每个登记项一条。"""
    seen = set()
    for p in watch.get("paths", []):
        f = Path(p)
        if not f.exists():
            continue
        if f.is_file():
            seen.add(f"{p} ({f.stat().st_size} B)")
        else:
            for x in sorted(f.rglob("*")):
                if x.is_file():
                    seen.add(f"{x.relative_to(f)} ({x.stat().st_size} B)")
    for t in watch.get("tables", []):
        f = Path(t)
        if f.is_file():
            try:
                for k in json.loads(f.read_text(encoding="utf-8")):
                    seen.add(f"{f.name}: {k}")
            except Exception:
                seen.add(f"{f.name}: <读不动>")
    return seen


def check(watch, load, unload, claimed_added=None, claimed_removed=None, declared=None,
          watching=True):
    """跑一次装卸，返回 {result, checks, left, rule}。"""
    if not watching:
        return {"result": UNKNOWN, "checks": [],
                "why": "没有观察器：插件系统外面没人在看，所以不能说 clean",
                "left": [], "rule": RULE}
    if declared is not None and not str(declared).strip():
        return {"result": UNKNOWN, "checks": [], "why": "作者声明是空的（空的等于没说）",
                "left": [], "rule": RULE}

    before = snapshot(watch)
    load()
    added = snapshot(watch) - before
    unload()
    after = snapshot(watch)
    removed = (before | added) - after
    left = sorted(before ^ after)

    checks = [
        {"compare": "加了什么 vs 说加了什么",
         "ok": claimed_added is None or set(claimed_added) == added,
         "added": sorted(added), "claimed": sorted(claimed_added or [])},
        {"compare": "删了什么 vs 说删了什么",
         "ok": claimed_removed is None or set(claimed_removed) == removed,
         "removed": sorted(removed), "claimed": sorted(claimed_removed or [])},
        {"compare": "装之前看到的 vs 卸之后看到的",
         "ok": before == after, "before": sorted(before), "after": sorted(after)},
    ]
    if not all(c["ok"] for c in checks):
        bad = "、".join(c["compare"] for c in checks if not c["ok"])
        return {"result": UNKNOWN, "checks": checks, "left": left,
                "why": f"这几次对照没过：{bad}", "rule": RULE}
    if declared:
        return {"result": DECLARED, "checks": checks, "left": left,
                "why": f"对照都过了，但作者说明有一处管不到的改动：{declared}", "rule": RULE}
    return {"result": CLEAN, "checks": checks, "left": left, "why": "三次对照全过", "rule": RULE}


RULE = ("roundTrip_iff_leftInverseOnRange_comp"
        "（github.com/goatliamia/dsh-observable-reversibility）")


def say(r: dict) -> str:
    """给人看的那一句话。"""
    if r["result"] == CLEAN:
        return "卸载完成：什么都没留下。"
    if r["result"] == DECLARED:
        return f"卸载完成：留下的东西作者已说明 —— {r['why'].split('：')[-1]}"
    if r.get("left"):
        return f"卸载完成：有 {len(r['left'])} 处没撤，而且没人说明它是什么（{r['left'][0]}）"
    return f"没能检查：{r.get('why', '')}"


def self_test() -> int:
    import shutil, tempfile
    ok = True

    def chk(c, what, detail=""):
        nonlocal ok
        ok &= bool(c)
        print(f"  {'✓' if c else '✗'} {what}" + (f" —— {detail}" if detail and not c else ""))

    def world(out_of_band=False, declare=None, empty=False):
        tmp = Path(tempfile.mkdtemp(prefix="rev-"))
        (tmp / "state").mkdir()
        (tmp / "svc.json").write_text("[]", encoding="utf-8")
        watch = {"paths": [str(tmp / "state")], "tables": [str(tmp / "svc.json")]}
        added, removed = [], []

        def load():
            (tmp / "state" / "a.txt").write_text("x", encoding="utf-8")
            (tmp / "svc.json").write_text('["svc.a"]', encoding="utf-8")
            added.extend(["a.txt (1 B)", "svc.json: svc.a"])
            if out_of_band:
                (tmp / "state" / "side.txt").write_text("y", encoding="utf-8")

        def unload():
            (tmp / "state" / "a.txt").unlink()
            (tmp / "svc.json").write_text("[]", encoding="utf-8")
            removed.extend(["a.txt (1 B)", "svc.json: svc.a"])

        d = "界外写" if declare else ("" if empty else None)
        return watch, load, unload, d, added, removed, tmp

    print("一、干干净净 → clean")
    w, ld, ul, d, ad, rm, tmp = world()
    r = check(w, ld, ul, ad, rm, d)
    chk(r["result"] == CLEAN, "判 clean", json.dumps(r, ensure_ascii=False)[:120]); print("     " + say(r))
    shutil.rmtree(tmp, ignore_errors=True)

    print("二、留下一处、没人说明 → unknown，并指出是哪一处")
    w, ld, ul, d, ad, rm, tmp = world(out_of_band=True)
    r = check(w, ld, ul, ad, rm, d)
    chk(r["result"] == UNKNOWN and r["left"], "判 unknown 并列出留下的", str(r["left"]))
    chk(any("side.txt" in x for x in r["left"]), "留下的里有那一处", str(r["left"])); print("     " + say(r))
    shutil.rmtree(tmp, ignore_errors=True)

    print("三、作者说明了 → declared（名字带出去）")
    w, ld, ul, d, ad, rm, tmp = world(declare=True)
    r = check(w, ld, ul, ad, rm, d)
    chk(r["result"] == DECLARED, "判 declared", json.dumps(r, ensure_ascii=False)[:120]); print("     " + say(r))
    shutil.rmtree(tmp, ignore_errors=True)

    print("四、拿不准就说拿不准")
    w, ld, ul, d, ad, rm, tmp = world()
    r = check({}, ld, ul, None, None, None, watching=False)
    chk(r["result"] == UNKNOWN, "没有观察器 → unknown", str(r["result"])); print("     " + say(r))
    shutil.rmtree(tmp, ignore_errors=True)
    w, ld, ul, d, ad, rm, tmp = world(empty=True)
    r = check(w, ld, ul, ad, rm, d)
    chk(r["result"] == UNKNOWN, "空声明 → unknown", str(r["result"]))
    shutil.rmtree(tmp, ignore_errors=True)

    print(f"\n自检：{'全过' if ok else '有没过'}")
    return 0 if ok else 1


def demo() -> int:
    import shutil, tempfile
    for label, kw in (("干干净净", {}),
                      ("留下一处、作者说明了", {"declare": True}),
                      ("留下一处、没人说明", {"out_of_band": True})):
        tmp = Path(tempfile.mkdtemp(prefix="rev-demo-"))
        (tmp / "state").mkdir(); (tmp / "svc.json").write_text("[]", encoding="utf-8")
        watch = {"paths": [str(tmp / "state")], "tables": [str(tmp / "svc.json")]}
        added, removed = [], []
        def load():
            (tmp / "state" / "a.txt").write_text("x", encoding="utf-8")
            (tmp / "svc.json").write_text('["svc.a"]', encoding="utf-8")
            added.extend(["a.txt (1 B)", "svc.json: svc.a"])
            if kw.get("out_of_band"):
                (tmp / "state" / "side.txt").write_text("y", encoding="utf-8")
        def unload():
            (tmp / "state" / "a.txt").unlink()
            (tmp / "svc.json").write_text("[]", encoding="utf-8")
            removed.extend(["a.txt (1 B)", "svc.json: svc.a"])
        r = check(watch, load, unload, added, removed,
                  "发送出去的消息撤不回" if kw.get("declare") else None)
        print(f"[{label}]  result={r['result']}")
        print(f"    {say(r)}")
        shutil.rmtree(tmp, ignore_errors=True)
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--demo", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        sys.exit(self_test())
    if a.demo:
        sys.exit(demo())
    print(__doc__)
