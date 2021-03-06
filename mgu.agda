module mgu where

open import nat
open import inject
open import desc

open import Data.Unit using (⊤; tt)
open import Data.Nat hiding (fold)
open import Data.Nat.Properties
open import Data.Nat.Properties.Simple
open import Data.Fin hiding (_+_; _≤_; fold)
open import Data.Sum
open import Data.Product
open import Data.Maybe
open import Function using (_∘_)
open import Relation.Binary.PropositionalEquality
open ≡-Reasoning

---------------------------------------------------------------

-- functional extensionality
postulate
  ext : forall {A B : Set} {f g : A -> B} -> (∀ (a : A) -> f a ≡ g a) -> f ≡ g

---------------------------------------------------------------

-- thin x y = y     (if y < x)
--          = suc y (if y >= x)
-- thin x y will never be x.
thin : {m : ℕ} → Fin (suc m) → Fin m → Fin (suc m)
thin {m} zero y = suc y
thin {suc m} (suc x) zero = zero
thin {suc m} (suc x) (suc y) = suc (thin x y)

-- thick x y = just y       (if y < x)
--           = nothing      (if y = x)
--           = just (y - 1) (if y > x)
thick : {m : ℕ} → (x y : Fin (suc m)) → Maybe (Fin m)
thick {m} zero zero = nothing -- x = y だった
thick {m} zero (suc y) = just y -- 濃縮する
thick {zero} (suc ()) zero
thick {suc m} (suc x) zero = just zero -- x 未満なのでそのまま
thick {zero} (suc ()) (suc y)
thick {suc m} (suc x) (suc y) with thick {m} x y
... | just x' = just (suc x')
... | nothing = nothing -- x = y だった

-- thick x x は必ず nothing になる
thickxx≡nothing : ∀ {m : ℕ} (x : Fin (suc m)) → thick x x ≡ nothing
thickxx≡nothing zero = refl
thickxx≡nothing {zero} (suc ())
thickxx≡nothing {suc m} (suc x) with thickxx≡nothing x
... | a rewrite a = refl

-- thick x y が nothing になったら x ≡ y
thickxy-x≡y : ∀ {m : ℕ} (x y : Fin (suc m)) → thick x y ≡ nothing → x ≡ y
thickxy-x≡y zero zero eq = refl
thickxy-x≡y zero (suc y) ()
thickxy-x≡y {zero} (suc ()) zero eq
thickxy-x≡y {suc m} (suc x) zero ()
thickxy-x≡y {zero} (suc ()) (suc y) eq
thickxy-x≡y {suc m} (suc x) (suc y) eq with thick x y | inspect (thick x) y
thickxy-x≡y {suc m} (suc x) (suc y) () | just x' | [ eq' ]
... | nothing | [ eq' ] = cong suc (thickxy-x≡y x y eq')

thickxynothing : {m : ℕ} → {x y : Fin (suc m)} →
        thick x y ≡ nothing → thick (inject₁ x) (inject₁ y) ≡ nothing
thickxynothing {x = zero} {zero} eq = refl
thickxynothing {x = zero} {suc y} ()
thickxynothing {zero} {suc ()} eq
thickxynothing {suc m} {suc x} {zero} ()
thickxynothing {suc m} {suc x} {suc y} eq with thick x y | inspect (thick x) y
thickxynothing {suc m} {suc x} {suc y} refl | nothing | [ eq2 ] rewrite eq2
  with thickxynothing {x = x} eq2
... | eq3 rewrite eq3 = refl
thickxynothing {suc m} {suc x} {suc y} () | just y' | [ _ ]

thickxyjust : {m : ℕ} → {x y : Fin (suc m)} → {y' : Fin m} →
        thick x y ≡ just y' → thick (inject₁ x) (inject₁ y) ≡ just (inject₁ y')
thickxyjust {x = zero} {zero} ()
thickxyjust {x = zero} {suc y} refl = refl
thickxyjust {zero} {suc x} {y} {()} eq
thickxyjust {suc m} {suc x} {zero} refl = refl
thickxyjust {suc m} {suc x} {suc y} eq with thick x y | inspect (thick x) y
thickxyjust {suc m} {suc x} {suc y} () | nothing | _
thickxyjust {suc m} {suc x} {suc y} refl | just y' | [ eq ] rewrite eq
  with thickxyjust {x = x} eq
... | eq2 rewrite eq2 = refl

private
  check-M : {D : Desc} → {m : ℕ} → Fin (suc m) → Fin (suc m) → Maybe (Fix D m)
  check-M x y with thick x y
  ... | just y' = just (M y')
  ... | nothing = nothing -- x が現れた（x = y だった）

  check-F' : {D D' : Desc} → {m : ℕ} → Fin (suc m) →
           ⟦ D ⟧ (Maybe (Fix D' m)) → Maybe (⟦ D ⟧ (Fix D' m))
  check-F' {base} x tt = just tt
  check-F' {D1 :+: D2} x (inj₁ t) with check-F' {D1} x t
  ... | nothing = nothing
  ... | just t' = just (inj₁ t')
  check-F' {D1 :+: D2} x (inj₂ t) with check-F' {D2} x t
  ... | nothing = nothing
  ... | just t' = just (inj₂ t')
  check-F' {D1 :*: D2} x (t1 , t2) with check-F' {D1} x t1
  ... | nothing = nothing
  ... | just t1' with check-F' {D2} x t2
  ... | nothing = nothing
  ... | just t2' = just (t1' , t2')
  check-F' {rec} x t = t

  check-F : {D : Desc} → {m : ℕ} → Fin (suc m) →
          ⟦ D ⟧ (Maybe (Fix D m)) → Maybe (Fix D m)
  check-F {D} x t with check-F' {D} x t
  ... | nothing = nothing
  ... | just t' = just (F t')

{-
D = base :+: rec なら、
[D](Maybe (Fix D m)) = Unit + (Maybe (Fix D m))
Unit + (Maybe (F ([D] (Fix D m))))

D = base :+: rec :*: rec なら、
[D](Maybe (Fix D m)) = Unit + (Maybe (Fix D m)) * (Maybe (Fix D m))

Unit + (Maybe (F ([D] (Fix D m)))) * (Maybe (F ([D] (Fix D m))))

Fix D m = F (t : [D](Fix D m)) or M y

[D](Maybe ([D] (Fix D' m))) =
  Unit + (Maybe ([D] (Fix D' m))) * (Maybe ([D] (Fix D' m)))
-}

-- check x t : x 番の型変数が型 t の中に現れるかをチェックする。
-- 現れなければ、型 t を x で thick できるはずなので、それを返す。
-- 現れたら、nothing を返す。
check : {D : Desc} → {m : ℕ} → Fin (suc m) → Fix D (suc m) → Maybe (Fix D m)
check {D} {m} x t = fold (check-F x)
                         (check-M {D} x)
                         t

private
  checkInv-F' : {D D' : Desc} → {m : ℕ} → (x : Fin (suc m)) → (d : ⟦ D ⟧ (Fix D' (suc m))) →
           (Σ[ d' ∈ ⟦ D ⟧ (Fix D' m) ]
            check-F' {D} {D'} x (fmap D (check x) d) ≡ just d') ⊎
           (check-F' {D} {D'} x (fmap D (check x) d) ≡ nothing)
  checkInv-F' {base} x d = inj₁ (tt , refl)
  checkInv-F' {D1 :+: D2} x (inj₁ d1) with checkInv-F' {D1} x d1
  ... | inj₁ (d1' , eq) rewrite eq = inj₁ (inj₁ d1' , refl)
  ... | inj₂ eq rewrite eq = inj₂ refl
  checkInv-F' {D1 :+: D2} x (inj₂ d2) with checkInv-F' {D2} x d2
  ... | inj₁ (d2' , eq) rewrite eq = inj₁ (inj₂ d2' , refl)
  ... | inj₂ eq rewrite eq = inj₂ refl
  checkInv-F' {D1 :*: D2} x (d1 , d2) with checkInv-F' {D1} x d1
  ... | inj₂ eq1 rewrite eq1 = inj₂ refl
  ... | inj₁ (d1' , eq1) rewrite eq1 with checkInv-F' {D2} x d2
  ... | inj₂ eq2 rewrite eq2 = inj₂ refl
  ... | inj₁ (d2' , eq2) rewrite eq2 = inj₁ ((d1' , d2') , refl)
  checkInv-F' {rec} x d with check x d | inspect (check x) d
  checkInv-F' {rec} x d | nothing | [ eq ] = inj₂ refl
  checkInv-F' {rec} x d | just d' | [ eq ] rewrite eq = inj₁ (d' , refl)

  checkInv-F : {D : Desc} → {m : ℕ} → (x : Fin (suc m)) → (d : ⟦ D ⟧ (Fix D (suc m))) →
           (r : ⟦ D ⟧' (λ (t : Fix D (suc m)) → {t' : Fix D m} →
                        check {D} x t ≡ just t' →
                        (Σ[ d2 ∈ ⟦ D ⟧ (Fix D (suc m)) ] Σ[ d' ∈ ⟦ D ⟧ (Fix D m) ]
                         (t ≡ F d2) × (t' ≡ F d') × (check-F {D} x (fmap D (check x) d2) ≡ just (F d'))) ⊎
                        (Σ[ y2 ∈ Fin (suc m) ] Σ[ y' ∈ Fin m ]
                         (t ≡ M y2) × (t' ≡ M y') × (thick x y2 ≡ just y'))) d) →
           {t' : Fix D m} →
           check {D} x (F d) ≡ just t' →
           (Σ[ d2 ∈ ⟦ D ⟧ (Fix D (suc m)) ] Σ[ d' ∈ ⟦ D ⟧ (Fix D m) ]
            (F {D = D} d ≡ F d2) × (t' ≡ F d') × (check-F {D} x (fmap D (check x) d2) ≡ just (F d'))) ⊎
           (Σ[ y2 ∈ Fin (suc m) ] Σ[ y' ∈ Fin m ]
            (F {D = D} d ≡ M y2) × (t' ≡ M y') × (thick x y2 ≡ just y'))
  checkInv-F {base} x tt tt refl = inj₁ (tt , tt , refl , refl , refl)
  checkInv-F {D1 :+: D2} x (inj₁ d1) r eq with check-F' {D1 :+: D2} x (inj₁ (fmap D1 (check x) d1))
                                    | inspect (check-F' {D1 :+: D2} x) (inj₁ (fmap D1 (check x) d1))
  checkInv-F {D1 :+: D2} x (inj₁ d1) r () | nothing | _
  checkInv-F {D1 :+: D2} x (inj₁ d1) r refl | just d' | [ eq2 ] rewrite eq2 =
    inj₁ (inj₁ d1 , d' , refl , refl , lem3 eq2)
    where lem3 : check-F' {D1 :+: D2} x (inj₁ (fmap D1 (check x) d1)) ≡ just d' →
                 check-F {D1 :+: D2} x (fmap (D1 :+: D2) (check x) (inj₁ d1)) ≡ just (F d')
              -- goal: check-F x (inj₁ (fmap D1 (check x) d1)) ≡ just (F d')
          lem3 eq rewrite eq = refl
  checkInv-F {D1 :+: D2} x (inj₂ d2) r eq with check-F' {D1 :+: D2} x (inj₂ (fmap D2 (check x) d2))
                                    | inspect (check-F' {D1 :+: D2} x) (inj₂ (fmap D2 (check x) d2))
  checkInv-F {D1 :+: D2} x (inj₂ d2) r () | nothing | _
  checkInv-F {D1 :+: D2} x (inj₂ d2) r refl | just d' | [ eq2 ] rewrite eq2 =
    inj₁ (inj₂ d2 , d' , refl , refl , lem4 eq2)
    where lem4 : check-F' {D1 :+: D2} x (inj₂ (fmap D2 (check x) d2)) ≡ just d' →
                 check-F {D1 :+: D2} x (fmap (D1 :+: D2) (check x) (inj₂ d2)) ≡ just (F d')
          lem4 eq rewrite eq = refl
  checkInv-F {D1 :*: D2} x (d1 , d2) (r1 , r2) eq
    with check {D1 :*: D2} x (F (d1 , d2)) | inspect (check {D1 :*: D2} x) (F (d1 , d2))
  checkInv-F {D1 :*: D2} x (d1 , d2) (r1 , r2) () | nothing | _
  checkInv-F {D1 :*: D2} x (d1 , d2) (r1 , r2) refl | just (F (d1' , d2')) | [ eq ] rewrite eq =
    inj₁ ((d1 , d2) , (d1' , d2') , refl , refl , eq)
  checkInv-F {D1 :*: D2} x (d1 , d2) (r1 , r2) refl | just (M y) | [ eq ] -- = {!!} -- rewrite eq = {!!}
    with check-F' {D1 :*: D2} x (fmap (D1 :*: D2) (check x) (d1 , d2))
  checkInv-F {D1 :*: D2} x (d1 , d2) (r1 , r2) refl | just (M y) | [ () ] | just x₁
  checkInv-F {D1 :*: D2} x (d1 , d2) (r1 , r2) refl | just (M y) | [ () ] | nothing
  checkInv-F {rec} x d r eq with check x d
  checkInv-F {rec} x d r () | nothing
  checkInv-F {rec} x d r refl | just t' with r refl
  checkInv-F {rec} x .(F d2) r refl | just .(F d') | inj₁ (d2 , d' , refl , refl , eq3) =
    inj₁ (F d2 , F d' , refl , refl , lem1 eq3)
    where lem1 : check {rec} x (F d2) ≡ just (F d') →
                 check {rec} x (F (F d2)) ≡ just (F (F d'))
          lem1 eq rewrite eq = refl
  checkInv-F {rec} x .(M y2) r refl | just .(M y') | inj₂ (y2 , y' , refl , refl , eq3) =
    inj₁ (M y2 , M y' , refl , refl , lem2 eq3)
    where lem2 : thick x y2 ≡ just y' →
                 check {rec} x (F (M y2)) ≡ just (F (M y'))
          lem2 eq rewrite eq = refl

  checkInv-M' : {D : Desc} → {m : ℕ} → (x y : Fin (suc m)) → {t' : Fix D m} →
           check {D} x (M y) ≡ just t' →
           (Σ[ y' ∈ Fin m ] (t' ≡ M y') × (thick x y ≡ just y'))
  checkInv-M' x y eq with thick x y
  checkInv-M' x y () | nothing
  checkInv-M' x y refl | just y' = (y' , refl , refl)

  checkInv-M : {D : Desc} → {m : ℕ} → (x y : Fin (suc m)) → {t' : Fix D m} →
           check {D} x (M y) ≡ just t' →
           Σ[ y2 ∈ Fin (suc m) ] Σ[ y' ∈ Fin m ]
            (M {D = D} y ≡ M y2) × (t' ≡ M y') × (thick x y2 ≡ just y')
  checkInv-M x y eq with checkInv-M' x y eq
  ... | (y' , t'≡My' , thickxy≡justy') = (y , y' , refl , t'≡My' , thickxy≡justy')

checkInv : {D : Desc} → {m : ℕ} → (x : Fin (suc m)) → (t : Fix D (suc m)) → {t' : Fix D m} →
           check {D} x t ≡ just t' →
           (Σ[ d ∈ ⟦ D ⟧ (Fix D (suc m)) ] Σ[ d' ∈ ⟦ D ⟧ (Fix D m) ]
            (t ≡ F d) × (t' ≡ F d') × (check-F {D} x (fmap D (check x) d) ≡ just (F d'))) ⊎
           (Σ[ y ∈ Fin (suc m) ] Σ[ y' ∈ Fin m ]
            (t ≡ M y) × (t' ≡ M y') × (thick x y ≡ just y'))
checkInv {D} {m} x =
  ind (λ (t : Fix D (suc m)) → {t' : Fix D m} →
           check {D} x t ≡ just t' →
           (Σ[ d ∈ ⟦ D ⟧ (Fix D (suc m)) ] Σ[ d' ∈ ⟦ D ⟧ (Fix D m) ]
            (t ≡ F d) × (t' ≡ F d') × (check-F {D} x (fmap D (check x) d) ≡ just (F d'))) ⊎
           (Σ[ y ∈ Fin (suc m) ] Σ[ y' ∈ Fin m ]
            (t ≡ M y) × (t' ≡ M y') × (thick x y ≡ just y')))
      (λ d r eq → checkInv-F x d r eq)
      (λ y eq → inj₂ (checkInv-M x y eq))

private
  D0 : Desc
  D0 = base :+: rec :*: rec

  d0 : ⟦ D0 ⟧ (Fix D0 1)
  d0 = inj₂ ((F (inj₁ tt)) , (F (inj₂ ((F (inj₁ tt)) , (F (inj₁ tt))))))

  ex0 : Fix D0 1 -- base -> (base -> base)
  ex0 = F d0
  -- ex0 = F (inj₂ ((F (inj₁ tt)) , (F (inj₂ ((F (inj₁ tt)) , (F (inj₁ tt)))))))

  d1 : ⟦ D0 ⟧ (Fix D0 zero)
  d1 = inj₂ ((F (inj₁ tt)) , (F (inj₂ ((F (inj₁ tt)) , (F (inj₁ tt))))))

  ex1 : Fix D0 zero
  ex1 = F (inj₂ ((F (inj₁ tt)) , (F (inj₂ ((F (inj₁ tt)) , (F (inj₁ tt)))))))

  check0 : check {D0} zero ex0 ≡ just ex1
  check0 = refl

  ex2a : Fix D0 zero
  ex2a = F (inj₁ tt)
  ex2b : Fix D0 1
  ex2b = F (inj₁ tt)
  check2 : check {D0} zero ex2b ≡ just ex2a
  check2 = refl

  ex3a : Fix D0 zero
  ex3a = F (inj₂ (F (inj₁ tt) , F (inj₁ tt)))
  ex3b : Fix D0 1
  ex3b = F (inj₂ (F (inj₁ tt) , F (inj₁ tt)))
  check3 : check {D0} zero ex3b ≡ just ex3a
  check3 = refl

  test0 : Σ[ d ∈ ⟦ D0 ⟧ (Fix D0 (suc zero)) ] Σ[ d' ∈ ⟦ D0 ⟧ (Fix D0 zero) ]
          (ex0 ≡ F d) × (ex1 ≡ F d') × (check-F' {D0} zero (fmap D0 (check zero) d) ≡ just d')
  test0 = (d0 , d1 , refl , refl , refl)

{-
  ind P phi f (F (inj₂ ([F (inj₁ tt)] , [F (inj₂ ([F (inj₁ tt)] , [F (inj₁ tt)]))])))
= phi (inj₂ ?) (everywhere D0 P (ind P phi f) (inj₂ ?))
= phi (inj₂ ?) (everywhere ? P (ind P phi f) ((F (inj₁ tt)) , (F (inj₂ ((F (inj₁ tt)) , (F (inj₁ tt)))))))
= phi (inj₂ ?) (everywhere ? P (ind P phi f) (F (inj₁ tt)) ,
                everywhere ? P (ind P phi f) (F (inj₂ ((F (inj₁ tt)) , (F (inj₁ tt)))))),
= phi (inj₂ ?) (everywhere rec P (ind P phi f) (F (inj₁ tt)) ,
                everywhere rec P (ind P phi f) (F (inj₂ ((F (inj₁ tt)) , (F (inj₁ tt))))))
= phi (inj₂ ?) (ind P phi f (F (inj₁ tt)) ,
                ind P phi f (F (inj₂ ((F (inj₁ tt)) , (F (inj₁ tt))))))
= phi (inj₂ ?) (phi tt (everywhere ? P (ind P phi f) tt) ,
                phi ((F (inj₁ tt)) , (F (inj₁ tt))) (everywhere ? P (ind P phi f) ((F (inj₁ tt)) , (F (inj₁ tt)))))
= ...
= phi1 (inj₂ ?) (phi2 tt tt ,
                phi3 ((F (inj₁ tt)) , (F (inj₁ tt)))
                    (phi4 tt tt , phi5 tt tt))
phi1 : check zero [F (inj₂ ([F (inj₁ tt)] , [F (inj₂ ([F (inj₁ tt)] , [F (inj₁ tt)]))]))] : Fix (base :+: base:*: base) (suc zero)
       = [F (inj₂ ([F (inj₁ tt)] , [F (inj₂ ([F (inj₁ tt)] , [F (inj₁ tt)]))]))] : Fix (base :+: base :*: base) zero
phi2 : check zero [F (inj₁ tt)] : Fix base (suc zero)
       = [F (inj₁ tt)] : Fix (base :+: base :*: base) zero
phi3 : check zero [F (inj₂ ([F (inj₁ tt)] , [F (inj₁ tt)]))] : Fix (base:*: base) (suc zero)
       = [F (inj₂ ([F (inj₁ tt)] , [F (inj₁ tt)]))] : Fix (base :+: base :*: base) zero
phi4 : check zero [F (inj₁ tt)] : Fix base (suc zero)
       = [F (inj₁ tt)] : Fix (base :+: base :*: base) zero
phi5 : check zero [F (inj₁ tt)] : Fix base (suc zero)
       = [F (inj₁ tt)] : Fix (base :+: base :*: base) zero
-}

{-
D = base :+: rec :*: rec なら、
[D](Fix D' m) = Unit + (Fix D' m) * (Fix D' m)

Fix D m = F (t : [D](Fix D m)) or M y

R = Fix D (suc m) として
P : R → Set
x : [D]R
[D]' P x

ind P phi f ex
-}

{-
check x (F d) = fold (check-F x) (check-M x) (F d)
              = check-F x (fmap D (fold (check-F x) (check-M x)) d)
              = check-F x (fmap D (check x) d)
-}

-- t' for x : x 番の型変数を型 t' に unify するような unifier を返す。
_for_ : {D : Desc} → {m : ℕ} →
        (t' : Fix D m) → (x : Fin (suc m)) → Fin (suc m) → Fix D m
_for_ t' x y with thick x y
... | just y' = M y'
... | nothing = t'

-- 代入 (σ : AList m n) 関係
-- AList D m n : m 個の型変数を持つ型を n 個の型変数を持つ型にする代入
data AList (D : Desc) : ℕ → ℕ → Set where
  anil : {m : ℕ} → AList D m m -- 何もしない代入
  _asnoc_/_ : {m : ℕ} {m' : ℕ} → (σ : AList D m m') → (t' : Fix D m) →
              (x : Fin (suc m)) → AList D (suc m) m'
          -- x を t' にした上で、さらにσを行う代入

-- liftAList1 lst : lst の中の型変数の数を 1 だけ増やす
liftAList1 : {D : Desc} → {m m' : ℕ} →
             AList D m m' → AList D (suc m) (suc m')
liftAList1 anil = anil
liftAList1 (σ asnoc t / x) = liftAList1 σ asnoc liftFix 1 t / inject₁ x

-- liftAList n lst : lst の中の型変数の数を n だけ増やす
liftAList : {D : Desc} → {m m' : ℕ} →
            (n : ℕ) → AList D m m' → AList D (n + m) (n + m')
liftAList zero σ = σ
liftAList (suc n) σ = liftAList1 (liftAList n σ)

liftAList≤' : {D : Desc} → {l m m' : ℕ} → (m≤′m' : m ≤′ m') →
             AList D l m → AList D ((m' ∸ m) + l) m'
liftAList≤' {m = m} ≤′-refl σ rewrite n∸n≡0 m = σ
liftAList≤' (≤′-step m≤′m') σ rewrite +-∸-assoc 1 (≤′⇒≤ m≤′m') =
  liftAList1 (liftAList≤' m≤′m' σ)

-- liftAList≤ m≤m' lst : lst の中の型変数の数を m から m' まで増やす
liftAList≤ : {D : Desc} → {l m m' : ℕ} → (m≤m' : m ≤ m') →
             AList D l m → AList D ((m' ∸ m) + l) m'
liftAList≤ m≤m' σ = liftAList≤' (≤⇒≤′ m≤m') σ

-- ふたつの代入をくっつける
_++_ : {D : Desc} → {l m n : ℕ} →
       (ρ : AList D m n) → (σ : AList D l m) →  AList D l n
ρ ++ anil = ρ
ρ ++ (alist asnoc t / x) = (ρ ++ alist) asnoc t / x

-- 後ろのσを持ち上げてから、ふたつの代入をくっつける
_+⟨_⟩_ : {D : Desc} → {l m m' n : ℕ} →
        (ρ : AList D m' n) → (m≤m' : m ≤ m') → (σ : AList D l m) →
        AList D ((m' ∸ m) + l) n
ρ +⟨ m≤m' ⟩ σ = ρ ++ (liftAList≤ m≤m' σ)

-- 代入σを Fin m → Fix D m' の関数に変換する
mvar-sub : {D : Desc} → {m m' : ℕ} → (σ : AList D m m') → Fin m → Fix D m'
mvar-sub anil = M
mvar-sub (σ asnoc t' / x) = mvar-map (mvar-sub σ) ∘ (t' for x)

-- 代入と ++ は交換できる
mvar-sub-++-commute : {D : Desc} → {m1 m2 m3 : ℕ} → (σ1 : AList D m2 m3) → (σ2 : AList D m1 m2) →
  mvar-map (mvar-sub (σ1 ++ σ2)) ≡ (mvar-map (mvar-sub σ1)) ∘ (mvar-map (mvar-sub σ2))
mvar-sub-++-commute σ1 anil = sym (ext (λ a → fuse (mvar-sub σ1) M a))
mvar-sub-++-commute σ1 (σ2 asnoc t / x) =
  ext (λ a → begin
    mvar-map (mvar-map (mvar-sub (σ1 ++ σ2)) ∘ (t for x)) a
  ≡⟨ sym (fuse (mvar-sub (σ1 ++ σ2)) (t for x) a) ⟩
    mvar-map (mvar-sub (σ1 ++ σ2)) (mvar-map (t for x) a)
  ≡⟨ cong (λ f → f (mvar-map (t for x) a)) (mvar-sub-++-commute σ1 σ2)  ⟩
    mvar-map (mvar-sub σ1) (mvar-map (mvar-sub σ2) (mvar-map (t for x) a))
  ≡⟨ cong (mvar-map (mvar-sub σ1)) (fuse (mvar-sub σ2) (t for x) a) ⟩
    mvar-map (mvar-sub σ1) (mvar-map (mvar-map (mvar-sub σ2) ∘ (t for x)) a)
  ≡⟨ refl ⟩
    ((mvar-map (mvar-sub σ1)) ∘ (mvar-map (mvar-map (mvar-sub σ2) ∘ (t for x)))) a
  ∎)

-- substFix σ t : t に σ を適用した型を返す
substFix : {D : Desc} → {m m' : ℕ} → AList D m m' → Fix D m → Fix D m'
substFix σ t = mvar-map (mvar-sub σ) t

-- substFix≤ σ m≤m' t : t の中の型変数の数を m から m'' に増やしてからσをかける
substFix≤ : {D : Desc} → {m m' m'' : ℕ} → AList D m'' m' →
            (m≤m'' : m ≤ m'') → Fix D m → Fix D m'
substFix≤ σ m≤m'' t = mvar-map (mvar-sub σ) (liftFix≤ m≤m'' t)

-- 型変数 x と y を unify する代入を返す
flexFlex : {D : Desc} → {m : ℕ} → (x y : Fin m) → Σ[ m' ∈ ℕ ] AList D m m'
flexFlex {D} {zero} () y
flexFlex {D} {suc m} x y with thick x y
... | nothing = (suc m , anil) -- x = y だった。代入の必要なし
... | just y' = (m , anil asnoc (M y') / x) -- M y' for x を返す

-- 型変数 x と型 t を unify する代入を返す
-- x が t に現れていたら nothing を返す
flexRigid : {D : Desc} → {m : ℕ} → (x : Fin m) → (t : Fix D m) →
                Maybe (Σ[ m' ∈ ℕ ] AList D m m')
flexRigid {D} {zero} () t
flexRigid {D} {suc m} x t with check x t
... | nothing = nothing -- x が t に現れていた
... | just t' = just (m , anil asnoc t' / x) -- t' for x を返す

-- 型 t1 と t2（に acc をかけたもの）を unify する代入を返す
mutual
  amgu : {D : Desc} → {m : ℕ} →
         (t1 t2 : Fix D m) → (acc : Σ[ m' ∈ ℕ ] AList D m m') →
         Maybe (Σ[ m' ∈ ℕ ] AList D m m')
  amgu {D} (F t1) (F t2) (m' , anil) = amgu' {D} t1 t2 (m' , anil)
  amgu (F t1) (M x2) (m' , anil) = flexRigid x2 (F t1)
  amgu (M x1) (F t2) (m' , anil) = flexRigid x1 (F t2)
  amgu (M x1) (M x2) (m' , anil) = just (flexFlex x1 x2)
  amgu {D} {suc m} t1 t2 (m' , σ asnoc r / z)
    with amgu {D} {m} (mvar-map (r for z) t1) (mvar-map (r for z) t2) (m' , σ)
  ... | just (m'' , σ') = just (m'' , (σ' asnoc r / z))
  ... | nothing = nothing

  amgu' : {D D' : Desc} → {m : ℕ} →
          (t1 t2 : ⟦ D ⟧ (Fix D' m)) → (acc : Σ[ m' ∈ ℕ ] AList D' m m') →
          Maybe (Σ[ m' ∈ ℕ ] AList D' m m')
  amgu' {base} tt tt acc = just acc
  amgu' {D1 :+: D2} (inj₁ t1) (inj₁ t2) acc = amgu' {D1} t1 t2 acc
  amgu' {D1 :+: D2} (inj₁ t1) (inj₂ t2) acc = nothing
  amgu' {D1 :+: D2} (inj₂ t1) (inj₁ t2) acc = nothing
  amgu' {D1 :+: D2} (inj₂ t1) (inj₂ t2) acc = amgu' {D2} t1 t2 acc
  amgu' {D1 :*: D2} (t11 , t12) (t21 , t22) acc with amgu' {D1} t11 t21 acc
  ... | just acc' = amgu' {D2} t12 t22 acc'
  ... | nothing = nothing
  amgu' {rec} t1 t2 acc = amgu t1 t2 acc

mgu : {D : Desc} → {m : ℕ} →
      (t1 t2 : Fix D m) → Maybe (Σ[ m' ∈ ℕ ] AList D m m')
mgu {D} {m} t1 t2 = amgu t1 t2 (m , anil)

private

  -- test

  D1 : Desc
  D1 = base :+: rec

  TInt : Fix D1 1
  TInt = F (inj₁ tt)

  TIntList : Fix D1 1
  TIntList = F (inj₂ TInt)

  [rec]FixD11 : ⟦ rec ⟧ (Fix D1 1)
  [rec]FixD11 = F (inj₁ tt)

  [D1]FixD11 : ⟦ D1 ⟧ (Fix D1 1)
  [D1]FixD11 = (inj₂ (F (inj₁ tt)))

  [D1]FixD11' : ⟦ D1 ⟧ (Fix D1 1)
  [D1]FixD11' = inj₂ (F (inj₂ (F (inj₁ tt))))

  TIntListList : Fix D1 1
  TIntListList = F (inj₂ (F (inj₂ (F (inj₁ tt)))))

  -- type

  TypeDesc : Desc
  TypeDesc = base :+: rec :*: rec

  Type : (m : ℕ) → Set
  Type m = Fix TypeDesc m

  TVar : {m : ℕ} → (x : Fin m) → Type m
  TVar = M

  TNat : {m : ℕ} → Type m
  TNat = F (inj₁ tt)

  _⇒_ : {m : ℕ} → Type m → Type m → Type m
  t1 ⇒ t2 = F (inj₂ (t1 , t2))

  t1 : Type 4
  t1 = TVar zero ⇒ TVar zero
  -- 0 ⇒ 0

  t2 : Type 4
  t2 = (TVar (suc zero) ⇒ TVar (suc (suc zero))) ⇒ TVar (suc (suc (suc zero)))
  -- (1 ⇒ 2) ⇒ 3

  u12 : Maybe (∃ (AList TypeDesc 4))
  u12 = mgu t1 t2
  -- just
  -- (2 ,
  --  (anil asnoc F (inj₂ (M zero , M (suc zero))) / suc (suc zero))
  --  asnoc F (inj₂ (M zero , M (suc zero))) / zero)
  -- 0 -> 0 ⇒ 1
  -- 2 -> 0 ⇒ 1

  t3 : Type 4
  t3 = (TVar zero ⇒ TVar (suc (suc zero))) ⇒ TVar (suc (suc (suc zero)))

  u13 : Maybe (∃ (AList TypeDesc 4))
  u13 = mgu t1 t3
  -- nothing

-- σ2 extends σ1 :「σ2 は σ1 の拡張になっている」という命題
_extends_ : {D : Desc} → {m : ℕ} →
            (σ2 : Σ[ m2 ∈ ℕ ] AList D m m2) (σ1 : Σ[ m1 ∈ ℕ ] AList D m m1) → Set
_extends_ {D} {m} (m2 , σ2) (m1 , σ1) =
  ∀ (s t : Fix D m) → substFix σ1 s ≡ substFix σ1 t → substFix σ2 s ≡ substFix σ2 t

-- 自分自身は自分自身の拡張になっている
σextendsσ : {D : Desc} → {m : ℕ} → (σ : Σ[ n ∈ ℕ ] AList D m n) → σ extends σ
σextendsσ σ s t eq = eq

-- 任意のσは anil の拡張になっている
σextendsNil : {D : Desc} → {m : ℕ} → (σ : Σ[ m' ∈ ℕ ] AList D m m') → σ extends (m , anil)
σextendsNil (m' , σ) s t eq rewrite fold-id s | fold-id t = cong (substFix σ) eq

-- asnoc しても拡張関係は保たれる
extends-asnoc : {D : Desc} → {m m1 m2 : ℕ} → {σ1 : AList D m m1} → {σ2 : AList D m m2} →
        {r : Fix D m} → {z : Fin (suc m)} →
        (m2 , σ2) extends (m1 , σ1) →
        (m2 , σ2 asnoc r / z) extends (m1 , σ1 asnoc r / z)
extends-asnoc {σ1 = σ1} {σ2 = σ2} {r = r} {z = z} ex s t eq
  rewrite sym (fuse (mvar-sub σ1) (r for z) s)
        | sym (fuse (mvar-sub σ1) (r for z) t)
        | sym (fuse (mvar-sub σ2) (r for z) s)
        | sym (fuse (mvar-sub σ2) (r for z) t)
  = ex (fold F (r for z) s) (fold F (r for z) t) eq

{-
  (m2 , σ2) extends (m1 , σ1)
= ∀ (s t : Fix D m) → substFix σ1 s ≡ substFix σ1 t → substFix σ2 s ≡ substFix σ2 t
= ∀ (s t : Fix D m) → mvar-map (mvar-sub σ1) s ≡ mvar-map (mvar-sub σ1) t →
                       mvar-map (mvar-sub σ2) s ≡ mvar-map (mvar-sub σ2) t
= ∀ (s t : Fix D m) → fold F (mvar-sub σ1) s ≡ fold F (mvar-sub σ1) t →
                       fold F (mvar-sub σ2) s ≡ fold F (mvar-sub σ2) t

  (m2 , σ2 asnoc r / z) extends (m1 , σ1 asnoc r / z)
= ∀ (s t : Fix D m) → fold F (mvar-sub (σ1 asnoc r / z)) s ≡ fold F (mvar-sub (σ1 asnoc r / z)) t →
                       fold F (mvar-sub (σ2 asnoc r / z)) s ≡ fold F (mvar-sub (σ2 asnoc r / z)) t
= ∀ (s t : Fix D m) → fold F (mvar-map (mvar-sub σ1) ∘ r for z) s ≡ fold F (mvar-map (mvar-sub σ1) ∘ r for z) t →
                       fold F (mvar-map (mvar-sub σ2) ∘ r for z) s ≡ fold F (mvar-map (mvar-sub σ2) ∘ r for z) t
= ∀ (s t : Fix D m) → fold F (mvar-sub σ1) (fold F (r for z) s) ≡
                       fold F (mvar-sub σ1) (fold F (r for z) t) →
                       fold F (mvar-sub σ2) (fold F (r for z) s) ≡
                       fold F (mvar-sub σ2) (fold F (r for z) t)
-}

-- inj したものが等しいなら、中身も等しい
inj₁-equal : {A B : Set} → {a1 a2 : A} → inj₁ {B = B} a1 ≡ inj₁ a2 → a1 ≡ a2
inj₁-equal refl = refl

inj₂-equal : {A B : Set} → {b1 b2 : B} → inj₂ {A = A} b1 ≡ inj₂ b2 → b1 ≡ b2
inj₂-equal refl = refl

-- extends しても eq の関係は変わらない
extends-eq : {D D' : Desc} → {m m1 m2 : ℕ} → {σ1 : AList D' m m1} → {σ2 : AList D' m m2} →
        (s t : ⟦ D ⟧ (Fix D' m)) →
        (m2 , σ2) extends (m1 , σ1) →
        fmap D (fold F (mvar-sub σ1)) s ≡ fmap D (fold F (mvar-sub σ1)) t →
        fmap D (fold F (mvar-sub σ2)) s ≡ fmap D (fold F (mvar-sub σ2)) t
extends-eq {base} s t ex eq = refl
extends-eq {D1 :+: D2} {σ1 = σ1} {σ2 = σ2} (inj₁ s) (inj₁ t) ex eq =
  cong inj₁ (extends-eq {D1} {σ1 = σ1} {σ2 = σ2} s t ex (inj₁-equal eq))
extends-eq {D1 :+: D2} (inj₁ s) (inj₂ t) ex ()
extends-eq {D1 :+: D2} (inj₂ s) (inj₁ t) ex ()
extends-eq {D1 :+: D2} {σ1 = σ1} {σ2 = σ2} (inj₂ s) (inj₂ t) ex eq =
  cong inj₂ (extends-eq {D2} {σ1 = σ1} {σ2 = σ2} s t ex (inj₂-equal eq))
extends-eq {D1 :*: D2} {σ1 = σ1} {σ2 = σ2} (s1 , s2) (t1 , t2) ex eq =
  cong₂ _,_ (extends-eq {D1} {σ1 = σ1} {σ2 = σ2} s1 t1 ex (cong proj₁ eq))
            (extends-eq {D2} {σ1 = σ1} {σ2 = σ2} s2 t2 ex (cong proj₂ eq))
extends-eq {rec} s t ex eq = ex s t eq

-- 型変数 x と y を unify する代入を返す
flexFlex2 : {D : Desc} → {m : ℕ} → (x1 x2 : Fin m) →
            (Σ[ m' ∈ ℕ ] Σ[ σ ∈ AList D m m' ]
             substFix σ (M x1) ≡ substFix σ (M x2))
flexFlex2 {D} {zero} () x2
flexFlex2 {D} {suc m} x1 x2 with thick x1 x2 | inspect (thick x1) x2
... | nothing | [ thickx1x2≡nothing ] =
  (suc m , anil , cong M (thickxy-x≡y x1 x2 thickx1x2≡nothing))  -- x1 = x2 だった。代入の必要なし
... | just x2' | [ thickx1x2≡justx2' ] =
  (m , anil asnoc M x2' / x1 , cong (mvar-map M) (eq thickx1x2≡justx2'))  -- TVar x2' for x1 を返す
  where eq : thick x1 x2 ≡ just x2' → mvar-map {D} (M x2' for x1) (M x1) ≡ mvar-map (M x2' for x1) (M x2)
        eq thickx1x2≡justx2' rewrite thickxx≡nothing x1 | thickx1x2≡justx2' = refl

flexRigidLem-F' : {D D' : Desc} → {m : ℕ} →
             (x : Fin (suc m)) → (d : ⟦ D ⟧ (Fix D' (suc m))) →
             (r : ⟦ D ⟧' (λ t → {t' t'' : Fix D' m} → check x t ≡ just t' → t' ≡ fold F (mvar-map M ∘ (t'' for x)) t) d) →
             {d' : ⟦ D ⟧ (Fix D' m)} →
             {t'' : Fix D' m} →
             check-F' {D} x (fmap D (check x) d) ≡ just d' →
             d' ≡ fmap D (fold F (mvar-sub (anil asnoc t'' / x))) d
flexRigidLem-F' {base} x tt tt {tt} refl = refl
flexRigidLem-F' {D1 :+: D2} x (inj₁ d) r eq
  with check-F' {D1} x (fmap D1 (check x) d) | inspect (check-F' {D1} x) (fmap D1 (check x) d)
flexRigidLem-F' {D1 :+: D2} x (inj₁ d) r () | nothing | _
flexRigidLem-F' {D1 :+: D2} x (inj₁ d) r refl | just d' | [ eq' ] = cong inj₁ (flexRigidLem-F' {D1} x d r eq')
flexRigidLem-F' {D1 :+: D2} x (inj₂ d) r eq
  with check-F' {D2} x (fmap D2 (check x) d) | inspect (check-F' {D2} x) (fmap D2 (check x) d)
flexRigidLem-F' {D1 :+: D2} x (inj₂ d) r () | nothing | _
flexRigidLem-F' {D1 :+: D2} x (inj₂ d) r refl | just d' | [ eq' ] = cong inj₂ (flexRigidLem-F' {D2} x d r eq')
flexRigidLem-F' {D1 :*: D2} x (d1 , d2) r eq
  with check-F' {D1} x (fmap D1 (check x) d1) | inspect (check-F' {D1} x) (fmap D1 (check x) d1)
flexRigidLem-F' {D1 :*: D2} x (d1 , d2) r () | nothing | _
flexRigidLem-F' {D1 :*: D2} x (d1 , d2) r eq | just d1' | [ eq1 ]
  with check-F' {D2} x (fmap D2 (check x) d2) | inspect (check-F' {D2} x) (fmap D2 (check x) d2)
flexRigidLem-F' {D1 :*: D2} x (d1 , d2) r () | just d1' | [ eq1 ] | nothing | _
flexRigidLem-F' {D1 :*: D2} x (d1 , d2) (r1 , r2) {.d1' , .d2'} refl | just d1' | [ eq1 ] | just d2' | [ eq2 ]
  = cong₂ _,_ (flexRigidLem-F' {D1} x d1 r1 eq1) (flexRigidLem-F' {D2} x d2 r2 eq2)
flexRigidLem-F' {rec} x d r eq with check x d
flexRigidLem-F' {rec} x d r () | nothing
flexRigidLem-F' {rec} x d r refl | just d' = r refl

flexRigidLem-F : {D : Desc} → {m : ℕ} →
             (x : Fin (suc m)) → (d : ⟦ D ⟧ (Fix D (suc m))) →
             (r : ⟦ D ⟧' (λ t → {t' t'' : Fix D m} → check x t ≡ just t' → t' ≡ fold F (mvar-map M ∘ (t'' for x)) t) d) →
             {t' t'' : Fix D m} →
             check x (F d) ≡ just t' →
             t' ≡ F (fmap D (fold F (mvar-sub (anil asnoc t'' / x))) d)
flexRigidLem-F {D} x d r eq with checkInv x (F d) eq
... | inj₂ (y2 , y' , () , eq2 , eq3)
... | inj₁ (.d , d' , refl , refl , eq3)
  with check-F' {D} x (fmap D (check x) d) | inspect (check-F' {D} x) (fmap D (check x) d)
flexRigidLem-F {D} x d r eq | inj₁ (.d , d' , refl , refl , refl) | just .d' | [ eq2 ] = cong F (flexRigidLem-F' {D} x d r eq2)
flexRigidLem-F x d r eq | inj₁ (.d , d' , refl , refl , ()) | nothing | _

flexRigidLem-M : {D : Desc} → {m : ℕ} → (x y : Fin (suc m)) →
               {t' t'' : Fix D m} → check x (M y) ≡ just t' →
               t' ≡ (mvar-sub (anil asnoc t'' / x)) y
flexRigidLem-M x y checkxMx≡justt' with thick x y
flexRigidLem-M x y () | nothing
flexRigidLem-M x y refl | just y' = refl

flexRigidLem' : {D : Desc} → {m : ℕ} →
               (x : Fin (suc m)) → (t : Fix D (suc m)) → {t' t'' : Fix D m} →
               check x t ≡ just t' → -- x が t に現れないなら
               t' ≡ fold F (mvar-sub (anil asnoc t'' / x)) t
             -- ≡ mvar-map (mvar-sub (anil asnoc t'' / x)) t
flexRigidLem' {D} {m} x =
  ind (λ t → {t' t'' : Fix D m} → check x t ≡ just t' → t' ≡ fold F (mvar-sub (anil asnoc t'' / x)) t)
      (λ d r → flexRigidLem-F x d r)
      (λ y → flexRigidLem-M x y)

flexRigidLem : {D : Desc} → {m : ℕ} →
               (x : Fin (suc m)) → (t : Fix D (suc m)) → {t' : Fix D m} →
               check x t ≡ just t' →
               mvar-sub (anil asnoc t' / x) x ≡ fold F (mvar-sub (anil asnoc t' / x)) t
flexRigidLem x t {t'} checkxt≡justt' rewrite checkxt≡justt' | thickxx≡nothing x | fold-id t' =
  flexRigidLem' x t checkxt≡justt'

-- 型変数 x と型 t を unify する代入を返す
-- x が t に現れていたら nothing を返す
flexRigid2 : {D : Desc} → {m : ℕ} → (x : Fin m) → (t : Fix D m) →
             Maybe (Σ[ m' ∈ ℕ ] Σ[ σ ∈ AList D m m' ] substFix σ (M x) ≡ substFix σ t)
flexRigid2 {D} {zero} () t
flexRigid2 {D} {suc m} x t with check x t | inspect (check x) t
... | nothing | [ checkxt≡nothing ] = nothing -- x が t に現れていた
... | just t' | [ checkxt≡justt' ] rewrite checkxt≡justt' =
  just (m , anil asnoc t' / x , flexRigidLem x t checkxt≡justt')  -- t' for x を返す

-- 型 s と t（に acc をかけたもの）を unify する代入を返す
mutual
  amgu2 : {D : Desc} → {m : ℕ} → (t1 t2 : Fix D m) →
        (acc : Σ[ m' ∈ ℕ ] AList D m m') →
        Maybe (Σ[ m' ∈ ℕ ] Σ[ σ ∈ AList D m m' ]
               (m' , σ) extends acc ×
               substFix σ t1 ≡ substFix σ t2)
  amgu2 {D} (F t1) (F t2) (m , anil) with amgu2' {D} t1 t2 (m , anil)
  ... | nothing = nothing
  ... | just (m' , σ' , ex , eq) = just (m' , σ' , ex , cong F eq)
  amgu2 {D} (F t1) (M x2) (m , anil) with flexRigid2 {D} x2 (F t1)
  ... | nothing = nothing
  ... | just (m' , σ' , eq) = just (m' , σ' , σextendsNil (m' , σ') , sym eq)
  amgu2 {D} (M x1) (F t2) (m , anil) with flexRigid2 {D} x1 (F t2)
  ... | nothing = nothing
  ... | just (m' , σ' , eq) = just (m' , σ' , σextendsNil (m' , σ') , eq)
  amgu2 {D} (M x1) (M x2) (m , anil) with flexFlex2 {D} x1 x2
  ... | (m' , σ' , eq) = just (m' , σ' , σextendsNil (m' , σ') , eq)
  amgu2 {D} {suc m} t1 t2 (m' , σ asnoc r / z)
    with amgu2 {D} {m} (mvar-map (r for z) t1) (mvar-map (r for z) t2) (m' , σ)
  ... | just (m'' , σ' , ex , eq)
    rewrite fuse (mvar-sub σ') (r for z) t1 | fuse (mvar-sub σ') (r for z) t2
    = just (m'' , σ' asnoc r / z , ex' , eq)
      where ex' : (s t : Fix D (suc m)) →
                   fold F (mvar-sub (σ asnoc r / z)) s ≡ fold F (mvar-sub (σ asnoc r / z)) t →
                   fold F (mvar-sub (σ' asnoc r / z)) s ≡ fold F (mvar-sub (σ' asnoc r / z)) t
            ex' = extends-asnoc {D} {σ1 = σ} {σ2 = σ'} {r = r} {z = z} ex
  ... | nothing = nothing

  amgu2' : {D D' : Desc} → {m : ℕ} → (t1 t2 : ⟦ D ⟧ (Fix D' m)) →
        (acc : Σ[ m' ∈ ℕ ] AList D' m m') →
        Maybe (Σ[ m' ∈ ℕ ] Σ[ σ ∈ AList D' m m' ]
               (m' , σ) extends acc ×
               fmap D (fold F (mvar-sub σ)) t1 ≡ fmap D (fold F (mvar-sub σ)) t2)
               -- substFix σ (F t1) ≡ substFix σ (F t2))
  amgu2' {base} tt tt (m' , σ) = just (m' , σ , σextendsσ (m' , σ) , refl)
  amgu2' {D1 :+: D2} (inj₁ t1) (inj₁ t2) acc with amgu2' {D1} t1 t2 acc
  ... | nothing = nothing
  ... | just (m' , σ , ex , eq) = just (m' , σ , ex , cong inj₁ eq)
  amgu2' {D1 :+: D2} (inj₁ t1) (inj₂ t2) acc = nothing
  amgu2' {D1 :+: D2} (inj₂ t1) (inj₁ t2) acc = nothing
  amgu2' {D1 :+: D2} (inj₂ t1) (inj₂ t2) acc with amgu2' {D2} t1 t2 acc
  ... | nothing = nothing
  ... | just (m' , σ , ex , eq) = just (m' , σ , ex , cong inj₂ eq)
  amgu2' {D1 :*: D2} (t11 , t12) (t21 , t22) (m' , σ)
    with amgu2' {D1} t11 t21 (m' , σ)
  ... | nothing = nothing
  ... | just (m1 , σ1 , ex1 , eq1)
    with amgu2' {D2} t12 t22 (m1 , σ1)
  ... | nothing = nothing
  ... | just (m2 , σ2 , ex2 , eq2) =
    just (m2 , σ2 , (λ s t x → ex2 s t (ex1 s t x)) ,
          cong₂ _,_ (extends-eq {D1} {σ1 = σ1} {σ2 = σ2} t11 t21 ex2 eq1) eq2)
  amgu2' {rec} t1 t2 acc = amgu2 t1 t2 acc

-- 型 t1 と t2 を unify する代入を、確かに unify できることの証明とともに返す
mgu2 : {D : Desc} → {m : ℕ} → (t1 t2 : Fix D m) →
       Maybe (Σ[ m' ∈ ℕ ] Σ[ σ ∈ AList D m m' ] substFix σ t1 ≡ substFix σ t2)
mgu2 {D} {m} t1 t2 with amgu2 {D} {m} t1 t2 (m , anil)
... | just (n , σ , _ , eq) = just (n , σ , eq)
... | nothing = nothing
