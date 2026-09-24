# 记号与论文的对应

论文：*A Programming Paradigm for Spatiotemporal Composability*（arXiv:2608.25512v1）。
下面的引文是 2026-09-24 从 PDF 全文抽文本、按节号定位后逐字抄下来的。

**这张表有两栏，别混着读。**

- **机器核的**：Lean 能核「这条语句就是这条语句」——`Reversibility/Statements.lean` 里的守卫
  会在语句被改弱时让构建失败；也能核没有 `sorry` / `admit` / 自定义 `axiom`。
- **要人读的**：Lean 核不了「这段代码就是论文的 Definition 31」。那一栏只有逐字引文，判断权在读者；
  下面这张表把两栏分开写，就是为了不让后者混进前者。

| # | 论文 | 逐字 | 本文里的位置 | 哪一栏 |
|---|---|---|---|---|
| 1 | §3.1.1 | 「we pair each transformation `f` with another transformation `g` that undoes `f`, and call `g` a left inverse of `f` … **Undoing is one-sided: what an inverse is held to is `g ∘ f` and never `f ∘ g`.**」 | 主定理右边的 `Uₒ (Lₒ o) = o` 就是单侧左逆，写成在 `range q` 上逐点 | 引文 + 机器核（形状） |
| 2 | §3.1.1 Definition 1 | 「Define the **twisted composition** of pairs of context transformations by `(f₁, g₁) ∘ (f₂, g₂) ≔ (f₁ ∘ f₂, g₂ ∘ g₁)`」 | `stacked_round_trip`：两组件的**反序**卸载正是这条乘法的第二个分量 | 引文 + 机器核 |
| 3 | §3.1.1 Theorem 7 | 「For every `(γ, φ) ∈ ∂Γ` and every pair `(f, g)` with `g(f(γ)) = γ`, `recoverΓ(trackΓ(f, g)(γ, φ)) = recoverΓ(γ, φ)`」 | **本文没有形式化他们的演算**（`∂Γ` / `trackΓ` / `recoverΓ` 都不在 Lean 里）。本文的定理是它在「整次装载/卸载 + 一个声明观察面」上的推广 | **只是引文** |
| 4 | §3.1.2 Definition 8 | 「The witness holds each returned inverse to one equation, `g(δ) = γ`: **the inverse is required to revert the effect only at the state where it was applied.**」 | 本判决也是**逐次运行**说的（`Run` = 一次装卸的四个快照与两份声明）。「逐状态」是原文的形状，不是本文的加强 | 引文 + 机器核 |
| 5 | §3.3.2 Definition 31 / 33 | 「Values `v, v′` are **indistinguishable** … when every test over `𝒜` is defined at both or at neither and yields the same outcomes at both」；「`σ ≃_S σ′ ≔ dom(σ) ∩ S = dom(σ′) ∩ S ∧ ∀k ∈ dom(σ) ∩ S. σ(k) ≃_k σ′(k)`」 | **本仓库的 `Equivalent` 是所声明的 `observe` 诱导的等价（`Setoid.ker`），不是论文这个等价。** 两者的关系由一个显式前提取代：`AdequateFor` | 引文 + 机器核（`AdequateFor` 的存在） |
| 6 | §3.3.2 开头 | 「The recovery guarantee of Section 3.1 asserts an equality of states (Theorem 7), **which is an idealization**, because the physical state cannot be recovered as it stood」 | 本文回答的正是这一句：**在什么观察面下、等式在商上成立**（主定理的 ⟺） | 引文 |
| 7 | §4.3.2 | 「each binding is restored only up to what its key's equivalence forgets, so a monotone allocator is not rewound, a heap's layout free does not restore, and **a message already sent stays sent**」 | 三态里的 `declared-irreversible` 就是给这一类写**命名**的位置；`unknown` 是不肯命名时的落点 | 引文 |
| 8 | §5.1.1 | 「the callback supplies an inverse, and that the inverse reverts the effect it accompanies is **an obligation on the component author rather than a property the runtime verifies**」 | `classify` + 三项核对：不替作者去证逆成立，只把这句话变成**可执行的判决**（`classify_verified_sound` 保证判决只能从核对里来） | 引文 + 机器核 |
| 9 | §6.1 | 「A location lies outside when either ability fails, so an operation on it **acts as `idΓ`** and is therefore neither tracked nor reverted.」 | 两个交换方块的失效模式：界外写让 `q ∘ U = Uₒ ∘ q` 破掉。前提守不住时正确动作是**把差异命名**，不是继续声称等号 | 引文 |

## 本文比论文多出来的那一步

论文把恢复等式定位成 idealization、并给出它的界（§3.3.2、§4.3.2），
但没有写「逐次运行的核对在什么条件下**确实等于**商空间上的恒等」。主定理给的就是这一步，
它需要两个交换方块作前提。**那两块不是免费的**：它们是「观察面之外没有未被命名的写」的数学写法（第 9 行）。

## 范围

证明的是**编码进去的语句与前提**：

1. 观察商上的往返刻画（主定理与推论），以及它的两个前提；
2. 三态判决的可靠性 —— `verified-reversible` 只能从三项核对里来。

不在范围内的是：

- 任何真实系统的可逆性；
- 工程观察与论文 contextual equivalence 之间的桥：它需要一个显式前提 `AdequateFor`；
- `declared-irreversible` 与 `unknown` 的「不可逆」含义：前者是具名披露，后者是没观察；
- 物理状态的全等（`L ∘ U = id`）。
