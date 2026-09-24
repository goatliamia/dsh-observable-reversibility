# 构建记录

本仓库钉住 `leanprover/lean4:v4.34.0` 与 `mathlib v4.34.0`。下面这一次是在本机跑的完整输出。

| 项 | 值 |
|---|---|
| 命令 | `lake build` |
| Lean | `Lake version 5.0.0-src+293d5d0 (Lean version 4.34.0)` |
| mathlib | `v4.34.0`，manifest 解析为 `5ed2965256430c3649e86755f9576b54eca72435` |
| 结果 | `Build completed successfully (946 jobs).`，退出码 0 |

被构建的字节（sha256 前 16 位）：

| 文件 | 前 16 |
|---|---|
| `Reversibility/Basic.lean` | `11A6AF232992162A` |
| `Reversibility/Structure.lean` | `E508DC9944FF9ED3` |
| `Reversibility/Finite.lean` | `D66ED748B82E4264` |
| `Reversibility/BasicExamples.lean` | `1D01AB81BF6E4225` |
| `Reversibility/StructureExamples.lean` | `AE85EDEFC328BD19` |
| `Reversibility/Statements.lean` | `08CE593A871908EA` |
| `Reversibility.lean` | `6836FF6F671F06F5` |

原始输出：[build.log](build.log)。

新机器上第一次：

    lake exe cache get      # 取 Mathlib 的编译缓存（约 GB 级，一次性）
    lake build

## 这份记录说明什么

- 这些源码在钉住的 Lean 与 Mathlib 上被内核接受；没有 `sorry` / `admit` / 自定义 `axiom`。
- 它说明的是**编码进去的语句与前提**，不是「这段源码等于论文的某个定义」——
  后一条只有逐字引文，判断权在读者，见 [CORRESPONDENCE.md](CORRESPONDENCE.md)。
