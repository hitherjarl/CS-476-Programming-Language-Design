(*
* Name: Mohamed Imran Mohamed Siddique
* netID: isiddi5
* Email: isiddi5@uic.edu
*)

type ast_A = String of string | Lets of ast_A * ast_A | Fun of string * ast_A;;

type ast_D = Let of string * ast_A | Rec of string * ast_A;;

let tree1 : ast_D = Let ("y", Fun ("f", Fun ("f", Lets (String "x", String "f"))));;

let rec count_funs (d : ast_D) : int = 
	match d with 
		| Let (_,d1) -> 
			(match d1 with
				| Lets (_,_) -> 0 
				| Fun (_,d2) ->  1 + count_funs d)

let count_id (s : string) (d : ast_D) = 
	match s with 
		| s -> 
			(match d with
				| Let(_,r) -> 
					(match r with
						| Fun (s,_) -> 1 + count_id s d))


type exp = Int of int | Add of exp * exp | Sub of exp * exp
         | Bool of bool | And of exp * exp | Or of exp * exp
         | Eq of exp * exp | If of exp * exp * exp

type typ = Tint | Tbool


let rec typecheck (e : exp) (t : typ) =
match e with
	| Int e -> 
 		(match t with 
 			| Tint -> true
 			| Tbool -> false)
 	| Bool y -> 
 		(match t with 
 			| Tint -> false
 			| Tbool -> true)
 	| Add(e1, e2) ->
		(match e1, e2 with
			| e1, e2 -> typecheck e1 t = typecheck e2 t &&
				(match t with 
					| Tint -> true
					| Tbool -> false))
	| Sub (e1, e2) ->
		(match e1, e2 with
			| e1, e2 -> typecheck e1 t = typecheck e2 t &&
				(match t with 
					| Tint -> true
					| Tbool -> false))
	| And (e1, e2) ->
		(match e1, e2 with
			| e1, e2 -> typecheck e1 t = typecheck e2 t &&
				(match t with 
					| Tint -> false
					| Tbool -> true))
	| Or (e1, e2) ->
		(match e1, e2 with
			| e1, e2 -> typecheck e1 t = typecheck e2 t &&
				(match t with 
					| Tint -> false
					| Tbool -> true))
	| Eq (e1, e2) ->
		(match e1, e2 with
			| e1, e2 -> typecheck e1 t = typecheck e2 t &&
				(match t with 
					| Tint -> false
					| Tbool -> true))
	| If (e1, e2, e3) ->
		(match e1, e2, e3 with
			| e1, e2, e3 -> typecheck e1 t = typecheck e2 t = typecheck e3 t &&
				(match t with 
					| Tint -> false
					| Tbool -> true))

				
