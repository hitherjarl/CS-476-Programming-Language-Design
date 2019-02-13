(*This is the second problem*)
let rec sum list =
  	  match list with
  	    Nil -> 0
  	  | Cons(head,tail) -> head + sum tail
  	;;

(*This is the first problem*)
let rec is_nil list =
  	  match list with
              Nil -> true
 	  | Cons(_,_) -> false
  	;;

(*This is the third problem*)  
(*First type*) type intlist = Nil | Cons of int * intlist;;
(*Then the type with 2 constructors*) type int_or_list = Int of int | List of intlist;;
(*Then the function itself*)

let rec is_pos = function
	  Int 0 -> false
	 |Int i -> true
	 |List Nil -> false
	 |List Cons (_,Nil) -> true;;

