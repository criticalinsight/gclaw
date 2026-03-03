-module(gleamdb@index).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/index.gleam").
-export([new_index/0, new_aindex/0, new_avindex/0, new_hybrid_index/1, insert_avet/2, delete_avet/2, insert_eavt/3, insert_hybrid/3, insert_aevt/3, delete_eavt/2, delete_aevt/2, filter_by_attribute/2, filter_by_entity/2, get_datoms_by_entity_attr_val/4, get_datoms_by_entity_attr/3, get_datoms_by_val/3, get_all_datoms/1, get_all_datoms_for_attr/2, get_all_datoms_avet/1, get_entity_by_av/3]).
-export_type([hybrid_index/0]).

-type hybrid_index() :: {hybrid_index,
        gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())),
        list(bitstring()),
        integer()}.

-file("src/gleamdb/index.gleam", 24).
-spec new_index() -> gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())).
new_index() ->
    maps:new().

-file("src/gleamdb/index.gleam", 28).
-spec new_aindex() -> gleam@dict:dict(binary(), list(gleamdb@fact:datom())).
new_aindex() ->
    maps:new().

-file("src/gleamdb/index.gleam", 32).
-spec new_avindex() -> gleam@dict:dict(binary(), gleam@dict:dict(gleamdb@fact:value(), gleamdb@fact:entity_id())).
new_avindex() ->
    maps:new().

-file("src/gleamdb/index.gleam", 36).
-spec new_hybrid_index(integer()) -> hybrid_index().
new_hybrid_index(Capacity) ->
    {hybrid_index, maps:new(), [], Capacity}.

-file("src/gleamdb/index.gleam", 98).
-spec insert_avet(
    gleam@dict:dict(binary(), gleam@dict:dict(gleamdb@fact:value(), gleamdb@fact:entity_id())),
    gleamdb@fact:datom()
) -> gleam@dict:dict(binary(), gleam@dict:dict(gleamdb@fact:value(), gleamdb@fact:entity_id())).
insert_avet(Index, Datom) ->
    V_dict = begin
        _pipe = gleam_stdlib:map_get(Index, erlang:element(3, Datom)),
        gleam@result:unwrap(_pipe, maps:new())
    end,
    New_v_dict = gleam@dict:insert(
        V_dict,
        erlang:element(4, Datom),
        erlang:element(2, Datom)
    ),
    gleam@dict:insert(Index, erlang:element(3, Datom), New_v_dict).

-file("src/gleamdb/index.gleam", 112).
-spec delete_avet(
    gleam@dict:dict(binary(), gleam@dict:dict(gleamdb@fact:value(), gleamdb@fact:entity_id())),
    gleamdb@fact:datom()
) -> gleam@dict:dict(binary(), gleam@dict:dict(gleamdb@fact:value(), gleamdb@fact:entity_id())).
delete_avet(Index, Datom) ->
    V_dict = begin
        _pipe = gleam_stdlib:map_get(Index, erlang:element(3, Datom)),
        gleam@result:unwrap(_pipe, maps:new())
    end,
    New_v_dict = gleam@dict:delete(V_dict, erlang:element(4, Datom)),
    gleam@dict:insert(Index, erlang:element(3, Datom), New_v_dict).

-file("src/gleamdb/index.gleam", 118).
-spec result_to_list({ok, list(HLL)} | {error, any()}) -> list(HLL).
result_to_list(Res) ->
    case Res of
        {ok, L} ->
            L;

        {error, _} ->
            []
    end.

-file("src/gleamdb/index.gleam", 60).
-spec insert_eavt(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())),
    gleamdb@fact:datom(),
    gleamdb@fact:retention()
) -> gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())).
insert_eavt(Index, Datom, Retention) ->
    Bucket = begin
        _pipe = gleam_stdlib:map_get(Index, erlang:element(2, Datom)),
        result_to_list(_pipe)
    end,
    New_bucket = case Retention of
        all ->
            [Datom | Bucket];

        latest_only ->
            Filtered = gleam@list:filter(
                Bucket,
                fun(D) -> erlang:element(3, D) /= erlang:element(3, Datom) end
            ),
            [Datom | Filtered];

        {last, N} ->
            Filtered@1 = gleam@list:filter(
                Bucket,
                fun(D@1) ->
                    erlang:element(3, D@1) /= erlang:element(3, Datom)
                end
            ),
            Existing = gleam@list:filter(
                Bucket,
                fun(D@2) ->
                    erlang:element(3, D@2) =:= erlang:element(3, Datom)
                end
            ),
            Kept = gleam@list:take(Existing, N - 1),
            [Datom | lists:append(Kept, Filtered@1)]
    end,
    gleam@dict:insert(Index, erlang:element(2, Datom), New_bucket).

-file("src/gleamdb/index.gleam", 40).
-spec insert_hybrid(
    hybrid_index(),
    gleamdb@fact:datom(),
    gleamdb@fact:retention()
) -> hybrid_index().
insert_hybrid(Index, Datom, Retention) ->
    New_index = insert_eavt(erlang:element(2, Index), Datom, Retention),
    case maps:size(New_index) > erlang:element(4, Index) of
        true ->
            Index;

        false ->
            {hybrid_index,
                New_index,
                erlang:element(3, Index),
                erlang:element(4, Index)}
    end.

-file("src/gleamdb/index.gleam", 79).
-spec insert_aevt(
    gleam@dict:dict(binary(), list(gleamdb@fact:datom())),
    gleamdb@fact:datom(),
    gleamdb@fact:retention()
) -> gleam@dict:dict(binary(), list(gleamdb@fact:datom())).
insert_aevt(Index, Datom, Retention) ->
    Bucket = begin
        _pipe = gleam_stdlib:map_get(Index, erlang:element(3, Datom)),
        result_to_list(_pipe)
    end,
    New_bucket = case Retention of
        all ->
            [Datom | Bucket];

        latest_only ->
            Filtered = gleam@list:filter(
                Bucket,
                fun(D) -> erlang:element(2, D) /= erlang:element(2, Datom) end
            ),
            [Datom | Filtered];

        {last, N} ->
            Filtered@1 = gleam@list:filter(
                Bucket,
                fun(D@1) ->
                    erlang:element(2, D@1) /= erlang:element(2, Datom)
                end
            ),
            Existing = gleam@list:filter(
                Bucket,
                fun(D@2) ->
                    erlang:element(2, D@2) =:= erlang:element(2, Datom)
                end
            ),
            Kept = gleam@list:take(Existing, N - 1),
            [Datom | lists:append(Kept, Filtered@1)]
    end,
    gleam@dict:insert(Index, erlang:element(3, Datom), New_bucket).

-file("src/gleamdb/index.gleam", 104).
-spec delete_eavt(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())),
    gleamdb@fact:datom()
) -> gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())).
delete_eavt(Index, Datom) ->
    insert_eavt(Index, Datom, all).

-file("src/gleamdb/index.gleam", 108).
-spec delete_aevt(
    gleam@dict:dict(binary(), list(gleamdb@fact:datom())),
    gleamdb@fact:datom()
) -> gleam@dict:dict(binary(), list(gleamdb@fact:datom())).
delete_aevt(Index, Datom) ->
    insert_aevt(Index, Datom, all).

-file("src/gleamdb/index.gleam", 125).
-spec filter_by_attribute(
    gleam@dict:dict(binary(), list(gleamdb@fact:datom())),
    binary()
) -> list(gleamdb@fact:datom()).
filter_by_attribute(Index, Attr) ->
    _pipe = gleam_stdlib:map_get(Index, Attr),
    result_to_list(_pipe).

-file("src/gleamdb/index.gleam", 129).
-spec filter_by_entity(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())),
    gleamdb@fact:entity_id()
) -> list(gleamdb@fact:datom()).
filter_by_entity(Index, Entity) ->
    _pipe = gleam_stdlib:map_get(Index, Entity),
    result_to_list(_pipe).

-file("src/gleamdb/index.gleam", 133).
-spec get_datoms_by_entity_attr_val(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())),
    gleamdb@fact:entity_id(),
    binary(),
    gleamdb@fact:value()
) -> list(gleamdb@fact:datom()).
get_datoms_by_entity_attr_val(Index, Entity, Attr, Val) ->
    _pipe = gleam_stdlib:map_get(Index, Entity),
    _pipe@1 = result_to_list(_pipe),
    gleam@list:filter(
        _pipe@1,
        fun(D) ->
            (erlang:element(3, D) =:= Attr) andalso (erlang:element(4, D) =:= Val)
        end
    ).

-file("src/gleamdb/index.gleam", 144).
-spec get_datoms_by_entity_attr(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())),
    gleamdb@fact:entity_id(),
    binary()
) -> list(gleamdb@fact:datom()).
get_datoms_by_entity_attr(Index, Entity, Attr) ->
    _pipe = gleam_stdlib:map_get(Index, Entity),
    _pipe@1 = result_to_list(_pipe),
    gleam@list:filter(_pipe@1, fun(D) -> erlang:element(3, D) =:= Attr end).

-file("src/gleamdb/index.gleam", 154).
-spec get_datoms_by_val(
    gleam@dict:dict(binary(), list(gleamdb@fact:datom())),
    binary(),
    gleamdb@fact:value()
) -> list(gleamdb@fact:datom()).
get_datoms_by_val(Index, Attr, Val) ->
    _pipe = gleam_stdlib:map_get(Index, Attr),
    _pipe@1 = result_to_list(_pipe),
    gleam@list:filter(_pipe@1, fun(D) -> erlang:element(4, D) =:= Val end).

-file("src/gleamdb/index.gleam", 160).
-spec get_all_datoms(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom()))
) -> list(gleamdb@fact:datom()).
get_all_datoms(Index) ->
    _pipe = maps:values(Index),
    lists:append(_pipe).

-file("src/gleamdb/index.gleam", 165).
-spec get_all_datoms_for_attr(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())),
    binary()
) -> list(gleamdb@fact:datom()).
get_all_datoms_for_attr(Index, Attr) ->
    _pipe = maps:values(Index),
    _pipe@1 = lists:append(_pipe),
    gleam@list:filter(_pipe@1, fun(D) -> erlang:element(3, D) =:= Attr end).

-file("src/gleamdb/index.gleam", 171).
-spec get_all_datoms_avet(
    gleam@dict:dict(binary(), gleam@dict:dict(gleamdb@fact:value(), gleamdb@fact:entity_id()))
) -> list(gleamdb@fact:datom()).
get_all_datoms_avet(Index) ->
    _pipe = maps:values(Index),
    gleam@list:flat_map(_pipe, fun(V_dict) -> _pipe@1 = maps:to_list(V_dict),
            gleam@list:map(
                _pipe@1,
                fun(Pair) ->
                    {Val, Eid} = Pair,
                    {datom, Eid, <<"unknown"/utf8>>, Val, 0, 0, assert}
                end
            ) end).

-file("src/gleamdb/index.gleam", 182).
-spec get_entity_by_av(
    gleam@dict:dict(binary(), gleam@dict:dict(gleamdb@fact:value(), gleamdb@fact:entity_id())),
    binary(),
    gleamdb@fact:value()
) -> {ok, gleamdb@fact:entity_id()} | {error, nil}.
get_entity_by_av(Index, Attr, Val) ->
    case gleam_stdlib:map_get(Index, Attr) of
        {ok, V_dict} ->
            gleam_stdlib:map_get(V_dict, Val);

        {error, _} ->
            {error, nil}
    end.
