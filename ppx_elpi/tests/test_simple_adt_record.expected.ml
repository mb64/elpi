let elpi_stuff = ref []
let pp_simple _ _ = ()
type simple =
  | K1 of {
  f: int ;
  g: bool } 
  | K2 of {
  f2: bool } [@@deriving elpi { declaration = elpi_stuff }]
include
  struct
    [@@@warning "-26-27-32-39-60"]
    let elpi_constant_type_simple = "simple"
    let elpi_constant_type_simplec =
      Elpi.API.RawData.Constants.declare_global_symbol
        elpi_constant_type_simple
    let elpi_constant_constructor_simple_K1 = "k1"
    let elpi_constant_constructor_simple_K1c =
      Elpi.API.RawData.Constants.declare_global_symbol
        elpi_constant_constructor_simple_K1
    let elpi_constant_constructor_simple_K2 = "k2"
    let elpi_constant_constructor_simple_K2c =
      Elpi.API.RawData.Constants.declare_global_symbol
        elpi_constant_constructor_simple_K2
    module Ctx_for_simple =
      struct class type t = object inherit Elpi.API.Conversion.ctx end end
    let rec elpi_embed_simple :
      'c . (simple, #Ctx_for_simple.t as 'c) Elpi.API.Conversion.embedding =
      fun ~depth:elpi__depth ->
        fun elpi__hyps ->
          fun elpi__constraints ->
            fun elpi__state ->
              function
              | K1 { f = elpi__7; g = elpi__8 } ->
                  let (elpi__state, elpi__11, elpi__9) =
                    Elpi.API.PPX.embed_int ~depth:elpi__depth elpi__hyps
                      elpi__constraints elpi__state elpi__7 in
                  let (elpi__state, elpi__12, elpi__10) =
                    Elpi.Builtin.PPX.embed_bool ~depth:elpi__depth elpi__hyps
                      elpi__constraints elpi__state elpi__8 in
                  (elpi__state,
                    (Elpi.API.RawData.mkAppL
                       elpi_constant_constructor_simple_K1c
                       [elpi__11; elpi__12]),
                    (List.concat [elpi__9; elpi__10]))
              | K2 { f2 = elpi__13 } ->
                  let (elpi__state, elpi__15, elpi__14) =
                    Elpi.Builtin.PPX.embed_bool ~depth:elpi__depth elpi__hyps
                      elpi__constraints elpi__state elpi__13 in
                  (elpi__state,
                    (Elpi.API.RawData.mkAppL
                       elpi_constant_constructor_simple_K2c [elpi__15]),
                    (List.concat [elpi__14]))
    let rec elpi_readback_simple :
      'c . (simple, #Ctx_for_simple.t as 'c) Elpi.API.Conversion.readback =
      fun ~depth:elpi__depth ->
        fun elpi__hyps ->
          fun elpi__constraints ->
            fun elpi__state ->
              fun elpi__x ->
                match Elpi.API.RawData.look ~depth:elpi__depth elpi__x with
                | Elpi.API.RawData.App (elpi__hd, elpi__x, elpi__xs) when
                    elpi__hd == elpi_constant_constructor_simple_K1c ->
                    let (elpi__state, elpi__4, elpi__3) =
                      Elpi.API.PPX.readback_int ~depth:elpi__depth elpi__hyps
                        elpi__constraints elpi__state elpi__x in
                    (match elpi__xs with
                     | elpi__1::[] ->
                         let (elpi__state, elpi__1, elpi__2) =
                           Elpi.Builtin.PPX.readback_bool ~depth:elpi__depth
                             elpi__hyps elpi__constraints elpi__state elpi__1 in
                         (elpi__state, (K1 { f = elpi__4; g = elpi__1 }),
                           (List.concat [elpi__3; elpi__2]))
                     | _ ->
                         Elpi.API.Utils.type_error
                           ("Not enough arguments to constructor: " ^
                              (Elpi.API.RawData.Constants.show
                                 elpi_constant_constructor_simple_K1c)))
                | Elpi.API.RawData.App (elpi__hd, elpi__x, elpi__xs) when
                    elpi__hd == elpi_constant_constructor_simple_K2c ->
                    let (elpi__state, elpi__6, elpi__5) =
                      Elpi.Builtin.PPX.readback_bool ~depth:elpi__depth
                        elpi__hyps elpi__constraints elpi__state elpi__x in
                    (match elpi__xs with
                     | [] ->
                         (elpi__state, (K2 { f2 = elpi__6 }),
                           (List.concat [elpi__5]))
                     | _ ->
                         Elpi.API.Utils.type_error
                           ("Not enough arguments to constructor: " ^
                              (Elpi.API.RawData.Constants.show
                                 elpi_constant_constructor_simple_K2c)))
                | _ ->
                    Elpi.API.Utils.type_error
                      (Format.asprintf "Not a constructor of type %s: %a"
                         "simple" (Elpi.API.RawPp.term elpi__depth) elpi__x)
    let simple : 'c . (simple, #Ctx_for_simple.t as 'c) Elpi.API.Conversion.t
      =
      let kind = Elpi.API.Conversion.TyName "simple" in
      {
        Elpi.API.Conversion.ty = kind;
        pp_doc =
          (fun fmt ->
             fun () ->
               Elpi.API.PPX.Doc.kind fmt kind ~doc:"simple";
               Elpi.API.PPX.Doc.constructor fmt ~ty:kind ~name:"k1" ~doc:"K1"
                 ~args:[Elpi.API.BuiltInData.int.Elpi.API.Conversion.ty;
                       Elpi.Builtin.bool.Elpi.API.Conversion.ty];
               Elpi.API.PPX.Doc.constructor fmt ~ty:kind ~name:"k2" ~doc:"K2"
                 ~args:[Elpi.Builtin.bool.Elpi.API.Conversion.ty]);
        pp = pp_simple;
        embed = elpi_embed_simple;
        readback = elpi_readback_simple
      }
    let elpi_simple = Elpi.API.BuiltIn.MLData simple
    class ctx_for_simple (h : Elpi.API.Data.hyps)  (s : Elpi.API.Data.state)
      : Ctx_for_simple.t =
      object (_) inherit  ((Elpi.API.Conversion.ctx) h) end
    let (in_ctx_for_simple :
      Ctx_for_simple.t Elpi.API.Conversion.ctx_readback) =
      fun ~depth ->
        fun h ->
          fun c -> fun s -> (s, ((new ctx_for_simple) h s), (List.concat []))
    let () = elpi_stuff := ((!elpi_stuff) @ [elpi_simple])
  end[@@ocaml.doc "@inline"][@@merlin.hide ]
open Elpi.API
let builtin =
  let open BuiltIn in declare ~file_name:(Sys.argv.(1)) (!elpi_stuff)
let main () =
  let (_elpi, _) = Setup.init ~builtins:[builtin] ~basedir:"." [] in
  BuiltIn.document_file builtin; exit 0
;;main ()
