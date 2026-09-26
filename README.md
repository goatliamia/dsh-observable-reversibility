# 观察面相对的可逆性：判决，而不是义务

**一句话**：把「卸载之后世界回得来」从**组件作者的义务**变成**被核对的判决**，
并说清楚这个判决在什么条件下等于「在观察商空间上恒等」。
判决相对于一个**声明的观察面**成立，不是物理状态的全等。

背景论文：*A Programming Paradigm for Spatiotemporal Composability*（arXiv:2608.25512v1）。
形式化在 `Reversibility/`，逐条对应关系与逐字引文见 [CORRESPONDENCE.md](CORRESPONDENCE.md)。

它接在 **DSH / Cordis** 那条线上：插件在运行时被装载与卸载，而「卸载之后环境回没回来」今天
只是作者的义务 —— 运行时不核对，差异也没有名字。给插件作者的那条义务写在
[skill/plugin-teardown-obligation/SKILL.md](skill/plugin-teardown-obligation/SKILL.md)。

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

## 五、怎么建

    lake exe cache get      # 第一次：取 Mathlib 编译缓存（约 GB 级）
    lake build

固定版本：`leanprover/lean4:v4.34.0` + `mathlib` `v4.34.0`（manifest 里是 `5ed2965…`）。
最近一次构建的命令、输出与源码哈希见 [BUILD.md](BUILD.md)。

## 六、文件

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
| [LICENSE](LICENSE) | MIT |

每次推送由 GitHub Actions 跑一次 `lake build`（见 [.github/workflows/build.yml](.github/workflows/build.yml)）。


---

## 运行时那半：一台能跑的检查机

机器本体：**`runtime-check.py`**（一个文件、无依赖）——`python runtime-check.py --demo` 就能看到三种结果；这次的运行记录在 `receipts/dsh-plugins-2026-09-26.json`。

这个仓给的是**判据**（上面的定理）。判据要能落地，还需要有人**在插件系统管不到的地方看着**——下面这台机器就是那半，已经跑了真实数据。

**它做什么（人话）**：先说清"要看哪些东西"（哪些目录/文件、哪些登记项），然后装一次、看三次（装之前 / 装完 / 卸完），做**三次对照**：

| 对照 | 比的是 |
|---|---|
| 加了什么 | 实际多出来的 ↔ 登记说加了什么 |
| 删了什么 | 实际少掉的 ↔ 撤销报告说删了什么 |
| 装前 vs 卸后 | 装之前看到的 ↔ 卸之后看到的 |

**结果只有三种**，而且决定落在哪一种是**算出来的**，不是作者自己说的：

- `clean` —— 三次对照全过，什么都没留下；
- `declared` —— 对照过了，但作者**具名**说明有一处管不到的改动；
- `unknown` —— 有东西没撤、**而且没人说明它是什么**，或者根本没法检查。

对应给用户看到的三句话：

```
卸载完成：什么都没留下。
卸载完成：留下的东西作者已说明 —— 发送出去的消息撤不回
卸载完成：有 1 处没撤，而且没人说明它是什么（side.txt）
```

第三条是今天缺的那句：**干净的卸载和不干净的卸载，现在在外部看起来一模一样。**

**两条规矩**：拿不准就说拿不准（任何一次对照做不了，结果就是 `unknown`，默认永远不是 `clean`）；**检查不能住在被检查的插件里**——"要看哪些东西"必须由外面声明，并且要包含插件系统管不到的地方。

**真实运行结果**（三个真插件，观察点在临时目录 + 桩服务表 + 工具表，不是插件自报）：

```
downstream/plugins/invariance/index…   → clean
downstream/plugins/assets/index.js     → clean
downstream/lifecycle/fixtures/multi…   → clean
```

**一处必须说清的**：上面第二项对照里的"撤销报告"，我们现在是用"插件登记过的那批"代理的（disposer 撤的就是它自己登记的）。它是一个**假设**——如果 disposer 少撤了一部分，第三次对照会失败，所以**不会假报 clean**。要把它变成事实，需要运行时**自己报它撤了什么**（见下）。

## 我们建议官方做的改变

机器只能**发现**和**具名**；要让这个问题彻底消失，得改 API 的形状。按"让错误写不出来"排：

1. **只给带登记的写入口**：共享状态只能通过会返回"撤销句柄"的接口拿；裸写没有入口 → "没登记的写"写不出来；
2. **运行时自己报撤销**：撤销时由运行时记下"撤了什么"（现在的"撤销报告"是我们代理的；变成事实后第二项对照才真正独立）；
3. **撤销顺序由运行时定**（反序回放）：顺序不再由插件决定，插件也没机会搞错（同顺序复合会失败，已有 `Fin 3` 上的最小反例）；
4. **管不到的能力必须具名才拿得到**：`declare(是什么, 为什么)` 换能力；不命名就拿不到 → "没名字的那一笔"写不出来；
5. **把结果挂到操作上，并当装载闸门**：`unknown` 不进默认路径，`declared` 带着名字进。安全模式要的就是这条判据。

我们这边已经给了两样：**一份给作者的义务说明**（`skill/plugin-teardown-obligation/`）和**一台能跑的机器**（上面那三张快照 + 三次对照 + 三种结果）。剩下的机制（隔离、事务、闸门、给用户看哪一句）是宿主的事——**只有官方改，这个问题才会真的不存在。**

**边界（一直成立）**：只看"要看哪些东西"这个清单里的东西；清单之外发生了什么，不在结果里。清单该包含什么，是政策，不是这台机器能定的。
