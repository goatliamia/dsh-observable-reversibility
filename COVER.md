# Cover: which changes cover which consequences

Targets are the consequences A–H recorded in PROBLEMS.md. **F (a carrier offering a different
capability set) is excluded** — it is a deliberate trade-off, not damage to remove. The question
this document answers: **what is the smallest set of changes that covers the rest, and what
stays uncovered if only some of them are accepted.**

## Candidate changes

| # | Change | Covers | Cost | Evidence / witness |
|---|---|---|---|---|
| 1 | Host supplies a carrier section in the prompt (carrying application, profile name, query pointer) | A (identity half) | one prompt section + the placement table | `packages/bundle/web-app/src/index.ts` has 0 occurrences of `profile`/`desktop`/`Electron`; measured profile `desktop`, carrier `DeepSeek Harness.exe` |
| 2 | Stop injecting the web-only contract off the web carrier (HMR / `dev:web` / "rebuild Web artifacts" / `__DSH_BOOT__`) | A (method half) | deleting a sentence on non-web carriers | measured: `GET 127.0.0.1:19387/` → 401; the desktop app loads packaged Web assets |
| 3 | Plugins declare required capabilities; a carrier lacking one leaves the plugin inactive instead of keeping the tree pending | G, and makes "usable" answerable | dependency-injection semantics | #8028 (six plugins pending, incomplete boot) — **not reproduced here**: live directory offered `webServer`, not `webRuntime`; of the `web`-profile plugins exactly one was `optional` |
| 4 | After a removal, report which other profiles still hold the package | D | one line of output; the data already exists | #3619: several workspaces must each be cleaned before the loader stops failing; local measurement: `desktop` 2 packages, `web` 37 |
| 5 | Shared data gets visible writers: the same lock, and the writing version recorded with the write | E, and the lock half of C | a storage-format decision | two carriers share `$DSH_HOME`: `dsh-desktop 0.2.0-rc.2` (nightly feed) and npm `dsh 0.1.7-rc.2` |
| 6 | Replace the global identity claim ("settings are shared") with per-consumer claims that can be checked | C (the claim half) | documentation only | #8399, with the official settings doc and a line-by-line read of `dsh-settings/lib/index.js` |
| 7 | An answer that separates installed / running / usable and names the profile | B | a query; the inventory exists | local: `web` 37 packages vs `desktop` 2; the nine repository plugins live in `web` only |

## Why each of 3–7 is necessary (remove it and something stays uncovered)

- Drop **3** → G stays: a missing capability still blocks the whole tree rather than one plugin.
- Drop **4** → D stays: a partial removal still reports success.
- Drop **5** → E stays: two versions still write one root with no writer identity; and C's lock
  half stays open even if 6 lands.
- Drop **6** → C's claim half stays: the settings document is the active profile's
  `cordis.patch.yml`, so the shared-settings sentence keeps being false.
- Drop **7** → B stays: carrier facts (1) tell the agent *where* it is, but not *what is installed
  in the other profile*.

## Ties (both options reported, no preference hidden)

| Consequence | Option A | Option B | Note |
|---|---|---|---|
| C | 6 — repair the claim (docs) | make settings actually shared (behavior) | Option B also satisfies 6, at a much higher cost; the claim must stop being false either way |
| E | 5 — visible writers (lock + version recorded) | stop sharing the data root | Option B would end cross-carrier continuity of sessions; recorded because it is a real alternative, not a recommendation |
| A | 2 alone — removing the false contract already prevents the wrong-method harm | 1 + 2 — also lets the agent state where it is | The smallest change that removes the *damage* is 2; 1 is what makes the agent correct rather than merely not-wrong |

## Cumulative cover (what is left if only some are accepted)

| Accepted | Covered | Still uncovered |
|---|---|---|
| 2 | A (damage half) | A (identity), B, C, D, E, G |
| 2 + 3 | A (damage half), G | A (identity), B, C, D, E |
| 2 + 3 + 4 | + D | A (identity), B, C, E |
| 2 + 3 + 4 + 5 | + E, C (lock half) | A (identity), B, C (claim half) |
| 2 + 3 + 4 + 5 + 6 | + C (claim half) | A (identity), B |
| all six | A (both halves), B, C, D, E, G | — (F is out of scope by decision) |

**Minimum cover: {1, 2, 3, 4, 5, 6, 7} minus nothing** — every one of the seven is needed for the
full target set, and the table above names, for each prefix of the order, exactly what stays open.
If the team wants a two-change shortlist, the pair with the largest covered set is **2 + 3**: it
removes the wrong-method harm and the hard-wait failure, and leaves B, C, D, E open — which is a
defensible stopping point, but it should be recorded as one.

## What this document does not claim

- It does not claim F should change (a carrier may offer a different capability set).
- It does not claim the cost column is complete: changes 3 and 5 touch runtime semantics, and
  their cost is a decision for their owners, not a number this survey can supply.
- Every "covers" entry names its witness; where the witness is a report rather than a local
  measurement (#8028), that is stated in the row.

---

## 中文要点

- 目标后果是 A–H 里除 **F** 之外的（F 是刻意的能力取舍，不移除）。
- 七项改动各自覆盖什么、代价、见证都在上表；**最少覆盖 = 七项都要**。
- **并列全报**：C 有"改文档"与"真把设置做成共享"两种；E 有"写者可见"与"不共享数据根"两种；
  A 有"只删假约定"与"再加载体事实"两种。都不藏偏好。
- **累积覆盖表**给出：只接受两条时缺 A(身份)、B、C、D、E；接受 2+3 是收益最大的两改，但剩下的
  必须**记成一次有意的停点**，不能当成"问题都解决了"。
