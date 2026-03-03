-module(gleamdb@fact).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/fact.gleam").
-export([phash2/1, to_string/1, uid/1, deterministic_uid/1, ref/1, event_uid/2, to_uid/1, new_datom/5, encode_compact/1, encode_datom/1, decode_compact/1, decode_datom/1]).
-export_type([entity_id/0, eid/0, value/0, operation/0, retention/0, cardinality/0, attribute_config/0, datom/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type entity_id() :: {entity_id, integer()}.

-type eid() :: {lookup, {binary(), value()}} | {uid, entity_id()}.

-type value() :: {str, binary()} |
    {int, integer()} |
    {float, float()} |
    {bool, boolean()} |
    {list, list(value())} |
    {vec, list(float())} |
    {ref, entity_id()}.

-type operation() :: assert | retract.

-type retention() :: all | latest_only | {last, integer()}.

-type cardinality() :: many | one.

-type attribute_config() :: {attribute_config,
        boolean(),
        boolean(),
        retention(),
        cardinality(),
        gleam@option:option(binary())}.

-type datom() :: {datom,
        entity_id(),
        binary(),
        value(),
        integer(),
        integer(),
        operation()}.

-file("src/gleamdb/fact.gleam", 8).
-spec phash2(any()) -> integer().
phash2(Data) ->
    erlang:phash2(Data).

-file("src/gleamdb/fact.gleam", 10).
-spec to_string(value()) -> binary().
to_string(V) ->
    gleam@string:inspect(V).

-file("src/gleamdb/fact.gleam", 14).
-spec uid(integer()) -> eid().
uid(Id) ->
    {uid, {entity_id, Id}}.

-file("src/gleamdb/fact.gleam", 20).
?DOC(
    " Create a deterministic Entity ID based on a hash of the data.\n"
    " This enables idempotent transaction semantics.\n"
).
-spec deterministic_uid(any()) -> eid().
deterministic_uid(Data) ->
    {uid, {entity_id, erlang:phash2(Data)}}.

-file("src/gleamdb/fact.gleam", 24).
-spec ref(integer()) -> entity_id().
ref(Id) ->
    {entity_id, Id}.

-file("src/gleamdb/fact.gleam", 30).
?DOC(
    " Create a unique, deterministic Entity ID for an event based on its type and timestamp.\n"
    " This ensures that the same event instance (e.g. from retries) always gets the same ID.\n"
).
-spec event_uid(binary(), integer()) -> eid().
event_uid(Event_type, Timestamp) ->
    deterministic_uid({Event_type, Timestamp}).

-file("src/gleamdb/fact.gleam", 105).
-spec to_uid(entity_id()) -> eid().
to_uid(Id) ->
    {uid, Id}.

-file("src/gleamdb/fact.gleam", 110).
?DOC(" Create a new Datom with default valid_time = 0.\n").
-spec new_datom(entity_id(), binary(), value(), integer(), operation()) -> datom().
new_datom(Entity, Attribute, Value, Tx, Operation) ->
    {datom, Entity, Attribute, Value, Tx, 0, Operation}.

-file("src/gleamdb/fact.gleam", 120).
-spec encode_compact(value()) -> bitstring().
encode_compact(V) ->
    case V of
        {str, S} ->
            B = <<S/binary>>,
            <<0:8, ((erlang:byte_size(B))):32, B/bitstring>>;

        {int, I} ->
            <<1:8, I:64>>;

        {float, F} ->
            <<2:8, F/float>>;

        {bool, B@1} ->
            <<3:8, ((case B@1 of
                    true ->
                        1;

                    false ->
                        0
                end)):8>>;

        {list, L} ->
            B@2 = gleam@list:fold(
                L,
                <<>>,
                fun(Acc, Item) ->
                    <<Acc/bitstring, ((encode_compact(Item)))/bitstring>>
                end
            ),
            <<4:8, ((erlang:length(L))):32, B@2/bitstring>>;

        {vec, V@1} ->
            B@3 = gleam@list:fold(
                V@1,
                <<>>,
                fun(Acc@1, Item@1) -> <<Acc@1/bitstring, Item@1/float>> end
            ),
            <<5:8, ((erlang:length(V@1))):32, B@3/bitstring>>;

        {ref, {entity_id, Id}} ->
            <<6:8, Id:64>>
    end.

-file("src/gleamdb/fact.gleam", 144).
-spec encode_datom(datom()) -> bitstring().
encode_datom(D) ->
    {entity_id, E_id} = erlang:element(2, D),
    Op_id = case erlang:element(7, D) of
        assert ->
            1;

        retract ->
            0
    end,
    V_bits = encode_compact(erlang:element(4, D)),
    A_bits = <<((erlang:element(3, D)))/binary>>,
    <<E_id:64,
        ((erlang:byte_size(A_bits))):32,
        A_bits/bitstring,
        Op_id:8,
        (erlang:element(5, D)):64,
        (erlang:element(6, D)):64,
        V_bits/bitstring>>.

-file("src/gleamdb/fact.gleam", 203).
-spec decode_vec_loop(bitstring(), integer(), list(float())) -> {ok,
        {list(float()), bitstring()}} |
    {error, nil}.
decode_vec_loop(Bits, Len, Acc) ->
    case Len of
        0 ->
            {ok, {Acc, Bits}};

        _ ->
            case Bits of
                <<F/float, Rest/bitstring>> ->
                    decode_vec_loop(Rest, Len - 1, [F | Acc]);

                _ ->
                    {error, nil}
            end
    end.

-file("src/gleamdb/fact.gleam", 191).
-spec decode_list_loop(bitstring(), integer(), list(value())) -> {ok,
        {list(value()), bitstring()}} |
    {error, nil}.
decode_list_loop(Bits, Len, Acc) ->
    case Len of
        0 ->
            {ok, {Acc, Bits}};

        _ ->
            case decode_compact(Bits) of
                {ok, {Val, Rest}} ->
                    decode_list_loop(Rest, Len - 1, [Val | Acc]);

                {error, _} ->
                    {error, nil}
            end
    end.

-file("src/gleamdb/fact.gleam", 163).
-spec decode_compact(bitstring()) -> {ok, {value(), bitstring()}} | {error, nil}.
decode_compact(Bits) ->
    case Bits of
        <<0:8, Len:32, S:Len/binary, Rest/bitstring>> ->
            case gleam@bit_array:to_string(S) of
                {ok, Str} ->
                    {ok, {{str, Str}, Rest}};

                {error, _} ->
                    {error, nil}
            end;

        <<1:8, I:64, Rest@1/bitstring>> ->
            {ok, {{int, I}, Rest@1}};

        <<2:8, F/float, Rest@2/bitstring>> ->
            {ok, {{float, F}, Rest@2}};

        <<3:8, B:8, Rest@3/bitstring>> ->
            {ok, {{bool, B =:= 1}, Rest@3}};

        <<4:8, Len@1:32, Rest@4/bitstring>> ->
            case decode_list_loop(Rest@4, Len@1, []) of
                {ok, {L, Tail}} ->
                    {ok, {{list, lists:reverse(L)}, Tail}};

                {error, _} ->
                    {error, nil}
            end;

        <<5:8, Len@2:32, Rest@5/bitstring>> ->
            case decode_vec_loop(Rest@5, Len@2, []) of
                {ok, {V, Tail@1}} ->
                    {ok, {{vec, lists:reverse(V)}, Tail@1}};

                {error, _} ->
                    {error, nil}
            end;

        <<6:8, Id:64, Rest@6/bitstring>> ->
            {ok, {{ref, {entity_id, Id}}, Rest@6}};

        _ ->
            {error, nil}
    end.

-file("src/gleamdb/fact.gleam", 215).
-spec decode_datom(bitstring()) -> {ok, {datom(), bitstring()}} | {error, nil}.
decode_datom(Bits) ->
    case Bits of
        <<E_id:64,
            A_len:32,
            A_bits:A_len/binary,
            Op_id:8,
            Tx:64,
            Vt:64,
            Val_bits/bitstring>> ->
            case gleam@bit_array:to_string(A_bits) of
                {ok, Attr} ->
                    Op = case Op_id of
                        1 ->
                            assert;

                        _ ->
                            retract
                    end,
                    case decode_compact(Val_bits) of
                        {ok, {Val, Rest}} ->
                            {ok,
                                {{datom,
                                        {entity_id, E_id},
                                        Attr,
                                        Val,
                                        Tx,
                                        Vt,
                                        Op},
                                    Rest}};

                        {error, _} ->
                            {error, nil}
                    end;

                {error, _} ->
                    {error, nil}
            end;

        _ ->
            {error, nil}
    end.
