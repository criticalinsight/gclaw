-module(gleamdb@index@ets).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/index/ets.gleam").
-export([init_tables/1, insert_datom/3, insert_avet/3, lookup_datoms/2, delete/2, get_av/3, prune_historical/3, prune_historical_aevt/3]).
-export_type([table_type/0]).

-type table_type() :: set | ordered_set | bag | duplicate_bag.

-file("src/gleamdb/index/ets.gleam", 7).
-spec init_tables(binary()) -> nil.
init_tables(Db_name) ->
    Eavt = <<Db_name/binary, "_eavt"/utf8>>,
    Aevt = <<Db_name/binary, "_aevt"/utf8>>,
    Avet = <<Db_name/binary, "_avet"/utf8>>,
    gleamdb_ets_ffi:init_table(Eavt, duplicate_bag),
    gleamdb_ets_ffi:init_table(Aevt, duplicate_bag),
    gleamdb_ets_ffi:init_table(Avet, set),
    nil.

-file("src/gleamdb/index/ets.gleam", 28).
-spec insert_datom(binary(), any(), gleamdb@fact:datom()) -> nil.
insert_datom(Table, Key, Datom) ->
    gleamdb_ets_ffi:insert(Table, {Key, Datom}).

-file("src/gleamdb/index/ets.gleam", 32).
-spec insert_avet(
    binary(),
    {binary(), gleamdb@fact:value()},
    gleamdb@fact:entity_id()
) -> nil.
insert_avet(Table, Key, Eid) ->
    gleamdb_ets_ffi:insert(Table, {Key, Eid}).

-file("src/gleamdb/index/ets.gleam", 39).
-spec lookup_datoms(binary(), any()) -> list(gleamdb@fact:datom()).
lookup_datoms(Table, Key) ->
    _pipe = gleamdb_ets_ffi:lookup(Table, Key),
    gleam@list:map(
        _pipe,
        fun(Obj) ->
            {_, Val} = Obj,
            Val
        end
    ).

-file("src/gleamdb/index/ets.gleam", 50).
-spec delete(binary(), any()) -> nil.
delete(Table, Key) ->
    gleamdb_ets_ffi:delete(Table, Key).

-file("src/gleamdb/index/ets.gleam", 57).
-spec get_av(binary(), binary(), gleamdb@fact:value()) -> gleam@option:option(gleamdb@fact:entity_id()).
get_av(Table, Attr, Val) ->
    case gleamdb_ets_ffi:lookup(Table, {Attr, Val}) of
        [{_, Eid}] ->
            {some, Eid};

        _ ->
            none
    end.

-file("src/gleamdb/index/ets.gleam", 67).
-spec prune_historical(binary(), gleamdb@fact:entity_id(), binary()) -> nil.
prune_historical(Table, Eid, Attr) ->
    gleamdb_ets_ffi:prune_eavt(Table, Eid, Attr).

-file("src/gleamdb/index/ets.gleam", 71).
-spec prune_historical_aevt(binary(), binary(), gleamdb@fact:entity_id()) -> nil.
prune_historical_aevt(Table, Attr, Eid) ->
    gleamdb_ets_ffi:prune_aevt(Table, Attr, Eid).
