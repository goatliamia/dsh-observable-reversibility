# 提案：让 agent 知道自己跑在哪个应用里

面向 DSH 官方。**问题**：会话的"环境说明"由**表面那层**生产，而桌面端复用同一层，于是 agent 拿到一句只对 `dsh web` 成立的话。

---

## 1. 现象与证据

### 1.1 生产这段文字的函数（`packages/bundle/web-app/src/index.ts`）

```ts
/** Model-visible orientation and acceptance boundary for sessions created through `dsh web`. */
function webSurfacePrompt(webUrl: string): string {
  const updateContract = 'The client-plugin HMR receiver is active, but client-plugin changes reload '
    + 'without a refresh only while `pnpm run dev:web` is also running from this same checkout to rebuild '
    + 'their bundles; verify that watcher before promising automatic updates. Every other change — the '
    + 'apps/web shell and plain packages — requires rebuilding the affected Web artifacts and verifying '
    + 'this existing URL after a page refresh. '
  return `You are interacting with the user through the DeepSeek Harness Web GUI at ${webUrl}. `
    + 'When the user refers to "this page", "this GUI", or "this app" without naming another target, they mean this GUI. '
    + 'The browser provides no implicit DOM, route, or screenshot context. '
    + updateContract
    + 'Starting another server does not update this GUI. '
    + 'The apps/web Vite entry builds the shell but is not a standalone application because only '
    + 'dsh web injects window.__DSH_BOOT__. '
    + 'Do not start a replacement server unless the user asks; if one is needed, use a managed background '
    + 'job and verify its exact URL.'
}
```

### 1.2 这个文件里没有"载体"这一维

同一份文件里，以下关键词出现次数：`DSH_PROFILE` **0**、`profile` **0**、`desktop` **0**、`Electron` **0**、`boot injection` **0**；只有 `DSH_WEB_URL`（5 处）被用到。

**结论**：不是"漏写一句 desktop"，而是**这段文字的产地只知道表面**。

### 1.3 桌面端复用的就是这一层

`~/.dsh/profiles/desktop/package.json` 的 bundles 是 `[@deepseek-ai/dsh-base, @deepseek-ai/dsh-web-app]`，而桌面端应用自身是 `@deepseek-ai/dsh-desktop`（Electron 壳 + `app.asar/dsh` 里打包好的引擎与依赖树）。官方 README 的决策表里写着：

- **Runtime**：不需要系统 Node/pnpm ⇒ `dsh` 跑在 Electron 下（`ELECTRON_RUN_AS_NODE=1`）；
- **Transport**：*"Electron loads packaged Web assets; **the Host supplies boot injections and authenticated APIs**"*；
- **Plugin changes**：*"Desktop and Web need the **same** installation and activation behavior"*。

### 1.4 两句话对桌面端会话是具体不成立的

| 提示词原话 | 桌面端实际 |
|---|---|
| through the DeepSeek Harness **Web GUI** at `http://127.0.0.1:19387` | Electron 壳 + 自带引擎；该地址**需要认证**（本机实测 `GET /` → **401**） |
| HMR / "重建 Web 产物 + 刷新" / "只有 `dsh web` 注入 `window.__DSH_BOOT__`" | 桌面端加载**打包好的 Web 资产**，不是本仓 checkout ⇒ 按这条去验证改动，**方法就错了** |

第二条比第一条更严重：它会让 agent 用错方法验证自己的工作。

### 1.5 连带后果（同一台机器）

- 插件按 **profile** 装：本机 `web` 有 37 个包、`desktop` 只有 2 个基座 bundle；仓库那 9 个插件装在 `web`，桌面端会话**一个都拿不到**；
- agent 因此用**错世界的清单**回答"装了吗 / 我能用吗"，并据此给用户错误结论。

---

## 2. 方案

### A. 宿主侧：加一段由宿主注入的载体事实（推荐）

架构里**已经有**这个位置：`Transport` 决策写着 Host 提供 **boot injections**，而提示词本来就是**按来源分段拼的**（存在 `app:web-surface` 这一节）。

1. 新增一节 `app:carrier`，由**宿主**（`apps/desktop-host` 或 `apps/cli`）注入，内容就是下面六个字段；
2. `webSurfacePrompt` 里那段 **web 专属契约**（HMR / dev-web / `__DSH_BOOT__` / "重建 Web 产物"）**只在 web 载体下注入**；桌面端要么不注入，要么替换为"本应用加载打包好的 Web 资产，改动需重启应用"；
3. 提示词里那句 `Web GUI` 改为**载体名 + 表面**两段，例如："You are running inside the DeepSeek Harness Desktop app; the user sees the Web UI served at `…`."

### B. 插件侧：一个可立即使用的自查命令（临时措施，不需要宿主改动）

见同目录的 `carrier-facts.mjs`：打印那六个字段，供 agent/人自查；也可包成插件工具。

---

## 3. 什么进提示词，什么按需查（这一节是修正过的）

**不能把清单倒进系统提示词。** 系统提示词每轮都在、要求稳定；而"哪些插件是活的""机器上还有哪些 profile"既长又易变，绝大多数轮次用不上。按"先给最便宜的一层、需要时再展开"：

### 3.1 常驻内容：三种给法，**请官方定**（这里只列取舍）

| 给法 | 提示词里放什么 | 好处 | 代价 |
|---|---|---|---|
| **最小** | 一行路径或命令：`运行环境的事实见 <路径>；用 <命令> 查` | 成本几乎为零，不随环境变化 | agent 要先查一次才走得对 |
| **中等（本提案建议）** | 上面那一行 **＋ 两个短字段**：运行它的应用（carrier）、profile 名 | 一次就把"我在哪"说对；今天那两处错都在这一格 | 每轮多一句 |
| **更多** | 再加界面地址与访问方式（例如"该地址需要认证，直连返回 401/403"） | 省掉一次探测 | 端口/配置一变就要跟着变 |

**无论选哪一种，下面这一件都必须做**：桌面端**不要**注入那段 web 专属契约（HMR / `pnpm run dev:web` / "重建 Web 产物 + 刷新" / `__DSH_BOOT__`）——它对桌面端不成立，而且比"认错身份"更危险（会让 agent 用错方法验证自己的工作）。


| 字段 | 例子 | 为什么必须在 |
|---|---|---|
| **1 载体** | `DeepSeek Harness Desktop app`（Electron RunAsNode） | 它决定后面那些 web 专属指令**成不成立**（今天错的就是这一条） |
| **2 profile 名** | `desktop` | 一句话就能定"我在哪个世界"，成本极低 |
| **3 界面与访问方式** | `http://127.0.0.1:19387`（需认证：直连 401/403） | 决定"我能不能自己去访问那个地址" |
| **4 一句指向** | `环境事实用 <命令> 查；装了 / 在跑 / 我能不能用是三件事，说清是哪一件` | 给出口，不倒清单 |

**并且**：那段 **web 专属契约**（HMR / `pnpm run dev:web` / "重建 Web 产物 + 刷新" / `__DSH_BOOT__`）**在桌面端要么不注入、要么替换成"本应用加载打包好的 Web 资产，改动要重启应用"**——**这才是本方案的主要修复**，而不是加字段。

### 3.2 按需（不进提示词，用命令/工具查）

| 字段 | 例子 | 为什么按需 |
|---|---|---|
| 5 这个 profile 里**活的**插件 | `dsh-base, dsh-web-app`（本机 web profile 有 37 个包） | 长、会变；只在问插件时才需要。**提示词里最多给个数** |
| 6 本机还有哪些运行时 / profile | npm `0.1.7-rc.2`；profiles：`web`、`web-b`、`headless`…（本机 15 个） | 更长更易变；只在"装了吗/哪一份在跑"这类问题上需要 |

两种给法都行：**一个命令**（`carrier-facts.mjs`，见同目录代码），或**一个工具/查询**（形状照 Inspect 那套：先给目录与计数，再要具体一项）。



| # | 字段 | 来源 | 例子 |
|---|---|---|---|
| 1 | 我在哪个 profile | `DSH_PROFILE` | `desktop` |
| 2 | 它的目录 | `DSH_PROFILE_DIR` | `…\.dsh\profiles\desktop` |
| 3 | 谁在承载我 | 进程祖先 + 承载应用包描述 | `DeepSeek Harness.exe`（`@deepseek-ai/dsh-desktop 0.2.0-rc.2`） |
| 4 | 我面对的界面 | `DSH_WEB_URL` + 是否需认证 | `http://127.0.0.1:19387`（需认证） |
| 5 | 这个 profile 里**活的**插件 | 该 profile 的 `dsh.profile.bundles` / `dependencies` | `dsh-base`、`dsh-web-app` |
| 6 | 本机还有哪些运行时/profile | 一次普查 | npm `dsh 0.1.7-rc.2`；`web`(37 包)… |

**写法三条（对常驻那四个字段同样适用）**：每条**带主语**；**装了 / 在跑 / 我能不能用**分开写；**不确定就标出来**（不许用沉默表示没问题）。

---

## 4. 验收（可测）

1. **快照测试**：新增 `apps/desktop/tests/expected/*carrier*`，断言桌面端会话的提示词：**包含**载体名与 profile 名；**不含** `Web GUI`；**不含** `pnpm run dev:web` 那段契约；并且**有长度上限**（不许把 profile 列表或已装插件列表整段倒进去——那些按需查）；
2. **web 会话不回归**：`apps/web/tests/expected/web-runtime-context/web-surface-prompt.expected.md` 保持不变；
3. **一条人工可复现的核对**：在桌面端会话里问 agent"你在哪"，答案必须与 `DSH_PROFILE`、进程祖先、profile bundles 三者一致。

---

## 5. 不做 / 边界

- **不动插件激活语义**（激活按 profile 隔离、桌面端禁用 `webserver`/`web-runtime` 是另一件事，另有讨论 #8028）；
- **不改 web 会话既有契约**（避免回归）；
- 本方案**只解决"agent 知道自己在哪"**：不解决"两处安装如何合并"，也不改锁与设置的归属。
