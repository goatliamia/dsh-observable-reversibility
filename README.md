# 观察面相对的可逆性：判决，而不是义务

**一句话**：把「卸载之后世界回得来」从**组件作者的义务**变成**被核对的判决**，
并说清楚这个判决在什么条件下等于「在观察商空间上恒等」。
判决相对于一个**声明的观察面**成立，不是物理状态的全等。

背景论文：*A Programming Paradigm for Spatiotemporal Composability*（arXiv:2608.25512v1）。
形式化在 `Reversibility/`，逐条对应关系与逐字引文见 [CORRESPONDENCE.md](CORRESPONDENCE.md)。

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
