# Proposal: let the agent know which application carries the session

## Problem

A session's orientation text has a **producer with no value**: `webSurfacePrompt()` in
`packages/bundle/web-app/src/index.ts` emits it, and the desktop app loads that same bundle
(`profiles/desktop` bundles = `dsh-base` + `dsh-web-app`). The file contains no occurrence of
`profile`, `desktop`, `Electron`, or `boot injection`, so nothing there can state which
application carries the session — the text names the surface only.

Two statements in that text are false for a desktop session:

| Text | Desktop session |
|---|---|
| "through the DeepSeek Harness Web GUI at …" | Electron shell (`ELECTRON_RUN_AS_NODE=1`); that address answers **401** to a direct fetch |
| the web-only contract: HMR / `pnpm run dev:web` / "rebuild the Web artifacts" / `__DSH_BOOT__` | the desktop app loads **packaged** Web assets, not this checkout — following that contract makes the agent verify its work the wrong way |

Measured on the machine this was written on: profile `desktop`, carrier `DeepSeek Harness.exe`,
`GET http://127.0.0.1:19387/` → 401, live bundles = `dsh-base`, `dsh-web-app`.

## Proposal

1. Add one host-supplied prompt section for carrier facts. The README's Transport decision
   already states that *"the Host supplies boot injections"*, so the position exists.
2. Always-on content: choose one of the three options below; on-demand facts stay out of the
   prompt and are read when needed.
3. On a non-web carrier, do **not** inject the web-only contract (HMR / `dev:web` /
   "rebuild Web artifacts" / `__DSH_BOOT__`); replace it with that carrier's own statement.

Always-on content is a **placement decision**, not a risk to be mitigated: every candidate fact is
classified by whether its value can be the same for every step of a session. Nothing below needs
a new mechanism — only the choice of where each field lives.

| Fact | Stability | Where | Basis for the judgement |
|---|---|---|---|
| carrying application (`desktop` / `web` / CLI) | constant for a session, and per carrier | **prefix** | set once at launch; identical for every session of that carrier |
| profile name | constant for a session | **prefix** | read from `DSH_PROFILE` at launch |
| the command that reads the rest | constant | **prefix** | it is a name, not a value |
| UI address and port | same value for a whole run, may differ across runs and configurations | **TBD** | measured stable within this run (19387); whether a different port is an acceptable different prefix is the team's call |
| whether the UI requires authentication | follows the carrier | **TBD** | constant per carrier in practice, not guaranteed by contract |
| live plugins in this profile | changes when a plugin is installed or removed | query | measured: 2 here, 37 in the other profile |
| other runtimes / profiles on the machine | changes; 15 profiles here, many of them experiments | query | length and churn |
| application version | changes on every update (nightly feed) | query | a prefix containing it breaks on each update |

Two rules the table encodes:

- a fact may enter the prefix **only if its value is the same for every step of a session**;
- a fact whose value is merely *usually* the same goes in the **TBD** column — decided by the
  team, not assumed. (The two TBD rows are the only open questions in this proposal.)

On-demand facts are exposed through a query shaped like the existing progressive Inspect
directories — a compact list first, one entry on request. `tools/carrier-facts.mjs` in this
repository prints them today, as a stopgap.

## Alternatives considered

- **Rewrite `webSurfacePrompt()` to be carrier-generic.** Rejected: the producer is the web
  bundle; it cannot know the carrier, and generalizing it loses the web-specific contract that
  is correct and useful for `dsh web` sessions.
- **Put the lists (live plugins, other profiles) in the prompt.** Rejected: they are volatile
  and long; the cost is paid every step.
- **Do nothing and let the agent infer from the environment.** Rejected by measurement: two
  wrong decisions were made in one session from the current text — treating a plugin installed
  for another profile as usable here, and explaining a change with the web rebuild contract.

## Acceptance criteria

1. A desktop session's assembled prompt contains the carrying application and the profile name,
   and does **not** contain `Web GUI`, `pnpm run dev:web`, or the `__DSH_BOOT__` sentence.
2. A web session's prompt is unchanged — `apps/web/tests/expected/web-runtime-context/` snapshot
   stays green.
3. The prompt has a length bound: no plugin list and no profile list may be inlined.
4. Manual check: asking the agent "which application are you running in, and which profile"
   returns answers consistent with `DSH_PROFILE`, the process ancestry, and the profile's bundles.

## Risks

- **Prompt cache cost is settled by the placement table above**, not by a separate mitigation:
  only facts whose value is constant for a session enter the prefix, so the block is
  byte-identical from the second step onward, and the same prefix is reusable across sessions of
  the same (carrier, profile) pair. Check: assemble the block twice in one session and require an
  empty diff, rejecting the block if it contains a port-like digit run or a timestamp.
- **Stale values.** Facts captured at boot can go stale if the profile changes mid-session.
  Mitigation: the on-demand query is authoritative; the always-on line points at it.
- **Scope creep.** This proposal does not touch plugin activation, per-profile settings, or the
  two-runtime layout. Those are separate decisions with their own owners.

---

# 提案：让 agent 知道自己跑在哪个应用里（中文对照）

## Problem

会话的环境说明**有生产者、没有值**：它由 `packages/bundle/web-app/src/index.ts` 的
`webSurfacePrompt()` 生成，而桌面端加载的正是同一个 `dsh-web-app` bundle（`profiles/desktop` 的
bundles = `dsh-base` + `dsh-web-app`）。该文件里 `profile` / `desktop` / `Electron` /
`boot injection` 出现 **0** 次——它没有任何一处能说出"是哪个应用在承载这个会话"。

其中两句对桌面端会话不成立：

| 原文 | 桌面端实际 |
|---|---|
| "through the DeepSeek Harness Web GUI at …" | Electron 壳（`ELECTRON_RUN_AS_NODE=1`）；该地址直连返回 **401** |
| web 专属约定（HMR / `pnpm run dev:web` / "重建 Web 产物" / `__DSH_BOOT__`） | 桌面端加载的是**打包好的** Web 资产，不是本仓；照它做等于**用错方法验证自己的工作** |

本机实测：profile `desktop`、承载者 `DeepSeek Harness.exe`、`GET 127.0.0.1:19387/` → 401、
当前 profile 活的 bundles 只有那两个。

## Proposal

1. 增加一节**由宿主提供**的载体事实。README 的 Transport 决策已写明 *"the Host supplies boot
   injections"*，位置是现成的。
2. **常驻内容是一道"放哪"的判定，不是要缓解的风险**——每一项候选事实，按"它在一个会话里能否
   每步都一样"分类（见上表）。表里只需要判断，不需要新机制。编码成两条规矩：
   - 只有**每一步值都一样**的事实才进前缀；
   - 只是"通常一样"的进 **TBD** 列——**由官方定，不替他们假设**（整份提案只有这两行是待定）。
3. 非 web 载体上**不要注入**那段 web 专属约定，换成该载体自己的说法。

## Alternatives considered

- 把 `webSurfacePrompt()` 改成载体无关：**否**——生产者是 web bundle，它无法知道载体，而且会丢掉
  对 `dsh web` 会话正确且有用的那段约定；
- 把清单倒进提示词：**否**——长且易变，代价每轮都付；
- 什么都不做、让 agent 自己从环境推断：**否**（有实测）——一个会话里据此判断错两次。

## Acceptance criteria

1. 桌面端会话的提示词含承载应用与 profile 名，且**不含** `Web GUI`、`pnpm run dev:web`、
   `__DSH_BOOT__` 那句；
2. web 会话的提示词不变（`apps/web/tests/expected/web-runtime-context/` 快照保持绿）；
3. 提示词有长度上限：不得内联插件清单或 profile 清单；
4. 人工核对：问 agent"你在哪个应用、哪个 profile"，答案与 `DSH_PROFILE`、进程祖先、profile
   bundles 三者一致。

## Risks

- **提示词缓存代价由上面那张判定表解决**，不再单列缓解：只有会话内恒定的事实进前缀，于是从第二步起
  该块逐字节不变；同一个 (载体, profile) 组合的前缀还可以跨会话复用。可核：一个会话里装配两次，
  要求 diff 为空；块内出现像端口的连续数字或时间戳就判不合规；
- **值会过期**：启动时取的事实可能在会话中途失效。缓解：以按需查询为准，常驻那行只是入口；
- **范围蔓延**：本提案不碰插件激活、按 profile 的设置、两套运行时的布局——那些是各自 owner 的决定。
