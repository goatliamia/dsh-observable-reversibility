# 描述与事实不一致时，谁来核对

**一句话**：把「卸载之后世界回得来」从**组件作者的义务**变成**被核对的判决**，
并说清楚这个判决在什么条件下等于「在观察商空间上恒等」。
判决相对于一个**声明的观察面**成立，不是物理状态的全等。

背景论文：*A Programming Paradigm for Spatiotemporal Composability*（arXiv:2608.25512v1）。
形式化在 `Reversibility/`，逐条对应关系与逐字引文见 [CORRESPONDENCE.md](CORRESPONDENCE.md)。

它接在 **DSH / Cordis** 那条线上：插件在运行时被装载与卸载，而「卸载之后环境回没回来」今天
只是作者的义务 —— 运行时不核对，差异也没有名字。给插件作者的那条义务写在
[skill/plugin-teardown-obligation/SKILL.md](skill/plugin-teardown-obligation/SKILL.md)。

## 这个仓库里有什么

一套**判据**，和它落在两处的结果；以及由第二处引出的一份对外提案。

| | 在哪 | 一句话 |
|---|---|---|
| 判据（通用那一半） | [`Reversibility/`](Reversibility/) + [runtime-check.py](runtime-check.py) | 卸载可逆性：从**义务**变成**判决** |
| 落在第一处：插件卸载 | [skill/plugin-teardown-obligation/SKILL.md](skill/plugin-teardown-obligation/SKILL.md) | 机制内的归 `ctx.effect`，机制外的必须具名 |
| 落在第二处：会话的环境说明 | 下面第五节 | 会话拿到的环境说明要与它**实际运行的应用**一致 |
| 由第二处引出的提案 | [proposals/agent-knows-its-carrier.md](proposals/agent-knows-its-carrier.md) | 要给的字段、放前缀还是走查询、验收 |
| 问题与覆盖登记 | [PROBLEMS.md](PROBLEMS.md) · [COVER.md](COVER.md) | 每条候选的 owner / 生效路径 / 消失什么 / 剩下什么 / 保留理由；最少改哪几处覆盖哪些后果 |
| 工具 | [tools/carrier-facts.mjs](tools/carrier-facts.mjs) | 一条命令打印这个会话的环境事实 |

两处同源：**都是"描述与事实不一致，而且没人核对"**；区别只在消费者 —— 第一处是插件作者，
第二处是会话里的 agent。所以第二处用的还是第一处那套东西：三项独立核对、三态判决、
以及"前提属于谁"的那笔账。

## 一、定理（一般形式）

状态空间 `S`、观察 `q : S → O`、装载 `L : S → S`、卸载 `U : S → S`。
若存在观察层变换 `Lₒ, Uₒ : O → O` 使两个方块**交换**：

    q ∘ L = Lₒ ∘ q          q ∘ U = Uₒ ∘ q

则

    (∀ s, q (U (L s)) = q s)   ⟺   (∀ o ∈ range q, Uₒ (Lₒ o) = o)

Lean：`Reversibility.roundTrip_iff_leftInverseOnRange_comp`（[Statements.lean](Reversibility/Statements.lean)）。

**这不是废话，理由在前提上**：右边是**观察层**上的全称，左边是**状态空间**上的全称，
交换方块是唯一把两者接起来的东西。没有它们，右边根本写不出来（`Lₒ`、`Uₒ` 不存在），
左边只是状态空间里一句没人核得了的话。所以那两个方块不是技术性假设 ——
它们就是**「观察面之外不许有未被命名的写」的数学写法**。

**这两块到底是谁的**：它们的内容来自**论文自己写的界**——§6.1「界外的位置不被追踪，当作 `idΓ`」、
§3.3.2「恢复等式是理想化」、§5.1.1「逆是否真的撤掉了它伴随的效果，是**作者的义务**，运行时不核对」。
所以**这不是为了证定理而加的假设，而是论文的界被写成了可检查的条件**。

它在工程上成不成立，取决于**宿主**：插件对共享环境的改动是否**全被记账**、记账与观察是否一致、
撤销是否由运行时**自己报**。分工因此是三方的：

| 谁 | 给什么 |
|---|---|
| 论文 | 理想化的恢复等式，以及它的三处界 |
| 宿主 | **前提**：记账是否完整、记账与观察是否一致、撤销是否自己报 |
| 本仓 | 前提的**验收**（机器）+ 前提守住时的**等价**（主定理） |

同一台机器量出来的缺口也因此分得清：**没有观察器**、**撤销报告靠代理** → 宿主那一边没做到；
**有东西没撤又没人说明** → 插件作者那一边。

**商那一端**：`~q ≔ ker q`，于是 `S / ~q ≃ range q`（第一同构定理）。
右边「在 `range q` 上逐点」不是取巧，它就是商空间上的逐点恒等。

### 推论

| 结论 | 说明 |
|---|---|
| 单射 / 满射 | `Lₒ` 在 `range q` 上单射、`Uₒ` 把 `range q` 映满 `range q`。**只能在 `range q` 之内说**：对整个 `O` 说「`Lₒ` 单射」是假的 |
| 幂等投影 | `Lₒ ∘ Uₒ` 幂等 |
| 不动点 | 恰好是装载像（`range Lₒ ∩ range q`） |
| 反序卸载 | 两个组件必须**反序**撤：`UₒA ∘ UₒB` 是 `LₒB ∘ LₒA` 的左逆。同顺序会失败，`Fin 3` 上给了反例 |
| 闭包 | 幂等**不是**闭包：还要声明的预序、`Monotone`、扩张性，才接上 `ClosureOperator`（closed ⟺ 在装载像里），再往上要 `PartialOrder` 才有 Galois insertion |
| `q` 满射时 | `Lₒ`、`Uₒ` 由 `L`、`U` 唯一确定，「可达值域上的左逆」升级成普通的 `Function.LeftInverse` |

## 二、判决：三态，三项独立核对

不要求「全世界都可逆」，要求**不许静默**。每个组件卸载后给一个三态：

| 判决 | 含义 |
|---|---|
| `verified-reversible` | 三项核对全过（有观察见证） |
| `declared-irreversible` | 作者**具名**声明界外写，写明是什么 |
| `unknown` | 没观察，或核对对不上 |

`verified-reversible` 的条件是三项**独立**核对，不是「作者说它撤了」：

1. **装载记录对账** —— 登记的新增等于观察到的可见增量；
2. **撤销报告对账** —— disposer 报告的删除等于观察到的可见减量；
3. **往返快照** —— 装载前的观察等于卸载后的观察。

判决 **fail-closed**：任一项对不上转 `unknown`；没有观察器时**绝不**输出 `verified-reversible`；
空的不可逆声明同样转 `unknown`。这些不是纪律条文，是 `classify_verified_sound` 的内容。

判据与边界的试件在 [BasicExamples.lean](Reversibility/BasicExamples.lean)（三态的正反例，
含「观察上回得来、物理状态没回来」那一格）。

## 三、为什么可以这样判

三项核对逐状态全过，合起来就是 `U ∘ L` 在 `S / ~q` 上**逐点恒等**
（`audited_composition_is_quotient_identity`）；配上两个交换方块，就等价于
「在可达观察值上 `Uₒ ∘ Lₒ = id`」。**所以这是一个有定理背书的判决，不是约定。**

方向也有用：它把**状态空间上的全称**换成**观察值域上的全称** —— 后者才是有限次观察能核掉的东西。

## 四、范围

证明的是**编码进去的语句与前提**：观察商上的往返刻画（主定理与推论），
以及三态判决的可靠性 —— `verified-reversible` 只能从三项核对里来。

写在明面上的三件事：

- 恢复到的是**观察面上的等价**，不是物理状态的全等（`L ∘ U = id` 与任意时刻回滚不在范围内）。
- **观察独立于 disposer 与 journal**：快照来自外部观察者，不是组件自报。
- 工程观察与论文 contextual equivalence 之间有一个**显式前提**（Lean 里的 `AdequateFor`），
  本仓库把它保留为前提。

两条结构性的界线：

- 三份**离散**快照看不见两次采样之间产生又消失的副作用；只看服务 key 也看不见同 key 下换实现。
  要作这类声明，得扩大观察签名，或给出连续日志的正确性证明。
- `declared-irreversible` 是具名披露，`unknown` 是没观察：两者都不含「不可逆」的证明。

## 五、落在第二处：会话的环境说明

同一套东西换个消费者。会话的「环境说明」由 **web 应用那层**生成 ——
`packages/bundle/web-app/src/index.ts` 里的 `webSurfacePrompt()`，注释写着
*"for sessions created through `dsh web`"* —— 而桌面端加载的正是同一个 bundle
（`profiles/desktop` 的 bundles = `dsh-base` + `dsh-web-app`）。
**这段文字有生产者，没有值**：它要说的是「哪个应用在承载这个会话」，而那个文件里
`profile` / `desktop` / `Electron` / `boot injection` 出现 **0** 次。

其中两句对桌面端**具体不成立**：

| 原文 | 桌面端实际 |
|---|---|
| "through the DeepSeek Harness **Web GUI** at …" | Electron 壳（`ELECTRON_RUN_AS_NODE=1`），该地址直连返回 **401** |
| web 专属约定：HMR / `pnpm run dev:web` / "重建 Web 产物 + 刷新" / `__DSH_BOOT__` | 桌面端加载**打包好的** Web 资产，不是本仓 —— 照它做等于**用错方法验证自己的工作** |

本机实测（2026-10-01）：profile `desktop`；承载者 `DeepSeek Harness.exe`；
`GET http://127.0.0.1:19387/` → **401**；这个 profile 里活的插件只有 `dsh-base` 与 `dsh-web-app`
（另一个 profile `web` 有 37 个包）；机器上另一份运行时是 npm 的 `0.1.7-rc.2`，另有 15 个别的 profile。

- **提案**：[proposals/agent-knows-its-carrier.md](proposals/agent-knows-its-carrier.md) ——
  按 `Problem / Proposal / Alternatives considered / Acceptance criteria / Risks` 组织；
  含一张"每项事实放前缀还是走查询"的判定表，**只有两行留给官方定**；
- **问题登记**：[PROBLEMS.md](PROBLEMS.md) —— 每条候选按 owner、生效路径、消失什么、剩下什么、
  最强的保留理由记录，并标成 **R**（不可达）/ **N**（收窄，写明损失）/ **P**（受保护义务或证据不足）；
- **覆盖**：[COVER.md](COVER.md) —— 最少改哪几处、每处覆盖哪些后果、并列全报，
  以及"只接受其中几条时还剩什么没被覆盖"；
- **工具**（都在这个仓库里，clone 下来就能跑）：[tools/carrier-facts.mjs](tools/carrier-facts.mjs)、
  [tools/preflight.mjs](tools/preflight.mjs)（**可达性诊断**：这个组合能不能激活这个插件）、
  [tools/census.py](tools/census.py)（按 profile 清点安装）。用法见下一节。

## 怎么用（拿到这个仓库之后）

三件东西，互不依赖，按你想看的选：

| 想干什么 | 需要什么 | 命令 |
|---|---|---|
| 看这台机器上装了什么、哪些插件在哪个 profile 里 | 一份装好的 DSH（Python 3） | `python tools/census.py --scan` 然后 `python tools/census.py --report` |
| 问"这个组合能不能激活这个插件" | 上面那份 + 从会话里取一次可用服务清单 | `node tools/preflight.mjs --profile <名字> --services <清单.json>` |
| 让 agent（或你）知道会话跑在哪个应用里 | 一份装好的 DSH（Node 18+） | `node tools/carrier-facts.mjs` |
| 核一遍 Lean 那一半 | Lean 4 + Mathlib（见下一节） | `lake build` |

`preflight.mjs` 的服务清单来自运行中的会话（官方 Inspect 的 `Service.listService`，把输出存成
JSON 即可，脚本只读文件、不连运行时）。三个脚本都只读；唯一会写的是 `census.py --scan`，
它写 `~/.dsh/runtime-census/<profile>.json`，**一个 profile 一个文件**。

## 六、怎么建

    lake exe cache get      # 第一次：取 Mathlib 编译缓存（约 GB 级）
    lake build

固定版本：`leanprover/lean4:v4.34.0` + `mathlib` `v4.34.0`（manifest 里是 `5ed2965…`）。
最近一次构建的命令、输出与源码哈希见 [BUILD.md](BUILD.md)。
每次推送由 GitHub Actions 跑一次 `lake build`（见 [.github/workflows/build.yml](.github/workflows/build.yml)）。

## 七、文件

| 路径 | 是什么 |
|---|---|
| [Reversibility/Basic.lean](Reversibility/Basic.lean) | 观察政策、商、`AdequateFor` 桥、三项核对、三态判决及其可靠性 |
| [Reversibility/Structure.lean](Reversibility/Structure.lean) | 主定理与推论：商 ≃ 可达值域、单射/满射、幂等投影、不动点、反序、闭包门槛 |
| [Reversibility/Statements.lean](Reversibility/Statements.lean) | 一般形式的陈述 + **漂移守卫**（语句被改弱则构建失败） |
| [Reversibility/Finite.lean](Reversibility/Finite.lean) | 精确有限例：目标只区分「服务/文件」时，充分观察面的最低成本是 2 |
| [Reversibility/BasicExamples.lean](Reversibility/BasicExamples.lean) | 三态判决的正反试件 |
| [Reversibility/StructureExamples.lean](Reversibility/StructureExamples.lean) | 反例：同顺序卸载失败、幂等但不扩张、可达之外不成立 |
| [skill/plugin-teardown-obligation/SKILL.md](skill/plugin-teardown-obligation/SKILL.md) | 给插件作者的那条义务：机制内的归 `ctx.effect`，机制外的必须具名 |
| [CORRESPONDENCE.md](CORRESPONDENCE.md) | 记号与论文的逐条对应（哪一栏机器核、哪一栏要人读） |
| [PROVENANCE.md](PROVENANCE.md) | 这批源码从哪来、做过哪两步机械改动 |
| [BUILD.md](BUILD.md) | 构建记录：命令、固定版本、被构建的字节 |
| [runtime-check.py](runtime-check.py) · [receipts/](receipts/) | 真插件上的三态判决，与真实运行留下的收据 |
| [LICENSE](LICENSE) | MIT |
