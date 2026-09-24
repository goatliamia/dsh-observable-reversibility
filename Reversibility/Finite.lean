import Reversibility.Structure
import Mathlib.Data.Fintype.Prod

namespace Reversibility.Finite

open Reversibility

/-!
An exact finite example of minimizing the observation surface subject to an
explicit target equivalence. This is a finite policy world, not a DSH model.
-/

/-!
## 这算的是什么

8 个状态、8 种观察政策：目标合同只区分「服务」与「文件」两项时，
`AdequateFor` 恰好等价于「观察服务 ∧ 观察文件」，成本下界 2，最优政策正是这两项；
目标若把「消息已发」也算重要，最优解必然改变。也就是说，
**「桥要多少才够」是可以算的**，而算出来的答案依赖于声明的目标合同。

*这是有限政策世界里的一个精确例，不是任何真实系统的模型*（原文就这么写，保留）。
-/


abbrev World := Bool × Bool × Bool
abbrev Mask := Bool × Bool × Bool

/-- Coordinates: service presence, profile-file content bit, outbound message bit. -/
def observe (mask : Mask) (state : World) : World :=
  (if mask.1 then state.1 else false,
   if mask.2.1 then state.2.1 else false,
   if mask.2.2 then state.2.2 else false)

def policy (mask : Mask) : ObservationPolicy World World Unit where
  observe := observe mask
  visibleEffects := fun _ => ∅

/-- The demanded contract distinguishes service and file states, but deliberately
does not distinguish already sent messages. -/
def demandedEquivalent (a b : World) : Prop :=
  a.1 = b.1 ∧ a.2.1 = b.2.1

/-- Enumerating all finite states yields a necessary and sufficient observation
condition. Observing messages is optional for this exact demanded contract. -/
theorem adequate_iff (mask : Mask) :
    AdequateFor (policy mask) demandedEquivalent ↔
      mask.1 = true ∧ mask.2.1 = true := by
  cases mask with
  | mk service rest =>
    cases rest with
    | mk file message =>
      cases service <;> cases file <;> cases message <;>
        simp only [AdequateFor, Equivalent, policy, demandedEquivalent, observe] <;>
        decide

def cost (mask : Mask) : Nat :=
  (if mask.1 then 1 else 0) +
  (if mask.2.1 then 1 else 0) +
  (if mask.2.2 then 1 else 0)

def optimalMask : Mask := (true, true, false)

theorem adequate_cost_lower_bound (mask : Mask)
    (adequate : AdequateFor (policy mask) demandedEquivalent) :
    2 ≤ cost mask := by
  obtain ⟨service, file⟩ := (adequate_iff mask).mp adequate
  cases mask with
  | mk s rest =>
    cases rest with
    | mk f m =>
      cases s <;> cases f <;> cases m <;>
        simp_all [cost]

theorem optimalMask_adequate :
    AdequateFor (policy optimalMask) demandedEquivalent := by
  exact (adequate_iff optimalMask).mpr ⟨rfl, rfl⟩

theorem optimalMask_cost : cost optimalMask = 2 := rfl

theorem optimalMask_is_minimum (mask : Mask)
    (adequate : AdequateFor (policy mask) demandedEquivalent) :
    cost optimalMask ≤ cost mask := by
  rw [optimalMask_cost]
  exact adequate_cost_lower_bound mask adequate

theorem world_cardinality : Fintype.card World = 8 := by decide
theorem policy_cardinality : Fintype.card Mask = 8 := by decide

end Reversibility.Finite
