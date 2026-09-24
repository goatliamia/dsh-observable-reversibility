import Reversibility.Structure

/-!
# 对外的那条陈述，钉在这里

本文件只写**一般形式**：状态空间 `S`、观察 `q`、装载 `L`、卸载 `U`，
以及那条等价和它的推论。不含任何具体系统的构造，也不含任何工程政策。

它同时是一道**漂移守卫**：下面这些 `example` 把主定理与各条推论的语句形状钉死 ——
谁把语句改弱了，构建当场失败，而不是让结论悄悄漂走。
-/

namespace Reversibility

variable {S O A B : Type*}

/-! ## 一般形式（不经过 `ObservationPolicy` 这层包装） -/

/-- `q ∘ L = Lₒ ∘ q` 且 `q ∘ U = Uₒ ∘ q` 时，
逐状态的往返等价于观察层在**可达**值域上的左逆。 -/
theorem roundTrip_iff_leftInverseOnRange_comp
    (q : S → O) (L U : S → S) (Lₒ Uₒ : O → O)
    (hL : ∀ s, q (L s) = Lₒ (q s)) (hU : ∀ s, q (U s) = Uₒ (q s)) :
    (∀ s, q (U (L s)) = q s) ↔ (∀ o ∈ Set.range q, Uₒ (Lₒ o) = o) := by
  let policy : ObservationPolicy S O Unit := { observe := q, visibleEffects := fun _ => ∅ }
  have h := roundTrip_iff_leftInverseOnRange policy L U Lₒ Uₒ hL hU
  simpa [policy, Equivalent] using h

/-- 观察 `q` 满射时，「可达值域上的左逆」就是普通的 `Function.LeftInverse`。 -/
theorem leftInverse_of_surjective
    (q : S → O) (L U : S → S) (Lₒ Uₒ : O → O)
    (hL : ∀ s, q (L s) = Lₒ (q s)) (hU : ∀ s, q (U s) = Uₒ (q s))
    (hsurj : Function.Surjective q) (hrt : ∀ s, q (U (L s)) = q s) :
    Function.LeftInverse Uₒ Lₒ := by
  intro o
  obtain ⟨s, rfl⟩ := hsurj o
  have h := (roundTrip_iff_leftInverseOnRange_comp q L U Lₒ Uₒ hL hU).mp hrt
  exact h (q s) ⟨s, rfl⟩

/-! ## 漂移守卫：主定理的语句形状 -/

example (policy : ObservationPolicy S O Unit) (L U : S → S) (Lₒ Uₒ : O → O)
    (hL : ∀ s, policy.observe (L s) = Lₒ (policy.observe s))
    (hU : ∀ s, policy.observe (U s) = Uₒ (policy.observe s)) :
    (∀ s, Equivalent policy (U (L s)) s) ↔
      (∀ o ∈ Set.range policy.observe, Uₒ (Lₒ o) = o) :=
  roundTrip_iff_leftInverseOnRange policy L U Lₒ Uₒ hL hU

example (q : S → O) (L U : S → S) (Lₒ Uₒ : O → O)
    (hL : ∀ s, q (L s) = Lₒ (q s)) (hU : ∀ s, q (U s) = Uₒ (q s)) :
    (∀ s, q (U (L s)) = q s) ↔ (∀ o ∈ Set.range q, Uₒ (Lₒ o) = o) :=
  roundTrip_iff_leftInverseOnRange_comp q L U Lₒ Uₒ hL hU

/-! ## 漂移守卫：推论

注意三条**推论都只在 `range q` 之内**说 —— 对整个 `O` 说「`Lₒ` 单射」是假的。 -/

/-- 退缩给出：装载单射、卸载满射（都在观察层那一段上）。 -/
example (load : A → B) (unload : B → A) (h : Function.LeftInverse unload load) :
    Function.Injective load ∧ Function.Surjective unload :=
  retract_injective_and_surjective load unload h

/-- 反向复合是幂等投影。 -/
example (load : A → B) (unload : B → A) (h : Function.LeftInverse unload load) (b : B) :
    load (unload (load (unload b))) = load (unload b) :=
  load_unload_projection_idempotent load unload h b

/-- 它的不动点恰好是装载像。 -/
example (load : A → B) (unload : B → A) (h : Function.LeftInverse unload load) (b : B) :
    load (unload b) = b ↔ b ∈ Set.range load :=
  projection_fixed_iff_in_load_range load unload h b

/-- 两个组件必须**反序**卸载。 -/
example (lA uA lB uB : S → S)
    (hA : Function.LeftInverse uA lA) (hB : Function.LeftInverse uB lB) :
    Function.LeftInverse (uA ∘ uB) (lB ∘ lA) :=
  stacked_round_trip lA uA lB uB hA hB

/-- 幂等**不是**闭包：还要 `Monotone` 与扩张性，才接得上 `ClosureOperator`。 -/
example [Preorder B] (load : A → B) (unload : B → A) (h : Function.LeftInverse unload load)
    (mono : Monotone (load ∘ unload)) (ext : ∀ b, b ≤ load (unload b)) :
    (projectionClosure load unload h mono ext).IsClosed b ↔ b ∈ Set.range load :=
  projectionClosure_closed_iff_range load unload h mono ext b

/-! ## 漂移守卫：那道桥是**前提**，不是结论 -/

example (policy : ObservationPolicy S O Unit) (target : S → S → Prop)
    (adequate : AdequateFor policy target) {a b : S} (same : Equivalent policy a b) :
    target a b :=
  transport_to_target_equivalence policy target adequate same

/-- 判决可靠：`verified-reversible` 只能从三项核对里来。 -/
example [DecidableEq O] (policy : ObservationPolicy S O Unit) (run : Run S Unit)
    (decl : Option String) (h : classify (some policy) run decl = .verifiedReversible) :
    Equivalent policy run.after run.before :=
  verified_round_trip policy run (classify_verified_sound policy run decl h)

end Reversibility
