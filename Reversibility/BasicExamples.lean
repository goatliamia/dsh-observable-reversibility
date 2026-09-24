import Reversibility.Basic

namespace Reversibility.BasicExamples

open Reversibility

open Reversibility

/-!
## 三态判决的正反试件

| 情形 | 判决 |
|---|---|
| 三项核对都对上 | `verified-reversible` |
| disposer 说撤了、观察说没撤 | `unknown` |
| 有未登记的写（装载记录对不上） | `unknown` |
| 卸载后还剩可见残留 | `unknown` |
| 作者**具名**声明界外写 | `declared-irreversible` |
| 声明是空串 / 没有外部观察器 | `unknown` |

`sentMessage` 是这里的关键一格：它**同时**满足 `Equivalent`（观察上回得来）
且 `≠`（物理状态没回来）—— 「恢复到 `≃`，不是全等」的机器可读版本。
-/

/-- In this declared world, service entries and profile files are visible. Sent messages
and the clock are deliberately outside the quotient. -/
structure World where
  visible : Finset String
  sentMessages : Nat
  clock : Nat
  deriving DecidableEq

def policy : ObservationPolicy World (Finset String) String where
  observe := World.visible
  visibleEffects := id

def coarsePolicy : ObservationPolicy World Unit String where
  observe := fun _ => ()
  visibleEffects := fun _ => ∅

example : Refines policy coarsePolicy :=
  refines_of_factor policy coarsePolicy (fun _ => ()) (by intro; rfl)

def empty : World := ⟨∅, 0, 0⟩
def service : World := ⟨{"service:cache"}, 0, 1⟩
def file : World := ⟨{"file:profile/config"}, 0, 2⟩
def serviceAndFile : World := ⟨{"service:cache", "file:profile/config"}, 0, 2⟩

def honest : Run World String where
  before := empty
  loaded := service
  after := empty
  registered := {"service:cache"}
  reportedRemoved := {"service:cache"}

def lyingDisposer : Run World String :=
  { honest with after := service }

def unregisteredWrite : Run World String :=
  { honest with loaded := serviceAndFile, after := file }

def residualFile : Run World String :=
  { honest with after := file }

def sentMessage : Run World String :=
  { honest with after := ⟨∅, 1, 3⟩ }

example : classify (some policy) honest none = .verifiedReversible := by decide
example : classify (some policy) lyingDisposer none =
    .unknown "disposer report differs from observed removals" := by decide
example : classify (some policy) unregisteredWrite none =
    .unknown "load journal differs from observed additions" := by decide
example : classify (some policy) residualFile none =
    .unknown "observable residual after unload" := by decide
example : classify (some policy) sentMessage (some "message sent to external recipient") =
    .declaredIrreversible "message sent to external recipient" := by decide
example : classify (some policy) sentMessage (some "") =
    .unknown "empty irreversibility declaration" := by decide
example : classify (none : Option (ObservationPolicy World (Finset String) String))
    honest none = .unknown "no external observer" := by decide

/-- This non-identity witness makes the declared quotient's scope explicit. -/
example : Equivalent policy sentMessage.after sentMessage.before := by
  unfold Equivalent
  decide
example : sentMessage.after ≠ sentMessage.before := by decide

example : Equivalent coarsePolicy empty service := by
  unfold Equivalent
  rfl
example : ¬Equivalent policy empty service := by
  unfold Equivalent
  decide

example (run : Run World String) (declaration : Option String)
    (h : classify (some policy) run declaration = .verifiedReversible) :
    Equivalent policy run.after run.before :=
  verified_round_trip policy run (classify_verified_sound policy run declaration h)

end Reversibility.BasicExamples
