(* elpi: embedded lambda prolog interpreter                                  *)
(* license: GNU Lesser General Public License Version 2.1 or later           *)
(* ------------------------------------------------------------------------- *)

(** This module is the API for clients of the ELPI library.
    
    The modules {!module:Setup}, {!module:Parse}, {!module:Compile} and
    {!module:Execute} let one run code, and {!module:Pp} print the result.
    Modules {!module:Ast} and {!module:Data} mostly contain opaque data types
    declarations.

    The sub module {!module:Extend} groups the APIs to extend ELPI.
    It provides richer {!module:Ast} and {!module:Data} submodules where the
    data types are made transparent.
    Module {!module:Extend.Compile} lets one register new \{\{quotations\}\}.
    Modules {!module:Extend.BuiltInPredicate} and
    {!module:Extend.CustomState} let one register built-in predicates and
    custom state. *)

(* ************************************************************************* *)
(* *************************** Basic API *********************************** *)
(* ************************************************************************* *)

module Ast : sig
  type program
  type query

  module Loc : sig
    type t = {
      source_name : string;
      source_start: int;
      source_stop: int;
      line: int;
      line_starts_at: int;
    }
    val pp : Format.formatter -> t -> unit
    val show : t -> string
    val equal : t -> t -> bool
    val compare : t -> t -> int

    val initial : string -> t
  end
end

module Setup : sig

  (* Built-in predicates, see {!module:Extend.BuiltInPredicate} *)
  type builtins
  type program_header

  (** Initialize ELPI.
      [init] must be called before invoking the parser.
      [builtins] the set of built-in predicates, eg [Elpi_builtin.std_builtins] 
      [basedir] current working directory (used to make paths absolute);
      [argv] is list of options, see the {!val:usage} string;
      It returns part of [argv] not relevant to ELPI and a [program_header]
      that contains the declaration of builtins. *)
  val init :
    builtins:builtins ->
    basedir:string ->
    string list -> program_header * string list

  (** Usage string *)
  val usage : string

  (** Set tracing options.
      [trace argv] can be called before {!module:Execute}.
      [argv] is expected to only contain options relevant for
      the tracing facility. *)
  val trace : string list -> unit

  (** Override default error functions (they call exit) *)
  val set_warn : (?loc:Ast.Loc.t -> string -> unit) -> unit
  val set_error : (?loc:Ast.Loc.t -> string -> 'a) -> unit
  val set_anomaly : (?loc:Ast.Loc.t -> string -> 'a) -> unit
  val set_type_error : (?loc:Ast.Loc.t -> string -> 'a) -> unit
  val set_std_formatter : Format.formatter -> unit
  val set_err_formatter : Format.formatter -> unit
end

module Parse : sig

  (** [program file_list] parses a list of files *)
  val program : ?print_accumulated_files:bool ->
    string list -> Ast.program
  val program_from_stream : ?print_accumulated_files:bool ->
    Ast.Loc.t -> char Stream.t -> Ast.program

  (** [goal file_list] parses the query *)
  val goal : Ast.Loc.t -> string -> Ast.query
  val goal_from_stream : Ast.Loc.t -> char Stream.t -> Ast.query

  exception ParseError of Ast.Loc.t * string
end

module Data : sig
  
  module StrMap : sig
   include Map.S with type key = string
   val show : (Format.formatter -> 'a -> unit) -> 'a t -> string
   val pp : (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a t -> unit
  end

  (* what is assigned to the query variables *)
  type term

  (* goals suspended via the declare_constraint built-in *)
  type constraints

  (* user defined state (not goals) *)
  type state

  (* a solution is an assignment map from query variables (name) to terms,
   * plus the goals that were suspended and the user defined constraints *)
  type solution = {
    assignments : term StrMap.t;
    constraints : constraints;
    state : state;
  }

end

module Compile : sig

  module StrSet : sig
   include Set.S with type elt = string
   val show : t -> string
   val pp : Format.formatter -> t -> unit
  end

  type flags = {
    (* variables used in conditional compilation, that is :if clauses *)
    defined_variables : StrSet.t;
    (* disable check that all built-in must come with a type declaration *)
    allow_untyped_builtin : bool;
    (* debug: print intermediate data during the compilation phase *)
    print_passes : bool;
  }
  val default_flags : flags

  type program
  type query
  type executable

  (* Warning: this API will change to support separate compilation of
   * Ast.program, esp the [link] one *)

  (* compile all program files *)
  val program : flags:flags ->
    Setup.program_header -> Ast.program list -> program

  (* then compile the query *)
  val query : program -> Ast.query -> query

  (* finally obtain the executable *)
  val link : query -> executable

  (** Runs [elpi-checker.elpi] by default.
      Returns true if no errors were found *)
  val static_check :
    Setup.program_header -> ?checker:Ast.program list -> ?flags:flags -> query -> bool

  (** HACK: don't use *)
  val dummy_header : Setup.program_header

end

module Execute : sig

  type outcome = Success of Data.solution | Failure | NoMoreSteps

  (* Returns the first solution, if any, within the optional steps bound.
   * Setting delay_outside_fragment (false by default) results in unification
   * outside the pattern fragment to be delayed (behavior of Teyjus), rather
   * than abort the execution (default behavior) *)
  val once : ?max_steps:int -> ?delay_outside_fragment:bool ->
    Compile.executable -> outcome

  (** Prolog's REPL.
    [pp] is called on all solutions.
    [more] is called to know if another solution has to be searched for. *)
  val loop :
    ?delay_outside_fragment:bool -> 
    Compile.executable ->
    more:(unit -> bool) -> pp:(float -> outcome -> unit) -> unit
end

module Pp : sig

  val term : Format.formatter -> Data.term -> unit
  val constraints : Format.formatter -> Data.constraints -> unit
  val state : Format.formatter -> Data.state -> unit
  val query : Format.formatter -> Compile.query -> unit

  module Ast : sig
    val program : Format.formatter -> Ast.program -> unit
  end

end

(* ************************************************************************* *)
(* ************************* Extension API ********************************* *)
(* ************************************************************************* *)

module Extend : sig

  (** Data of the host program that is opaque to Elpi. *)
  module CData : sig
    type t

    (** The [eq] function is used by unification. Limitation: unification of
     * two cdata cannot alter the constraint store. This can be lifted in the
     * future if there is user request.
     *
     * If the data_hconsed is true, then the [cin] function below will
     * automatically hashcons the data using the [eq] and [hash] functions.
     *)
    type 'a data_declaration = {
      data_name : string;
      data_pp : Format.formatter -> 'a -> unit;
      data_eq : 'a -> 'a -> bool;
      data_hash : 'a -> int;
      data_hconsed : bool;
    }

    type 'a cdata = private {
      cin : 'a -> t;
      isc : t -> bool;
      cout: t -> 'a;
      name : string;
    }

    val declare : 'a data_declaration -> 'a cdata

    val pp : Format.formatter -> t -> unit
    val show : t -> string
    val equal : t -> t -> bool
    val hash : t -> int
    val name : t -> string
    val hcons : t -> t

    (* tests if two cdata have the same given type *)
    val ty2 : 'a cdata -> t -> t -> bool
    val morph1 : 'a cdata -> ('a -> 'a) -> t -> t
    val morph2 : 'a cdata -> ('a -> 'a -> 'a) -> t -> t -> t
    val map : 'a cdata -> 'b cdata -> ('a -> 'b) -> t -> t
  end

  (* State is a collection of purely functional piece of data carried
   * by the interpreter. Such data is kept in sync with the backtracking, i.e.
   * changes made in a branch are lost if that branch fails.
   * It can be used to both store custom constraints to be manipulated by
   * custom solvers, or any other piece of data the host application may
   * need to use.
   * The initial value can be taken from the compiler state, e.g. a quotation
   * may generate some constraints statically *)
  module State : sig

    (** 'a MUST be purely functional, i.e. backtracking is implemented by using
     * an old binding for 'a.
     * This limitation can be lifted if there is user request. *)
    type 'a component

    (** The compilation_is_over callback is called when the compilation
        phase is over, after that the state is threaded at run time *)
    val declare :
      name:string ->
      pp:(Format.formatter -> 'a -> unit) ->
      init:(unit -> 'a) ->
        'a component

    type t = Data.state

    val get : 'a component -> t -> 'a
    val set : 'a component -> t -> 'a -> t

    (** Allowed to raise BuiltInPredicate.No_clause *)
    val update : 'a component -> t -> ('a -> 'a) -> t
    val update_return : 'a component -> t -> ('a -> 'a * 'b) -> t * 'b

    (* to map uvars from/to the host application *)

    module UVKey : sig
      type t
      val make : ?name:string -> lvl:int -> Data.state -> Data.state * t
      val get : name:string -> Data.state -> t option
      val pp :  Format.formatter -> t -> unit
      val show :  t -> string
      val equal : t -> t -> bool
    end

    module type HostUVar = sig
      type t
      val compare : t -> t -> int
      val pp : Format.formatter -> t -> unit
      val show : t -> string
    end

    (* Bijective map between elpi UVar and host equivalent *)
    module UVMap : functor(T : HostUVar) -> sig
      type t

      val empty : t
      val add : UVKey.t -> T.t -> t -> t

      val remove_elpi : UVKey.t -> t -> t
      val remove_host : T.t -> t -> t

      val filter : (T.t -> UVKey.t -> bool) -> t -> t

      (* The eventual body at its depth *)
      val fold : (T.t -> UVKey.t -> (int * Data.term) option -> 'a -> 'a) -> t -> 'a -> 'a

      val elpi   : T.t -> t -> UVKey.t
      val host : UVKey.t -> t -> T.t

      val uvmap : t component

      val pp : Format.formatter -> t -> unit
      val show : t -> string
    end

  end


  (** This module exposes the low level representation of terms.
   *
   * The data type [term] is opaque and can only be accessed by using the
   * [look] API that exposes a term [view]. The [look] view automatically
   * substitutes assigned unification variables by their value. The [UVar]
   * and [AppUVar] node hence stand for unassigned unification variables. *)
  module Data : sig

    type constant = int (** De Bruijn levels (not indexes):
                            the distance of the binder from the root.
                            Starts at 0 and grows for bound variables;
                            global constants have negative values. *)
    type builtin
    type uvar_body (* unification variable (missing) body, use == only *)
    type term
    type view = private
      (* Pure subterms *)
      | Const of constant                   (* global constant or a bound var *)
      | Lam of term                         (* lambda abstraction, i.e. x\ *)
      | App of constant * term * term list  (* application (at least 1 arg) *)
      (* Optimizations *)
      | Cons of term * term                 (* :: *)
      | Nil                                 (* [] *)
      | Discard                             (* _  *)
      (* FFI *)
      | Builtin of builtin * term list      (* call to a built-in predicate *)
      | CData of CData.t                    (* external data *)
      (* Unassigned unification variables *)
      | UnifVar of State.UVKey.t * term list

    (** Smart constructors *)
    val mkGlobalS : string -> term  (* global constant, i.e. < 0 *)
    val mkBound : constant -> term  (* bound variable, i.e. >= 0 *)
    val mkLam : term -> term
    val mkAppS : string -> term -> term list -> term
    val mkAppSL : string -> term list -> term
    val mkCons : term -> term -> term
    val mkNil : term
    val mkDiscard : term
    val mkBuiltinS : string -> term list -> term
    val mkCData : CData.t -> term
    val mkUnifVar : State.UVKey.t -> args:term list -> State.t -> term

    (** Lower level smart constructors *)
    val mkGlobal : constant -> term (* global constant, i.e. < 0 *)
    val mkApp : constant -> term -> term list -> term
    val mkAppL : constant -> term list -> term
    val mkBuiltin : builtin -> term list -> term
    val mkConst : constant -> term (* no check, works for globals and bound *)

    (** Terms must be inspected after dereferencing their head.
        If the resulting term is UVar then its uvar_body is such that
        get_assignment uvar_body = None *)
    val look : depth:int -> term -> view

    (* to reuse a term that was looked at *)
    val kool : view -> term

    type clause_src = {
      hdepth : int;
      hsrc : term
    }
    type hyps = clause_src list
    type suspended_goal = {
      context : hyps;
      goal : int * term
    }

    (* Alias/cast from Data *)
    val of_term : Data.term -> term
    type constraints = Data.constraints
    module StrMap = Data.StrMap
    val constraints : Data.constraints -> suspended_goal list
    val no_constraints : constraints

    (** LambdaProlog built-in data types *)
    module C : sig
      val int : int CData.cdata
      val is_int : CData.t -> bool
      val to_int : CData.t -> int
      val of_int : int -> term
    
      val float : float CData.cdata
      val is_float : CData.t -> bool
      val to_float : CData.t -> float
      val of_float : float -> term
    
      val string : string CData.cdata
      val is_string : CData.t -> bool
      val to_string : CData.t -> string
      val of_string : string -> term

      (* This is elpi specific *)
      val loc : Ast.Loc.t CData.cdata
      val is_loc : CData.t -> bool
      val to_loc : CData.t -> Ast.Loc.t
      val of_loc : Ast.Loc.t -> term
    end

    (** LambdaProlog built-in global constants *)
    module Constants :
     sig
      val from_string : string -> term
      val from_stringc : string -> constant
     
      val show : constant -> string

      val eqc    : constant (* = *)
      val orc    : constant (* ; *)
      val andc   : constant (* , *)
      val andc2  : constant (* & *)
      val rimplc : constant (* :- *)
      val pic    : constant (* pi *)
      val sigmac : constant (* sigma *)
      val implc  : constant (* => *)
      val cutc   : constant (* ! *)

      (* LambdaProlog built-in data types are just instances of CData.
       * Still the parser translated the type [int], [float] and [string]
       * to [ctype "int"], [ctype "float"] and [ctype "string"]. *)
      val ctypec : constant (* ctype *)

      (* Marker for spilling function calls, as in [{ rev L }] *)
      val spillc : constant
    
      module Map : Map.S with type key = constant
      module Set : Set.S with type elt = constant
    end
    
  end

  (* Built-in predicates are implemented in ML using the following FFI.
   *
   * The ffi data type uses GADTs to let one describe the type of an OCaml
   * function. Terms passed to the built-in predicate are then checked against
   * and converted to their types before being passed to the OCaml code.
   * The ffi data type is also used to generate the documentation of the
   * built-in (Elpi code with comments).
   *
   * Example: built-in "div" taking two int and returning their division and
   * remainder.
   *
   *   Pred("div",
   *        In(int, "N",
   *        In(int, "M",
   *        Out(int, "D",
   *        Out(int, "R",
   *          Easy "division of N by M gives D with reminder R")))),
   *        (fun n m _ _ -> !: (n div m) +! (n mod n)))
   *
   *   In( type, documentation, ... ) declares an input of a given type.
   *     In the example above both "n" and "m" are declare as input, and
   *     as expected the OCaml code receives two inputs (n and m) of type
   *     int
   *   Out( type, documentation, ...) declares an input/output argument.
   *     The OCaml code receives an "int arg" (and not just an int).
   *     We will detail this later, for now lets ignore that.
   *   Easy( documentation ) just signals that the built-in does not alter the
   *     store of custom constraints
   *
   *   The OCaml code has to produce a tuple of outputs, the convenience
   *   notations "!: x" and "x +! y" should be used to produce, respectively,
   *   the first output and any extra one ("!:" begins the list, "+!" continues
   *   it). In the example two outputs (division and reminder) are produced.
   *
   *   In the ffi declaration above "int" is of type "int data" that is a
   *   record containing functions to inject/eject integers into terms.
   *   The function to eject (of_term) does not return an "int" but an
   *   "int arg"  where "'a arg" can be one of
   *     Data of 'a | Flex of term | Discard
   *   For arguments that are described as In in the ffi, only the first
   *   constructor is allowed (i.e. if the user passes a term that is ejected
   *   as Flex or Discard a (fatal, run-time) type error is raised).
   *   For arguments described as Out all 3 cases are valid.
   *
   *   Now let's go back to the two arguments the OCaml code discards.
   *   They are of type "int arg" as a consequence the OCaml code is
   *   made aware of the user passed. For example
   *     div 4 2 D _
   *   would result in the OCaml code being passed: 4, 2, Flex, Discard.
   *   In such a way the code can decide to not even produce the second
   *   output, since it is not requested (not very useful in this specific
   *   case). The notations "?:" and "+?" are like "!:" and "+!" but their
   *   argument is of type option, so one can output None in response to a
   *   Discard.
   *
   *   The FFI unifies the outputs produces by the OCaml code with the
   *   terms provided by the user. It is always correct to produce all
   *   outputs (and ignore the corresponding arguments in OCaml).
   * *)
  module BuiltInPredicate : sig

    exception No_clause (* signals logical Failure, i.e. demands backtrack *)

    type name = string
    type doc = string
    
    type ty_ast = TyName of string | TyApp of string * ty_ast * ty_ast list

    type 'a oarg = Keep | Discard
    type 'a ioarg = Data of 'a | NoData

    type extra_goals = Data.term list

    type 'a embedding =
      depth:int -> Data.hyps -> Data.constraints ->
      State.t -> 'a -> State.t * Data.term * extra_goals (* XXX depth!!! *)
      
    type 'a readback =
      depth:int -> Data.hyps -> Data.constraints ->
      State.t -> Data.term -> State.t * 'a

    type 'a data = {
      ty : ty_ast;
      pp_doc : Format.formatter -> unit -> unit;
      embed : 'a embedding;   (* 'a -> term *)
      readback : 'a readback; (* term -> 'a *)
    }

    exception TypeErr of ty_ast * Data.term (* a type error at data conversion time *)
    
    type ('function_type, 'inernal_outtype_in) ffi =
      | In   : 't data * doc * ('i, 'o) ffi -> ('t -> 'i,'o) ffi
      | Out  : 't data * doc * ('i, 'o * 't option) ffi -> ('t oarg -> 'i,'o) ffi
      | InOut  : 't data * doc * ('i, 'o * 't option) ffi -> ('t ioarg -> 'i,'o) ffi
      | Easy : doc -> (depth:int -> 'o, 'o) ffi
      | Read : doc -> (depth:int -> Data.hyps -> Data.constraints -> Data.state -> 'o, 'o) ffi
      | Full : doc -> (depth:int -> Data.hyps -> Data.constraints -> Data.state -> Data.state * 'o, 'o) ffi
      | VariadicIn : 't data * doc -> ('t list -> depth:int -> Data.hyps -> Data.constraints -> Data.state -> Data.state * 'o, 'o) ffi
      | VariadicOut : 't data * doc -> ('t oarg list -> depth:int -> Data.hyps -> Data.constraints -> Data.state -> Data.state * ('o * 't option list option), 'o) ffi
      | VariadicInOut : 't data * doc -> ('t ioarg list -> depth:int -> Data.hyps -> Data.constraints -> Data.state -> Data.state * ('o * 't option list option), 'o) ffi

    type t = Pred : name * ('a,unit) ffi * 'a -> t


    (** Commodity API for representing simple ADT: no binders!
     *
     *  Example of: pred getenv i:string, o:option string.
     *  
     * (* define the ADT for "option a" *)
     * let option_adt a = {
     *   ty = TyApp("option",a.ty,[]);
     *   doc = "The option type (aka Maybe)";
     *   constructors = [
     *
     *     K("none","nothing in this case",
     *       N,                                               (* no arguments *)
     *       None,                                            (* builder *)
     *       (fun ~ok ~ko -> function None -> ok | _ -> ko)); (* matcher *)

     *     K("some","something in this case",
     *       A(a,N),                               (* one argument of type a *)
     *       (fun x -> Some x),                                   (* builder *)
     *       (fun ~ok ~ko -> function Some x -> ok x | _ -> ko)); (* matcher *)
     *   ]
     * }
     * (* compile the ADT to data types to be used in predicate signatures *)
     * let option a : a data = adt (option_adt a)
     *
     * (* define a predicate using "option" *)
     * let getenv : t =
     *   Pred("getenv",
     *     In(string,         "VarName",
     *     Out(option string, "Value",
     *     Easy "Like Sys.getenv")),
     *     (fun name _ ~depth ->
     *        try !: (Some (Sys.getenv name))
     *        with Not_found -> !: None))
     * *)
    module ADT : sig

    type ('matched, 't) match_t =
      (* continuation to call passing subterms *)
      ok:'matched ->
      (* continuation to call to signal pattern matching failure *)
      ko:(Data.state -> Data.state * Data.term * extra_goals) ->
      (* match 't and pass its subterms to ~ok or just call ~ko *)
      't -> Data.state -> Data.state * Data.term * extra_goals

    type ('builder, 'matcher,  'self) constructor_arguments =
      (* No arguments *)
      | N : ('self, Data.state -> Data.state * Data.term * extra_goals, 'self) constructor_arguments
      (* An argument of type 'a *)
      | A : 'a data * ('b, 'm, 'self) constructor_arguments -> ('a -> 'b, 'a -> 'm, 'self) constructor_arguments
      (* An argument of type 'self *)
      | S : ('b, 'm, 'self) constructor_arguments -> ('self -> 'b, 'self -> 'm, 'self) constructor_arguments
      (* An argument of type `T 'self` for a constainer `T`, like a `list 'self`.
         `S args` above is a shortcut for `C(fun x -> x, args)` *)
      | C : ('self data -> 'a data) * ('b,'m,'self) constructor_arguments -> ('a -> 'b, 'a -> 'm, 'self) constructor_arguments
    
    type 't constructor =
      K : name * doc *
          ('build_t,'matched_t,'t) constructor_arguments *   (* args ty *)
          'build_t * ('matched_t,'t) match_t                 (* build/match *)
        -> 't constructor

    type 't t = {
      ty : ty_ast;
      doc : doc;
      constructors : 't constructor list;
    }

    end (* ADT *)

    (** Where to print the documentation. For the running example DocAbove
     * generates
     *   % [div N M D R] division of N by M gives D with reminder R
     *   pred div i:int, i:int, o:int, o:int.
     * while DocNext generates
     *   pred div % division of N by M gives D with reminder R
     *    i:int, % N
     *    i:int, % M
     *    o:int, % D
     *    o:int. % R
     * The latter format it is useful to give longer doc for each argument. *)
    type doc_spec = DocAbove | DocNext

    (* When an elpi interpreter is set up one can pass a list of
     * declarations that constitute the base environment in which
     * programs run *)
    type declaration =
    (* Real OCaml code *)
    | MLCode of t * doc_spec
    (* Declaration of an OCaml data *)
    | MLData : 'a data -> declaration
    (* Extra doc *)
    | LPDoc  of string
    (* Sometimes you wrap OCaml code in regular predicates or similar in order
     * to implement the desired builtin, maybe just temporarily because writing
     * LP code is simpler.
     * Note: will be complemented in the future by an LPType/LPPred/LPMode nodes
     * for the specific statements. *)
    | LPCode of string

    (** Type descriptors (see also Elpi_builtin) *)
    val int    : int data
    val float  : float data
    val string : string data
    val list   : 'a data -> 'a list data
    val loc    : Ast.Loc.t data

    (* poly "A" is what one would use for, say, [type eq A -> A -> prop] *)
    val poly   : string -> Data.term data
    (* any is like poly "X" for X fresh *)
    val any    : Data.term data

    (* commodity type description of a CData *)
    val cdata :
      (* name used for type declarations, eg "int" or "in_stream" *)
      name:string ->
      (* To document *)
      ?doc:doc ->
      (* global constants of that type, eg "std_in" *)
      ?constants:'a Data.Constants.Map.t ->
      'a CData.cdata -> 'a data

    (* commodity type description of ADT *)
    val adt : 'a ADT.t -> 'a data

    val map_acc_embed :
      (Data.state -> 'a -> Data.state * Data.term * extra_goals) ->
      Data.state -> 'a list -> Data.state * Data.term list * extra_goals

    val map_acc_readback :
      (Data.state -> Data.term -> Data.state * 'a) ->
      Data.state -> Data.term list -> Data.state * 'a list


    (** Prints in LP syntax the "external" declarations.
     * The file builtin.elpi is generated by calling this API on the
     * declaration list from elpi_builtin.ml *)
    val document : Format.formatter -> declaration list -> unit

    (** What is passed to [Setup.init] *)
    val builtin_of_declaration :
      file_name:string -> declaration list -> Setup.builtins

    module Notation : sig

      (* Handy notation to construct the value generated by built-in predicates.
       *
       * "!" means the output is there, while "?" that it may not be.
       *
       * "?:" and "!:" begin the sequence of outputs, while "+?" and "+!"
       * continue.
       *
       * Eg  !: 3 +! 4 +? None +? (Some 5)           -->
       *     ((((), Some 3), Some 4), None), Some 5
       *)
      val (?:) : 'a -> unit * 'a
      val (!:) : 'a -> unit * 'a option
      val (+?) : 'a -> 'b -> 'a * 'b
      val (+!) : 'a -> 'b -> 'a * 'b option

    end
  end


  (** This module lets one extend the compiler by:
   * - "compiling" the query by hand
   * - providing quotations *)
  module Compile : sig

    (** Generate a query starting from a compiled/hand-made term. The StrMap
        maps names of args (see fresh_Arg below) *)
    val query :
      Compile.program -> (depth:int -> Data.state -> Data.state * (Ast.Loc.t * Data.term)) ->
        Compile.query

    (* Args are parameters of the query (e.g. capital letters). *)
    val is_Arg : Data.state -> Data.term -> bool

    (* The output term is to be used to build the query but is *not* the handle
       to the eventual solution. The compiler transforms it, later on, into
       a UVar. The mapping is passed to the compilation_is_over callback of
       each State.component. *)
    val mk_Arg :
      Data.state -> name:string -> args:Data.term list ->
        Data.state * Data.term

    val while_compiling : bool State.component

    (** From an unparsed string to a term *)
    type quotation =
      depth:int -> Data.state -> Ast.Loc.t -> string -> Data.state * Data.term

    (** The default quotation [{{code}}] *)
    val set_default_quotation : quotation -> unit

    (** Named quotation [{{name:code}}] *)
    val register_named_quotation : name:string -> quotation -> unit

    (** The anti-quotation to lambda Prolog *)
    val lp : quotation


    (** See elpi_quoted_syntax.elpi (EXPERIMENTAL, used by elpi-checker) *)
    val quote_syntax : Compile.query -> Data.term list * Data.term

    (** To implement the string_to_term built-in (AVOID, makes little sense
     * if depth is non zero, since bound variables have no name!) *)
    val term_at : depth:int -> Ast.query -> Data.term
    
  end

  (** Like quotations but for identifiers that begin and end with
   * "`" or "'", e.g. `this` and 'that'. Useful if the object language
   * needs something that looks like a string but with a custom compilation
   * (e.g. CD.string like but with a case insensitive comparison) *)
  module CustomFunctor : sig

    val declare_backtick : name:string ->
      (Data.state -> string -> Data.state * Data.term) -> unit

    val declare_singlequote : name:string ->
      (Data.state -> string -> Data.state * Data.term) -> unit

  end


  module Utils : sig

    (** A regular error (fatal) *)
    val error : ?loc:Ast.Loc.t ->string -> 'a
    (** An invariant is broken, i.e. a bug *)
    val anomaly : ?loc:Ast.Loc.t ->string -> 'a
    (** A type error (in principle ruled out by [elpi-checker.elpi]) *)
    val type_error : ?loc:Ast.Loc.t ->string -> 'a
    (** A non fatal warning *)
    val warn : ?loc:Ast.Loc.t ->string -> unit

    (** link between OCaml and LP lists. Note that [1,2|X] is not a valid
     * OCaml list! *)
    val list_to_lp_list : Data.term list -> Data.term
    val lp_list_to_list : depth:int -> Data.term -> Data.term list

    (** The body of an assignment, if any (LOW LEVEL). 
     * Use [look] and forget about this API since the term you get
     * needs to be moved and/or reduced, and you have no API for this. *)
    val get_assignment : Data.uvar_body -> Data.term option

    (** Hackish, in particular the output should be a compiled program *)
    val clause_of_term :
      ?name:string -> ?graft:([`After | `Before] * string) ->
      depth:int -> Ast.Loc.t -> Data.term -> Ast.program

    (** Lifting/restriction (LOW LEVEL, don't use) *)
    val move : from:int -> to_:int -> Data.term -> Data.term

  end
        

  module Pp : sig

    (** If the term is under [depth] binders this is the function that has to be
     * called in order to print the term correct. WARNING: as of today printing
     * an open term (i.e. containing unification variables) in the *wrong* depth
     * can cause the pruning of the unification variable.
     * This behavior shall be cleaned up in the future *)
    val term : (*depth*)int -> Format.formatter -> Data.term -> unit

    val list : ?max:int -> ?boxed:bool ->
      (Format.formatter -> 'a -> unit) ->
      ?pplastelem:(Format.formatter -> 'a -> unit) -> string ->
        Format.formatter -> 'a list -> unit

    module Raw : sig
      val term : (*depth*)int -> Format.formatter -> Data.term -> unit
      val show_term : Data.term -> string
   end

  end

end (* Extend *)

(**/**)
