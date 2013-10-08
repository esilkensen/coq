(* Abstracting Abstract Machines (Van Horn and Might, ICFP'10) *)

Require Export SfLib.

Inductive id : Type := 
  Id : nat -> id.

Definition beq_id X1 X2 :=
  match (X1, X2) with
    (Id n1, Id n2) => beq_nat n1 n2
  end.

Theorem beq_id_refl : forall X,
  true = beq_id X X.
Proof. destruct X. apply beq_nat_refl. Qed.

Theorem beq_id_sym: forall i1 i2,
  beq_id i1 i2 = beq_id i2 i1.
Proof.
  intros. destruct i1. destruct i2. unfold beq_id. apply beq_nat_sym.
Qed.

Theorem beq_id_eq : forall i1 i2,
  true = beq_id i1 i2 -> i1 = i2.
Proof.
  intros. destruct i1. destruct i2. unfold beq_id in H.
  apply beq_nat_eq in H. rewrite H. reflexivity.
Qed.

(* ###################################################################### *)

Inductive expr : Type :=
  | e_var : id -> expr
  | e_app : expr -> expr -> expr
  | e_abs : id -> expr -> expr.

Inductive val : Type :=
  | v_abs : id -> expr -> val.

Tactic Notation "expr_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "e_var" | Case_aux c "e_app" | Case_aux c "e_abs" ].

(* ###################################################################### *)

Module CEK.

Inductive env : Type :=
  | env_empty : env
  | env_extend : env -> id -> (val * env) -> env.

Fixpoint env_lookup p x :=
  match p with
    | env_empty => None
    | env_extend q y (v, p') =>
      if beq_id x y then Some (v, p') else env_lookup q x
  end.

Inductive kont : Type :=
  | mt : kont
  | ar : expr -> env -> kont -> kont
  | fn : val -> env -> kont -> kont.

Inductive state : Type :=
  | ev : expr -> env -> kont -> state
  | ap : val -> env -> kont -> state.

Definition inj : expr -> state :=
  fun e => ev e env_empty mt.

Reserved Notation "s1 '==>' s2" (at level 40).

Inductive step : state -> state -> Prop :=
  | cek0 :
      forall x e p k,
        ev (e_abs x e) p k
        ==>
        ap (v_abs x e) p k
  | cek1 :
      forall x p k v p',
        env_lookup p x = Some (v, p') ->
        ev (e_var x) p k
        ==>
        ap v p' k
  | cek2 :
      forall e0 e1 p k,
        ev (e_app e0 e1) p k
        ==>
        ev e0 p (ar e1 p k)
  | cek3 :
      forall v p e p' k,
        ap v p (ar e p' k)
        ==>
        ev e p' (fn v p k)
  | cek4 :
      forall v p x e p' k,
        ap v p (fn (v_abs x e) p' k)
        ==>
        ev e (env_extend p' x (v, p)) k

where "s1 '==>' s2" := (step s1 s2).

Hint Constructors step.

Notation "s1 '==>*' s2" := (multi step s1 s2) (at level 40).

Example ex1 :
  forall x y,
    inj (e_app (e_abs x (e_var x)) (e_abs y (e_var y)))
    ==>*
    ap (v_abs y (e_var y)) env_empty mt.
Proof.
  intros. unfold inj.
  eapply multi_step. apply cek2.
  eapply multi_step. apply cek0.
  eapply multi_step. apply cek3.
  eapply multi_step. apply cek0.
  eapply multi_step. apply cek4.
  eapply multi_step. apply cek1.
    simpl. rewrite <- beq_id_refl. reflexivity.
  apply multi_refl.
Qed.

End CEK.

(* ###################################################################### *)

Module CESK.

Definition addr : Type := id.
       
Inductive env : Type :=
  | env_empty : env
  | env_extend : env -> id -> addr -> env.

Definition storable : Type := (val * env)%type.

Inductive store : Type :=
  | store_empty : store
  | store_extend : store -> addr -> storable -> store.

Fixpoint env_lookup p x :=
  match p with
    | env_empty => None
    | env_extend q y a =>
      if beq_id x y then Some a else env_lookup q x
  end.

Fixpoint store_lookup s a :=
  match s with
    | store_empty => None
    | store_extend t b (v, p') =>
      if beq_id a b then Some (v, p') else store_lookup t a
  end.

Fixpoint alloc s :=
  match s with
    | store_empty => Id 0
    | store_extend t (Id n) (v, p') => Id (n + 1)
  end.

Inductive kont : Type :=
  | mt : kont
  | ar : expr -> env -> kont -> kont
  | fn : val -> env -> kont -> kont.

Inductive state : Type :=
  | ev : expr -> env -> store -> kont -> state
  | ap : val -> env -> store -> kont -> state.

Definition inj : expr -> state :=
  fun e => ev e env_empty store_empty mt.

Reserved Notation "s1 '==>' s2" (at level 40).

Inductive step : state -> state -> Prop :=
  | cesk0 :
      forall x e p s k,
        ev (e_abs x e) p s k
        ==>
        ap (v_abs x e) p s k
  | cesk1 :
      forall x p s k a v p',
        env_lookup p x = Some a ->
        store_lookup s a = Some (v, p') ->
        ev (e_var x) p s k
        ==>
        ap v p' s k
  | cesk2 :
      forall e0 e1 p s k,
        ev (e_app e0 e1) p s k
        ==>
        ev e0 p s (ar e1 p k)
  | cesk3 :
      forall v p s e p' k,
        ap v p s (ar e p' k)
        ==>
        ev e p' s (fn v p k)
  | cesk4 :
      forall v p s x e p' k a,
        a = alloc s ->
        ap v p s (fn (v_abs x e) p' k)
        ==>
        ev e (env_extend p' x a) (store_extend s a (v, p)) k

where "s1 '==>' s2" := (step s1 s2).

Hint Constructors step.

Notation "s1 '==>*' s2" := (multi step s1 s2) (at level 40).

Example ex1 :
  forall x y,
    inj (e_app (e_abs x (e_var x)) (e_abs y (e_var y)))
    ==>*
    ap (v_abs y (e_var y)) env_empty
    (store_extend store_empty (Id 0) (v_abs y (e_var y), env_empty)) mt.
Proof.
  intros. unfold inj.
  eapply multi_step. apply cesk2.
  eapply multi_step. apply cesk0.
  eapply multi_step. apply cesk3.
  eapply multi_step. apply cesk0.
  eapply multi_step. apply cesk4.
    reflexivity.
  eapply multi_step. eapply cesk1.
    simpl. rewrite <- beq_id_refl. reflexivity. reflexivity.
  apply multi_refl.
Qed.

End CESK.

(* ###################################################################### *)

Inductive cek_sim_cesk_env : CEK.env -> CESK.env -> CESK.store -> Prop :=
  | empty_sim :
      forall s2,
        cek_sim_cesk_env CEK.env_empty CESK.env_empty s2
  | extend_sim :
      forall q1 x1 v1 p1,
        forall q2 x2 a2 v2 p2 s2,
          x1 = x2 ->
          v1 = v2 ->
          cek_sim_cesk_env q1 q2 s2 ->
          cek_sim_cesk_env p1 p2 s2 ->
          CESK.store_lookup s2 a2 = Some (v2, p2) ->
          cek_sim_cesk_env
            (CEK.env_extend q1 x1 (v1, p1)) (CESK.env_extend q2 x2 a2) s2.

Hint Constructors cek_sim_cesk_env.

Lemma cek_sim_cesk_env_lookup :
  forall p1 p2 s2,
    cek_sim_cesk_env p1 p2 s2 ->
    forall x v1 p1',
      CEK.env_lookup p1 x = Some (v1, p1') ->
      exists a2 p2',
        cek_sim_cesk_env p1' p2' s2 /\
        CESK.env_lookup p2 x = Some a2 /\
        CESK.store_lookup s2 a2 = Some (v1, p2').
Proof.
  intros p1 p2 s2 H1.
  induction H1; intros.
  Case "empty".
    inversion H.
  Case "extend".
    subst.
    remember (beq_id x x2) as b. destruct b.
    SCase "x = x2".
      simpl. rewrite <- Heqb.
      apply beq_id_eq in Heqb. subst.
      simpl in H2. rewrite <- beq_id_refl in H2. inversion H2; subst.
      apply ex_intro with a2. apply ex_intro with p2.
      split. assumption. split. reflexivity. assumption.
    SCase "x <> x2".
      simpl. rewrite <- Heqb.
      simpl in H2. rewrite <- Heqb in H2. 
      apply IHcek_sim_cesk_env1 in H2. assumption.
Qed.

Inductive cek_sim_cesk_kont : CEK.kont -> CESK.kont -> CESK.store -> Prop :=
  | mt_sim :
      forall s2,
        cek_sim_cesk_kont CEK.mt CESK.mt s2
  | ar_sim :
      forall e1 p1 k1,
        forall e2 p2 s2 k2,
          e1 = e2 ->
          cek_sim_cesk_env p1 p2 s2 ->
          cek_sim_cesk_kont k1 k2 s2 ->
          cek_sim_cesk_kont (CEK.ar e1 p1 k1) (CESK.ar e2 p2 k2) s2
  | fn_sim :
      forall v1 p1 k1,
        forall v2 p2 s2 k2,
          v1 = v2 ->
          cek_sim_cesk_env p1 p2 s2 ->
          cek_sim_cesk_kont k1 k2 s2 ->
          cek_sim_cesk_kont (CEK.fn v1 p1 k1) (CESK.fn v2 p2 k2) s2.

Hint Constructors cek_sim_cesk_kont.

Inductive cek_sim_cesk_state : CEK.state -> CESK.state -> Prop :=
  | ev_sim :
      forall e1 p1 k1,
        forall e2 p2 s2 k2,
          e1 = e2 ->
          cek_sim_cesk_env p1 p2 s2 ->
          cek_sim_cesk_kont k1 k2 s2 ->
          cek_sim_cesk_state (CEK.ev e1 p1 k1) (CESK.ev e2 p2 s2 k2)
  | ap_sim :
      forall v1 p1 k1,
        forall v2 p2 s2 k2,
          v1 = v2 ->
          cek_sim_cesk_env p1 p2 s2 ->
          cek_sim_cesk_kont k1 k2 s2 ->
          cek_sim_cesk_state (CEK.ap v1 p1 k1) (CESK.ap v2 p2 s2 k2).

Hint Constructors cek_sim_cesk_state.

Notation "s1 '~' t1" := (cek_sim_cesk_state s1 t1) (at level 40).

(* ###################################################################### *)

Inductive n_steps {X : Type} (step : relation X) : X -> X -> nat -> Prop :=
  | step_0 : forall s1,
               n_steps step s1 s1 0
  | step_1 : forall s1 s2,
               step s1 s2 ->
               n_steps step s1 s2 1
  | step_n : forall s1 s2 s3 n,
               n_steps step s1 s2 n ->
               n_steps step s2 s3 1 ->
               n_steps step s1 s3 (1 + n).

Lemma cek_sim_cesk_step :
  forall e s n,
    n_steps CEK.step (CEK.inj e) s n ->
    exists t,
      n_steps CESK.step (CESK.inj e) t n /\ s ~ t.
Proof.
  intros e s n. generalize dependent s.
  induction n as [| n']; intros s H.
  Case "n = 0".
    unfold CEK.inj in H. unfold CESK.inj.
    expr_cases (destruct e) SCase;
      (eapply ex_intro;
       split; [apply step_0 |
               inversion H; subst; auto]).
  Case "n = S n'".
    expr_cases (destruct e) SCase.
    SCase "e_var".
      inversion H; subst.
      SSCase "step_1".
        inversion H3; subst.
        inversion H5.
      SSCase "step_n".
        inversion H4; subst. inversion H0; subst.
        SSSCase "cek0".
          assert
            (exists t,
               n_steps CESK.step (CESK.inj (e_var i)) t n' /\
               (CEK.ev (e_abs x e) p k) ~ t) by
            (apply IHn'; assumption).
          inversion H2 as [t1]. inversion H3.
          assert
            (exists t1',
               n_steps CESK.step t1 t1' 1 /\
               (CEK.ap (v_abs x e) p k) ~ t1') by
              (inversion H6; subst;
               eapply ex_intro;
               split; [apply step_1; auto |
                       auto]).
          inversion H7 as [t1']. inversion H8.
          apply ex_intro with t1'. split.
            apply step_n with t1; assumption.
            assumption.
        SSSCase "cek1".
          assert
            (exists t,
               n_steps CESK.step (CESK.inj (e_var i)) t n' /\
               (CEK.ev (e_var x) p k) ~ t) by
            (apply IHn'; assumption).
          inversion H3 as [t1]. inversion H5.
          assert
            (exists t1',
               n_steps CESK.step t1 t1' 1 /\
               (CEK.ap v p' k) ~ t1').
          SSSSCase "Proof of assertion".
            inversion H7; subst.
            apply cek_sim_cesk_env_lookup with p p2 s2 x v p' in H13.
            inversion H13; subst. inversion H8; subst. inversion H9; subst.
            inversion H11; subst. clear H9. clear H8. clear H11. clear H13.
            eapply ex_intro. split.
              apply step_1.
                eapply CESK.cesk1; eassumption.
                apply ap_sim.
                  reflexivity.
                  assumption.
                  assumption.
                  assumption.
          inversion H8 as [t1']. inversion H9.
          apply ex_intro with t1'. split.
            apply step_n with t1; assumption.
            assumption.
        SSSCase "cek2".
          Admitted.

Lemma cesk_sim_cek_step :
  forall e t n,
    n_steps CESK.step (CESK.inj e) t n ->
    exists s,
      n_steps CEK.step (CEK.inj e) s n /\ s ~ t.
Proof.
  intros e t n. generalize dependent t.
  unfold CEK.inj. unfold CESK.inj.
  induction n as [| n']; intros s H.
  Case "n = 0".
    expr_cases (destruct e) SCase;
      (eapply ex_intro;
       split; [apply step_0 |
               inversion H; subst; auto]).
  Case "n = S n'".
    expr_cases (destruct e) SCase.
    SCase "e_var".
      Admitted.
