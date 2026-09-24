import Reversibility.Structure
import Mathlib.Data.Fintype.Fin
import Mathlib.Tactic.FinCases
import Mathlib.Tactic.NormNum

namespace Reversibility.StructureExamples

open Reversibility

open Reversibility

/-!
## 边界的反例

* 两个组件各自可逆，**按同一顺序卸载**并不撤销它们的复合（`Fin 3` 上给出）。
  正确的顺序是反序，见 `Reversibility.stacked_round_trip`。
* 幂等**不等于**闭包：`reset` 幂等但不扩张，所以 `projectionClosure` 的
  `Monotone` 与扩张性两条前提一条也不能省。
* 在**可达**观察上成立的左逆，不能推广到不可达的值（观察层那一格）。
-/

def swap01 (x : Fin 3) : Fin 3 :=
  if x = 0 then 1 else if x = 1 then 0 else 2

def swap12 (x : Fin 3) : Fin 3 :=
  if x = 1 then 2 else if x = 2 then 1 else 0

theorem swap01_self_inverse : Function.LeftInverse swap01 swap01 := by
  change ∀ x : Fin 3, swap01 (swap01 x) = x
  intro x
  fin_cases x <;> decide
theorem swap12_self_inverse : Function.LeftInverse swap12 swap12 := by
  change ∀ x : Fin 3, swap12 (swap12 x) = x
  intro x
  fin_cases x <;> decide

example : Function.LeftInverse (swap01 ∘ swap12) (swap12 ∘ swap01) :=
  stacked_round_trip swap01 swap01 swap12 swap12
    swap01_self_inverse swap12_self_inverse

/-- Both components are individually reversible, but unloading in the same order
does not undo their composite. -/
example : ¬Function.LeftInverse (swap12 ∘ swap01) (swap12 ∘ swap01) := by
  intro h
  have atZero := h (0 : Fin 3)
  norm_num [Function.comp_def, swap01, swap12] at atZero

def boolObservation : ObservationPolicy Bool Nat Unit where
  observe := fun b => if b then 1 else 0
  visibleEffects := fun _ => ∅

def observationUnload (n : Nat) : Nat := if n = 2 then 0 else n

example : ∀ b : Bool, Equivalent boolObservation (id (id b)) b := by
  intro b
  rfl

/-- A proof on reachable observations 0 and 1 cannot be generalized to 2. -/
example : ¬Function.LeftInverse observationUnload (id : Nat → Nat) := by
  intro h
  have atTwo := h 2
  simp [observationUnload] at atTwo

def reset (_n : Nat) : Nat := 0

example (_n : Nat) : reset (reset _n) = reset _n := rfl
example : ¬∀ n : Nat, n ≤ reset n := by
  intro extensive
  have atOne := extensive 1
  simp [reset] at atOne

end Reversibility.StructureExamples
