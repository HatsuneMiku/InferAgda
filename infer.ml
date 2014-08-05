(* �Ķ����ѿ� key ���ͤ� value �Ǥ��뤳�Ȥ��ݻ�����ơ��֥� *)

(* key �����Ĥ���ʤ��ä��Ȥ��� raise ������㳰 *)
exception UnboundVariable of string
(* ���δĶ� *)
let empty_env = []


(* �Ķ� env �� (key, value) ��ä��� *)
let add env key value = (key, value) :: env

(* �Ķ� env ���� key ���б������ͤ���Ф� *)
let rec get env key = match env with
    [] -> raise (UnboundVariable key)
  | (first_key, first_value) :: rest ->
	if key = first_key then first_value
			   else get rest key

(* �� *)
type t = Int | Fun of t * t | Type_Var of t option ref | Boolean

(* Type.gen_type : unit -> t *)
let gen_type () = Type_Var (ref None)

(* �����������ϡ���̵���˷׻� *)
type untyped_t = Var of string
	       | Lam of string * untyped_t
	       | App of untyped_t * untyped_t
	       | Num of int
	       | Bool of bool
	       | If of untyped_t * untyped_t * untyped_t
	       | Let of string * untyped_t * untyped_t
(* �������ν��ϡ����դ��˷׻� *)
type typed_t = TVar of string
	     | TLam of string * t * typed_t
	     | TApp of typed_t * typed_t
	     | TNum of int
	     | TBool of bool
	     | TIf of typed_t * typed_t * typed_t
	     | TLet of string * t * typed_t * typed_t
exception Unify of t * t
exception Error of t * t

(* ���ѿ�����Ȥ��֤������롣�֤äƤ��뷿�ˤϷ��ѿ��ϴޤޤ�ʤ� *)
(* deref_type : t -> t *)
let rec deref_type t = match t with
    Int -> Int
  | Boolean -> Boolean
  | Fun (ts, t') -> Fun(deref_type ts, deref_type t')
  | Type_Var (r) -> match !r with
			None -> r := Some (Int);
				     Int
		      | Some (t') -> let t'' = deref_type t' in
				     r := Some (t'');
				     t''
		      

(* (�ѿ�, ��) �η��� deref ���� *)
(* deref_id_type : (string * t) -> (string * t) *)
let rec deref_id_type (x, t) = (x, deref_type t)

(* ��ˤǤƤ��뷿�� deref ���� *)
(* deref_term : typed_t -> typed_t *)
let rec deref_term expr = match expr with
  | TNum (n) -> TNum (n)
  | TVar (name) -> TVar (name)
  | TLam (xt, e1, e2) -> TLam (xt, deref_type e1, e2)
  | TApp (e, es) -> expr
  | TIf (t,t1,t2) -> expr
  | TLet (s,t,e1,e2) -> expr
  | TBool (b) -> expr

(* r ���� t �˸���뤫������å����� (occur check) *)
(* occur : t option ref -> t -> bool *)
let rec occur r t = match t with
    Int -> false
  | Boolean -> false
  | Fun (ts, t') -> (occur r) ts || occur r t'
  | Type_Var(r') ->
      if r == r' then true else
	match !r' with
	    None -> false
	  | Some (t') -> occur r t'

(* t1 = t2 �Ȥʤ�褦�ˡ����ѿ��ؤ������򤹤� *)
(* unify : t -> t -> unit *)
let rec unify t1 t2 = match (t1, t2) with
    (Int, Int) -> ()
  | (Fun(t1s, t1'), Fun(t2s, t2')) ->
      (try unify t1s t2s with
         Invalid_argument ("List") -> raise (Unify (t1, t2)));
      unify t1' t2'
  | (Type_Var(r1), Type_Var(r2)) when r1 == r2 -> ()
  | (Boolean, Boolean) -> ()
  | Type_Var({ contents = Some(t1') }), _ -> unify t1' t2
  | _, Type_Var({ contents = Some(t2') }) -> unify t1 t2'
  | (Type_Var(r1), _) ->
      (match !r1 with
	  None -> if occur r1 t2 then raise (Unify (t1, t2))
				 else r1 := Some (t2)
	| Some (t1') -> unify t1' t2)
  | (_, Type_Var(r2)) ->
      (match !r2 with
	  None -> if occur r2 t1 then raise (Unify (t1, t2))
				 else r2 := Some (t1)
	| Some (t2') -> unify t1 t2')
  | (_, _) -> raise (Unify (t1, t2))



(* ������ *)
(* infer : untyped_t -> (string * t) list -> typed_t * t *)
let rec infer untyped env = try (match untyped with
   | Num(n) -> (TNum(n), Int)
   | Var(t) -> (TVar(t), get env t)
   | App(e1,e2) -> 
     let (e1',t1) = infer e1 env in
     let (e2',t2) = infer e2 env in
     let a = gen_type() in 
     unify t1 (Fun(t2,a));
     (TApp(e1',e2'), a)	
   | Lam (name, e) -> let t' = gen_type() in
		      let env' = add env name t' in
		      let (e', t) = infer e env' in
		      (TLam(name, t', e'), Fun(t',t)) 
   | If (t, t1, t2) -> 
      let (e ,t') = infer t env in
      unify t' Boolean ;
      let (e1,t1') = infer t1 env in
      let (e2,t2') = infer t2 env in
      unify t1' t2';
      (TIf(e , e1, e2), t2')
   | Let(s ,e1 ,e2) -> 
		       let (e1',t1) = infer e1 env in
		       let env' =  add env s t1 in
		       let (e2',t2) = infer e2 env' in
		       (TLet(s, t1, e1', e2'), t2)
   | Bool(b) -> (TBool(b),Boolean))
			   
			    with Unify (t1, t2) ->
			      raise (Error (deref_type t1, deref_type t2))
			      

let test1 = Lam("f",App(Var("f"),Num(3)))
let test2 = Lam("x",Var("x"))
let test3 = If(Bool(true),Let("x",Num(3),Var("x")),App(test1,test2))
(* 
  Agda �ǽ񤯾��
1. �����Ѥ�����
2. store passing
  Unification ���񤱤ʤ� -> termination ������
 *)
