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

Always-on options (explicit trade-off, for the team to choose):

| Option | Prompt content | Gain | Cost |
|---|---|---|---|
| Smallest | one path or command: "environment facts: `<command>`" | near-zero, never stale | the agent must run it once to be right |
| Minimal fields (suggested) | that line **+ two short fields**: carrying application, profile name | makes "where am I" correct at step one | one extra sentence per step |
| More | add UI address and access requirement (e.g. "authenticated; direct fetch 401") | saves one probe | changes with port/configuration |

On-demand facts (never in the prompt): live plugins in this profile; other dsh runtimes and
profiles on the machine. Both are long and change; expose them through a query shaped like the
existing progressive Inspect directories — a compact list first, one entry on request.
`tools/carrier-facts.mjs` in this repository prints them today, as a stopgap.

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

- **Prompt cache cost.** Injecting volatile values (URL, port, auth state) can invalidate the
  cached prefix every step. Mitigation: keep the always-on section to fields that do not change
  within a session; leave the rest on demand.
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

1. 增加一节**由宿主提供**的载体事实。READM 的 Transport 决策已写明 *"the Host supplies boot
   injections"*，位置是现成的。
2. 常驻内容三选一（见上表），**按需事实不进提示词**。
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

- **提示词缓存代价**：易变值（地址、端口、认证状态）会让缓存前缀每轮失效。缓解：常驻只放会话内
  不变的事实，其余按需；
- **值会过期**：启动时取的事实可能在会话中途失效。缓解：以按需查询为准，常驻那行只是入口；
- **范围蔓延**：本提案不碰插件激活、按 profile 的设置、两套运行时的布局——那些是各自 owner 的决定。
