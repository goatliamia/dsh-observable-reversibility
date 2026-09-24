import Reversibility.Basic
import Mathlib.Data.Setoid.Basic
import Mathlib.Logic.Function.Basic
import Mathlib.Order.Closure

namespace Reversibility

/-!
The mathematical core of an observed load/unload cycle is a retraction on the
reachable observation space. This is stronger structure than a single successful
runtime check, and it requires explicit commutation of physical transitions with
the observation map.
-/

/-!
## 主定理与它在论文里的位置

    若 q ∘ L = Lₒ ∘ q 且 q ∘ U = Uₒ ∘ q，则
        (∀ s, q (U (L s)) = q s)  ↔  (∀ o ∈ range q, Uₒ (Lₒ o) = o)

* **商那一端**：`policySetoid = Setoid.ker q`，于是 `S / ~q ≃ range q`
  （Mathlib `Setoid.quotientKerEquivRange`）。右边「在可达值域上逐点」不是取巧，
  它就是商空间上的逐点恒等。
* **论文里的位置**：**§3.3.2** 自己说 §3.1 的恢复等式是 idealization、只能读到 `≃`
  （「The recovery guarantee of Section 3.1 asserts an equality of states (Theorem 7),
  which is an idealization」）；**§4.3.2** 给出那个界（「a message already sent stays sent」）。
  本文补的是它缺的那一步：**在什么条件下，逐次运行的核对确实等于商空间上的恒等。**
* **前提不是免费的**：两个交换方块是「观察面之外没有未被命名的写」的数学写法
  （论文 §6.1：界外的操作 `acts as idΓ`，既不追踪也不撤销）。
  前提守不住时，正确动作是**把差异命名**（`Reversibility.Basic` 的三态判决），
  而不是继续声称等号。
-/

/-- The observation policy's equivalence relation is exactly the kernel setoid
of its observation function. -/
theorem policySetoid_eq_ker {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect) :
    policySetoid policy = Setoid.ker policy.observe := by
  ext a b
  rfl

/-- Mathlib's first isomorphism theorem for sets identifies our quotient with
the *reachable* observations, not with all possible values of `Observation`. -/
noncomputable def quotientEquivObservedRange {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect) :
    Quotient (policySetoid policy) ≃ Set.range policy.observe := by
  rw [policySetoid_eq_ker]
  exact Setoid.quotientKerEquivRange policy.observe

/-- Whether load/unload is the identity after observation can be checked on each
reachable observation, provided both transitions commute with observation. -/
theorem roundTrip_iff_leftInverseOnRange
    {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect)
    (load unload : State → State) (loadObs unloadObs : Observation → Observation)
    (loadCommutes : ∀ state, policy.observe (load state) = loadObs (policy.observe state))
    (unloadCommutes : ∀ state, policy.observe (unload state) = unloadObs (policy.observe state)) :
    (∀ state, Equivalent policy (unload (load state)) state) ↔
      (∀ observation ∈ Set.range policy.observe,
        unloadObs (loadObs observation) = observation) := by
  constructor
  · rintro roundTrip observation ⟨state, rfl⟩
    calc
      unloadObs (loadObs (policy.observe state)) =
          unloadObs (policy.observe (load state)) := by rw [loadCommutes]
      _ = policy.observe (unload (load state)) := (unloadCommutes _).symm
      _ = policy.observe state := roundTrip state
  · intro leftInverseOnRange state
    unfold Equivalent
    calc
      policy.observe (unload (load state)) =
          unloadObs (policy.observe (load state)) := unloadCommutes _
      _ = unloadObs (loadObs (policy.observe state)) := by rw [loadCommutes]
      _ = policy.observe state := leftInverseOnRange _ ⟨state, rfl⟩

/-- If every observation value is reachable, the restricted inverse becomes an
ordinary Mathlib `Function.LeftInverse`. -/
theorem observed_leftInverse_of_surjective
    {State Observation Effect : Type*}
    (policy : ObservationPolicy State Observation Effect)
    (load unload : State → State) (loadObs unloadObs : Observation → Observation)
    (loadCommutes : ∀ state, policy.observe (load state) = loadObs (policy.observe state))
    (unloadCommutes : ∀ state, policy.observe (unload state) = unloadObs (policy.observe state))
    (observationSurjective : Function.Surjective policy.observe)
    (roundTrip : ∀ state, Equivalent policy (unload (load state)) state) :
    Function.LeftInverse unloadObs loadObs := by
  intro observation
  exact (roundTrip_iff_leftInverseOnRange policy load unload loadObs unloadObs
    loadCommutes unloadCommutes).mp roundTrip observation (observationSurjective observation)

/-- A retraction gives an injective load map and a surjective unload map. -/
theorem retract_injective_and_surjective {Before Loaded : Type*}
    (load : Before → Loaded) (unload : Loaded → Before)
    (h : Function.LeftInverse unload load) :
    Function.Injective load ∧ Function.Surjective unload :=
  ⟨h.injective, h.surjective⟩

/-- The opposite composite is an idempotent projection onto recoverable loaded states. -/
theorem load_unload_projection_idempotent {Before Loaded : Type*}
    (load : Before → Loaded) (unload : Loaded → Before)
    (h : Function.LeftInverse unload load) (loaded : Loaded) :
    load (unload (load (unload loaded))) = load (unload loaded) := by
  rw [h (unload loaded)]

theorem projection_fixed_iff_in_load_range {Before Loaded : Type*}
    (load : Before → Loaded) (unload : Loaded → Before)
    (h : Function.LeftInverse unload load) (loaded : Loaded) :
    load (unload loaded) = loaded ↔ loaded ∈ Set.range load := by
  constructor
  · intro fixed
    exact ⟨unload loaded, fixed⟩
  · rintro ⟨before, rfl⟩
    rw [h before]

/-- Mathlib's inverse-composition theorem captures stack-order unloading. -/
theorem stacked_round_trip {State : Type*}
    (loadA unloadA loadB unloadB : State → State)
    (hA : Function.LeftInverse unloadA loadA)
    (hB : Function.LeftInverse unloadB loadB) :
    Function.LeftInverse (unloadA ∘ unloadB) (loadB ∘ loadA) :=
  hB.comp hA

/-- Idempotence alone does not make a closure operator. Monotonicity and
extensivity have to be supplied separately. -/
def projectionClosure {Before Loaded : Type*} [Preorder Loaded]
    (load : Before → Loaded) (unload : Loaded → Before)
    (h : Function.LeftInverse unload load)
    (monotone : Monotone (load ∘ unload))
    (extensive : ∀ loaded, loaded ≤ load (unload loaded)) :
    ClosureOperator Loaded where
  toFun := load ∘ unload
  monotone' := monotone
  le_closure' := extensive
  idempotent' := load_unload_projection_idempotent load unload h

/-- Under the additional order laws, the closed loaded states are exactly
those in the image of `load`. -/
theorem projectionClosure_closed_iff_range {Before Loaded : Type*} [Preorder Loaded]
    (load : Before → Loaded) (unload : Loaded → Before)
    (h : Function.LeftInverse unload load)
    (monotone : Monotone (load ∘ unload))
    (extensive : ∀ loaded, loaded ≤ load (unload loaded))
    (loaded : Loaded) :
    (projectionClosure load unload h monotone extensive).IsClosed loaded ↔
      loaded ∈ Set.range load := by
  rw [(projectionClosure load unload h monotone extensive).isClosed_iff]
  exact projection_fixed_iff_in_load_range load unload h loaded

/-- Mathlib upgrades a genuine closure operator to a Galois insertion of its
closed states. This upgrade is conditional on monotonicity and extensivity. -/
def projectionClosure_galoisInsertion {Before Loaded : Type*}
    [PartialOrder Loaded]
    (load : Before → Loaded) (unload : Loaded → Before)
    (h : Function.LeftInverse unload load)
    (monotone : Monotone (load ∘ unload))
    (extensive : ∀ loaded, loaded ≤ load (unload loaded)) :
    GaloisInsertion
      (projectionClosure load unload h monotone extensive).toCloseds (↑) :=
  (projectionClosure load unload h monotone extensive).gi

end Reversibility
