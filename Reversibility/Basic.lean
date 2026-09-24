import Mathlib.Data.Finset.Basic

namespace Reversibility

/-!
# Audited reversibility on a declared observation surface

The paper's contextual equivalence is defined through operations at observable keys.
`ObservationPolicy` below is a *chosen engineering observation*, not an identification
with that contextual equivalence. The observer must obtain its snapshots independently
of the component's disposer and journal.
-/

/-!
## 论文里的位置（arXiv:2608.25512v1；逐字引文见 `CORRESPONDENCE.md`）

* **§3.1.1**：逆是**单侧**的 —— 「what an inverse is held to is `g ∘ f` and never `f ∘ g`」。
* **§3.1.2 Definition 8**：见证只要求逆**在施加它的那个状态上**回得去
  （「the inverse is required to revert the effect only at the state where it was applied」）。
  所以「逐次运行、逐状态」是原文的形状，不是这里加的强条件。
* **§3.3.2 Definition 31 / 33**：论文的观察等价由「某个 key 上的有限操作测试」生成。
  **本文件的 `Equivalent` 不是那个等价**：它是所声明的 `observe` 诱导的等价（`Setoid.ker`）。
  两者之间要换，需要一个**显式前提** —— 就是下面的 `AdequateFor`；没有它不能互推。
* **§5.1.1**：inverse 见证的正确性在论文里是组件作者的义务，运行时**不核对**
  （「an obligation on the component author rather than a property the runtime verifies」）。
  `classify` 与三项核对不是替作者去证逆成立，而是把这句话变成**可执行的判决**。
-/

/-- A published policy decides which differences matter. -/
structure ObservationPolicy (State Observation Effect : Type*) where
  observe : State → Observation
  visibleEffects : Observation → Finset Effect

/-- Equality in the quotient induced by this particular observation policy. -/
def Equivalent {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect) (a b : State) : Prop :=
  policy.observe a = policy.observe b

theorem equivalent_refl {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect) (a : State) :
    Equivalent policy a a := rfl

theorem equivalent_symm {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect) {a b : State}
    (h : Equivalent policy a b) : Equivalent policy b a := h.symm

theorem equivalent_trans {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect) {a b c : State}
    (hab : Equivalent policy a b) (hbc : Equivalent policy b c) :
    Equivalent policy a c := hab.trans hbc

/-- The quotient named in the handoff is formed from the declared policy, not from an
unqualified equality of physical states. -/
def policySetoid {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect) : Setoid State where
  r := Equivalent policy
  iseqv := ⟨equivalent_refl policy, equivalent_symm policy, equivalent_trans policy⟩

/-- The finer observer distinguishes at least as many states as the coarser one. -/
def Refines {State FineObservation CoarseObservation FineEffect CoarseEffect : Type*}
    (fine : ObservationPolicy State FineObservation FineEffect)
    (coarse : ObservationPolicy State CoarseObservation CoarseEffect) : Prop :=
  ∀ a b, Equivalent fine a b → Equivalent coarse a b

/-- A factorization of observations gives a certified direction of transport. -/
theorem refines_of_factor
    {State FineObservation CoarseObservation FineEffect CoarseEffect : Type*}
    (fine : ObservationPolicy State FineObservation FineEffect)
    (coarse : ObservationPolicy State CoarseObservation CoarseEffect)
    (factor : FineObservation → CoarseObservation)
    (commutes : ∀ state, coarse.observe state = factor (fine.observe state)) :
    Refines fine coarse := by
  intro a b sameFine
  unfold Equivalent at *
  rw [commutes a, commutes b, sameFine]

/-- An engineering observation proves a stronger external equivalence only through an
explicit adequacy bridge. No such bridge is assumed for the paper's contextual relation. -/
def AdequateFor {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect)
    (targetEquivalence : State → State → Prop) : Prop :=
  ∀ a b, Equivalent policy a b → targetEquivalence a b

theorem transport_to_target_equivalence {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect)
    (targetEquivalence : State → State → Prop)
    (adequate : AdequateFor policy targetEquivalence)
    {a b : State} (sameObservation : Equivalent policy a b) :
    targetEquivalence a b := adequate a b sameObservation

/-- One load/unload run. The first and last snapshots belong to an external observer;
`registered` and `reportedRemoved` are claims made by the runtime/disposer. -/
structure Run (State Effect : Type*) where
  before : State
  loaded : State
  after : State
  registered : Finset Effect
  reportedRemoved : Finset Effect

/-- The journal must name precisely the newly visible effects of loading. -/
def LoadJournalMatches {State Observation Effect : Type*} [DecidableEq Effect]
    (policy : ObservationPolicy State Observation Effect) (run : Run State Effect) : Prop :=
  run.registered = policy.visibleEffects (policy.observe run.loaded) \
    policy.visibleEffects (policy.observe run.before)

/-- The disposer report is compared with an independently observed removal delta. -/
def RemovalReportMatches {State Observation Effect : Type*} [DecidableEq Effect]
    (policy : ObservationPolicy State Observation Effect) (run : Run State Effect) : Prop :=
  run.reportedRemoved = policy.visibleEffects (policy.observe run.loaded) \
    policy.visibleEffects (policy.observe run.after)

/-- Three separately checked obligations. An unchanged visible-effects set alone is not
enough: other published fields of `Observation` also have to be restored. -/
def Verified {State Observation Effect : Type*} [DecidableEq Effect]
    (policy : ObservationPolicy State Observation Effect) (run : Run State Effect) : Prop :=
  LoadJournalMatches policy run ∧
  RemovalReportMatches policy run ∧
  Equivalent policy run.after run.before

theorem verified_round_trip {State Observation Effect : Type*} [DecidableEq Effect]
    (policy : ObservationPolicy State Observation Effect) (run : Run State Effect)
    (h : Verified policy run) : Equivalent policy run.after run.before := h.2.2

/-- A checked run under a finer observer is a round trip under any explicitly
factored coarser observer. The converse needs reflection and is not automatic. -/
theorem verified_transports_to_coarser_observation
    {State FineObservation CoarseObservation FineEffect CoarseEffect : Type*}
    [DecidableEq FineEffect]
    (fine : ObservationPolicy State FineObservation FineEffect)
    (coarse : ObservationPolicy State CoarseObservation CoarseEffect)
    (refines : Refines fine coarse) (run : Run State FineEffect)
    (verified : Verified fine run) : Equivalent coarse run.after run.before :=
  refines _ _ (verified_round_trip fine run verified)

theorem verified_report_cancels_journal {State Observation Effect : Type*}
    [DecidableEq Effect] (policy : ObservationPolicy State Observation Effect)
    (run : Run State Effect) (h : Verified policy run) :
    run.reportedRemoved = run.registered := by
  calc
    run.reportedRemoved = policy.visibleEffects (policy.observe run.loaded) \
        policy.visibleEffects (policy.observe run.after) := h.2.1
    _ = policy.visibleEffects (policy.observe run.loaded) \
        policy.visibleEffects (policy.observe run.before) := by rw [h.2.2]
    _ = run.registered := h.1.symm

/-- If every load/unload state has independently checked witnesses, the composition
acts as the identity on the policy quotient, pointwise. -/
theorem audited_composition_is_quotient_identity {State Observation Effect : Type*}
    [DecidableEq Effect] (policy : ObservationPolicy State Observation Effect)
    (load unload : State → State) (registered reportedRemoved : State → Finset Effect)
    (allChecked : ∀ state, Verified policy
      ⟨state, load state, unload (load state), registered state, reportedRemoved state⟩)
    (state : State) :
    Quotient.mk (policySetoid policy) (unload (load state)) =
      Quotient.mk (policySetoid policy) state := by
  exact Quotient.sound (verified_round_trip policy _ (allChecked state))

/-- A named declaration is a disclosure, not a proof of irreversibility. -/
inductive Verdict where
  | verifiedReversible
  | declaredIrreversible (description : String)
  | unknown (reason : String)
  deriving Repr, DecidableEq

def namedDeclaration (description : String) : Verdict :=
  if description.isEmpty then .unknown "empty irreversibility declaration"
  else .declaredIrreversible description

/-- Fail closed on a bad journal or disposer report, even when the component declares an
external effect. Lack of an observer never yields a verified verdict. -/
def classify {State Observation Effect : Type*} [DecidableEq Effect]
    [DecidableEq Observation]
    (observer : Option (ObservationPolicy State Observation Effect))
    (run : Run State Effect) (declaration : Option String) : Verdict :=
  match observer with
  | none =>
      match declaration with
      | some description => namedDeclaration description
      | none => .unknown "no external observer"
  | some policy =>
      if run.registered = policy.visibleEffects (policy.observe run.loaded) \
          policy.visibleEffects (policy.observe run.before) then
        if run.reportedRemoved = policy.visibleEffects (policy.observe run.loaded) \
            policy.visibleEffects (policy.observe run.after) then
          if policy.observe run.after = policy.observe run.before then
            match declaration with
            | some description => namedDeclaration description
            | none => .verifiedReversible
          else
            match declaration with
            | some description => namedDeclaration description
            | none => .unknown "observable residual after unload"
        else
          .unknown "disposer report differs from observed removals"
      else
        .unknown "load journal differs from observed additions"

theorem classify_verified_sound {State Observation Effect : Type*} [DecidableEq Effect]
    [DecidableEq Observation]
    (policy : ObservationPolicy State Observation Effect) (run : Run State Effect)
    (declaration : Option String)
    (h : classify (some policy) run declaration = .verifiedReversible) :
    Verified policy run := by
  by_cases hj : run.registered = policy.visibleEffects (policy.observe run.loaded) \
      policy.visibleEffects (policy.observe run.before)
  · by_cases hr : run.reportedRemoved = policy.visibleEffects (policy.observe run.loaded) \
        policy.visibleEffects (policy.observe run.after)
    · by_cases he : policy.observe run.after = policy.observe run.before
      · exact ⟨hj, hr, he⟩
      · cases declaration with
        | none => simp [classify, hj, hr, he] at h
        | some description =>
          by_cases hd : description.isEmpty
          · simp [classify, namedDeclaration, hj, hr, he, hd] at h
          · simp [classify, namedDeclaration, hj, hr, he, hd] at h
    · simp [classify, hj, hr] at h
  · simp [classify, hj] at h

/-- The audit result is deliberately about snapshots supplied by the external observer.
It does not establish that an untrusted adapter captured the physical world faithfully. -/
theorem verified_is_policy_relative {State Observation Effect : Type*} [DecidableEq Effect]
    [DecidableEq Observation]
    (policy : ObservationPolicy State Observation Effect) (run : Run State Effect)
    (declaration : Option String)
    (h : classify (some policy) run declaration = .verifiedReversible) :
    policy.observe run.after = policy.observe run.before :=
  (classify_verified_sound policy run declaration h).2.2

end Reversibility
