open List

(* syntax *)
type ident = string

type typ = Tint | Tclass of ident
type exp = Int of int | Add of exp * exp | Mul of exp * exp | Var of ident
         | GetField of exp * ident

type cmd = Assign of ident * exp | Seq of cmd * cmd | Skip
           | New of ident * ident * exp list | SetField of exp * ident * exp
           | Invoke of ident * exp * ident * exp list | Return of exp
           | IfC of exp * cmd * cmd


type mdecl = MDecl of typ * ident * (typ * ident) list * cmd

type cdecl = Class of ident * ident * (typ * ident) list * mdecl list

(* values and states *)
type class_table = ident -> cdecl option
                 
type ref = int
type value = IntV of int | RefV of ref
type obj = Obj of ident * value list

type env = ident -> value option
type store = (ref -> obj option) * ref
let empty_state = fun x -> None
let update s x v = fun y -> if y = x then Some v else s y

let empty_store : store = (empty_state, 0)
let store_lookup (s : store) = fst s
let next_ref (s : store) = snd s
let update_store (s : store) (r : ref) (o : obj) : store = (update (store_lookup s) r o, next_ref s)

(* field and method lookup *)
let rec fields (ct : class_table) (c : ident) : (typ * ident) list =
  if c = "Object" then [] else
    match ct c with
    | Some (Class (_, d, lf, _)) -> fields ct d @ lf
    | _ -> []

let rec field_index_aux (l : (typ * ident) list) (f : ident) (n : int) =
  match l with
  | [] -> None
  | (_, g) :: rest ->
     if f = g then Some n else field_index_aux rest f (n - 1)

let field_index ct c f =
  field_index_aux (rev (fields ct c)) f (length (fields ct c) - 1)

let rec methods (ct : class_table) (c : ident) : mdecl list =
  if c = "Object" then [] else
    match ct c with
    | Some (Class (_, d, _, lm)) -> methods ct d @ lm
    | _ -> []

let lookup_method_aux (l : mdecl list) (m : ident) : mdecl option =
  find_opt (fun d -> match d with MDecl (_, n, _, _) -> n = m) l

let lookup_method ct c m =
  lookup_method_aux (rev (methods ct c)) m
  
let replace l pos a  = mapi (fun i x -> if i = pos then a else x) l
  
(* evaluating expressions (based on big-step rules) *)
let rec eval_exp (ct : class_table) (e : exp) (r : env) (s : store)
        : value option =
  match e with
  | Var x -> r x
  | Int i -> Some (IntV i)
  | Add (e1, e2) ->
     (match eval_exp ct e1 r s, eval_exp ct e2 r s with
      | Some (IntV i1), Some (IntV i2) -> Some (IntV (i1 + i2))
      | _, _ -> None)
  | Mul (e1, e2) ->
     (match eval_exp ct e1 r s, eval_exp ct e2 r s with
      | Some (IntV i1), Some (IntV i2) -> Some (IntV (i1 * i2))
      | _, _ -> None)
  | GetField (e, f) ->
     (match eval_exp ct e r s with
      | Some (RefV p) ->
         (match store_lookup s p with
          | Some (Obj (c, lv)) ->
             (match field_index ct c f with
              | Some i -> nth_opt lv i
              | None -> None)
          | _ -> None)
      | _ -> None)

let rec eval_exps (ct : class_table) (le : exp list) (r : env) (s : store)
        : value list option =
  match le with
  | [] -> Some []
  | e :: rest ->
     (match eval_exp ct e r s, eval_exps ct rest r s with
      | Some v, Some lv -> Some (v :: lv)
      | _, _ -> None)
(*
  match li with
  | [] -> empty_state
  | hd :: tl -> 
hd :: tl -> update (make_env li lv) hd (IntV 1)
update (make_env li lv) hd (List.combine li lv)

#use "hw#4.ml";;

combine ["u";"v";"x";"y";"z"] [6;7;8;9;10];;

works:
| hd :: tl -> update (make_env tl lv) hd (IntV 1)
*)
let rec make_env (li : ident list) (vl : value list) : env = 
 match li, vl with
  | [], [] -> empty_state
  | ((_::_, [])|([], _::_)) -> empty_state
  | (a1::li, a2::vl) -> update(make_env li vl) a1 a2
    
let ct1 d = if d = "Shape" then
              Some (Class ("Shape", "Object", [(Tint, "id")],
                           [MDecl (Tint, "area", [],
                                   Return (Int 0))]))
            else if d = "Square" then
              Some (Class ("Square", "Shape", [(Tint, "side")],
                           [MDecl (Tint, "area", [],
                                   Seq (Assign ("x", GetField (Var "this", "side")),
                                        Return (Mul (Var "x", Var "x"))))]))
            else None

(* evaluating commands (based on small-step rules*)          
type stack = (env * ident) list          
type config = cmd * stack * env * store


let rec step_cmd (ct : class_table) (c : cmd) (k : stack) (r : env) (s : store)
        : config option =
  match c with
  | Assign (x, e) ->
     (match eval_exp ct e r s with
      | Some v -> Some (Skip, k, update r x v, s)
      | None -> None)
  | Seq (Skip, c2) -> Some (c2, k, r, s)
  | Seq (c1, c2) ->
     (match step_cmd ct c1 k r s with
      | Some (c1', k', r', s') -> Some (Seq (c1', c2), k', r', s')
      | None -> None)
  | Skip -> None 
  | IfC (e, c1, c2) -> 
    (match eval_exp ct e r s with
      | Some (IntV 0) -> Some (c2, k, r, s)
      | Some v -> if v != IntV 0 then Some (c1, k, r, s) else None
      | _ -> None)
  | New (x, c, args) ->
     (match eval_exps ct args r s with
      | Some lv ->
         let p = next_ref s in
         Some (Skip, k, update r x (RefV p),
               (update (store_lookup s) p (Obj (c, lv)), p + 1))
      | None -> None)
  | SetField (e, f, e1) ->
     (match eval_exp ct e r s, eval_exp ct e1 r s with
      | Some (RefV p), Some v ->
         (match store_lookup s p with
          | Some (Obj (c, lv)) ->
             (match field_index ct c f with
              | Some i -> Some (Skip, k, r, update_store s p (Obj (c, replace lv i v)))
              | None -> None)
          | None -> None)
      | _, _ -> None)
  | _ -> None 
  | Invoke (x,e,m,args) ->
      (match eval_exp ct e r s with 
        Some (RefV p) ->
          (match store_lookup s p with
            | Some (Obj (c, lv)) ->
              (match eval_exps ct args r s with 
                Some lv -> 
                (match lookup_method ct c m with
                  | Some i -> Some (Skip, k, update r x (RefV p), (update (store_lookup s) p (Obj (c, lv)), p + 1))
                  | None -> None
                  )
                | None -> None  )
            | None -> None   )
        | Some IntV i -> None
        | None -> None)
  | Return (e) ->
    (match eval_exp ct e r s with 
      Some v -> 
        let (p,x) = next_ref s , "x" in
        Some (Skip, k , update r x v, s)
      |None -> None)

let rec run_config (ct : class_table) (con : config) : config =
  let (c, k, r, s) = con in
  match step_cmd ct c k r s with
  | Some con' -> run_config ct con'
  | None -> con

let run_prog (ct : class_table) (c : cmd) =
  run_config ct (c, [], empty_state, empty_store)

(* test cases *)  
let test0 : cmd =
  Seq (New ("s", "Square", [Int 0; Int 2]),
       (* s = new Square(0, 2); *)
       SetField (Var "s", "side", Add (GetField (Var "s", "side"), Int 1)))
       (* s.side = s.side + 1; *)

let test1 : cmd =
  Seq (Assign ("x", Int 1),
       IfC (Var "x", Assign ("x", Int 2), Assign ("x", Int 3)))
  
let test2 : cmd =
  Seq (New ("s", "Shape", [Int 2]),
       (* s = new Shape(2); *)
       Invoke ("x", Var "s", "area", []))
       (* x = s.area(); *)

let test3 : cmd =
  Seq (New ("s", "Square", [Int 0; Int 2]),
       (* s = new Square(0, 2); *)
  Seq (SetField (Var "s", "side", Add (GetField (Var "s", "side"), Int 1)),
       (* s.side = s.side + 1; *)
       Invoke ("x", Var "s", "area", [])))
       (* x = s.area(); *)

(*
#use "hw#4.ml";;
make_env [] [];;
make_env ["a"] [IntV 1];;

make_env ["x";"y"] [IntV 0;IntV 1];;

make_env ["x"; "y"; "z"] [IntV 0; IntV 1; IntV 2];; 
*)



