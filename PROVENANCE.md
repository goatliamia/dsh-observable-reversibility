# 这些文件从哪来

`Reversibility/` 下的源码在 **meta-law** 项目里写成（2026-09-23），发布到本仓库前做过两步**纯机械**的改动，
数学内容一行未动：语句没改、证明没改、前提没改。

## 原来的文件名

| 现在 | 原来 |
|---|---|
| `Reversibility/Basic.lean` | `MetaLaw/ObservableReversibility.lean` |
| `Reversibility/Structure.lean` | `MetaLaw/ReversibilityStructure.lean` |
| `Reversibility/Finite.lean` | `MetaLaw/ReversibilityOptimization.lean` |
| `Reversibility/BasicExamples.lean` | `MetaLaw/ObservableReversibilityTest.lean` |
| `Reversibility/StructureExamples.lean` | `MetaLaw/ReversibilityStructureTest.lean` |

## 第一步：改名

| 原 | 现 |
|---|---|
| `namespace MetaLaw` + `namespace ObservableReversibility` | `namespace Reversibility` |
| `namespace MetaLaw` + `namespace ReversibilityStructure` | `namespace Reversibility` |
| `namespace MetaLaw` + `namespace ReversibilityOptimization` | `namespace Reversibility.Finite` |
| `namespace MetaLaw` + `namespace ObservableReversibilityTest` | `namespace Reversibility.BasicExamples` |
| `namespace MetaLaw` + `namespace ReversibilityStructureTest` | `namespace Reversibility.StructureExamples` |
| `import MetaLaw.ObservableReversibility` | `import Reversibility.Basic` |
| `import MetaLaw.ReversibilityStructure` | `import Reversibility.Structure` |
| `open ObservableReversibility` / `open ReversibilityStructure` | `open Reversibility`（或删去） |
| `end X` + `end MetaLaw` | `end Reversibility`（或 `end Reversibility.Finite` 等） |

这一步只动命名空间与 import 行。

## 第二步：加「论文里的位置」

每份文件头部加了一节，写明对应的节号与定义号。**这一步只加注释块 `/-! … -/`，不动任何语句。**

## 发布时新增的

- `Reversibility/Statements.lean`：一般形式的陈述与语句守卫。其中两条定理
  （`roundTrip_iff_leftInverseOnRange_comp`、`leftInverse_of_surjective`）
  是把既有定理从 `ObservationPolicy` 包装里搬出来的直接推论，不引入新假设；
  其余是 `example`，把已有定理的语句形状钉死。
- 本目录的 README / CORRESPONDENCE / BUILD 三份文档。

## 改写前的原始字节（sha256 前 16 位）

| 原文件 | 前 16 |
|---|---|
| `MetaLaw/ObservableReversibility.lean` | `6B1DC91FE9B97971` |
| `MetaLaw/ReversibilityStructure.lean` | `E215B264FB145B83` |
| `MetaLaw/ReversibilityOptimization.lean` | `17D5CDE58D2CBE00` |
| `MetaLaw/ObservableReversibilityTest.lean` | `DAA504D8DB58CB97` |
| `MetaLaw/ReversibilityStructureTest.lean` | `17E89549F7764ACD` |

发布版（改名与加注释之后）的哈希在 [BUILD.md](BUILD.md)。
