-module(gleamdb@storage@mnesia).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/storage/mnesia.gleam").
-export([init_mnesia/0, persist_datom/1, persist_batch/1, recover_datoms/0, adapter/0]).

-file("src/gleamdb/storage/mnesia.gleam", 5).
-spec init_mnesia() -> nil.
init_mnesia() ->
    gleamdb_mnesia_ffi:init().

-file("src/gleamdb/storage/mnesia.gleam", 8).
-spec persist_datom(gleamdb@fact:datom()) -> nil.
persist_datom(Datom) ->
    gleamdb_mnesia_ffi:persist(Datom).

-file("src/gleamdb/storage/mnesia.gleam", 11).
-spec persist_batch(list(gleamdb@fact:datom())) -> nil.
persist_batch(Datoms) ->
    gleamdb_mnesia_ffi:persist_batch(Datoms).

-file("src/gleamdb/storage/mnesia.gleam", 23).
-spec recover_datoms() -> {ok, list(gleamdb@fact:datom())} | {error, binary()}.
recover_datoms() ->
    gleamdb_mnesia_ffi:recover().

-file("src/gleamdb/storage/mnesia.gleam", 13).
-spec adapter() -> gleamdb@storage:storage_adapter().
adapter() ->
    {storage_adapter,
        fun gleamdb_mnesia_ffi:init/0,
        fun gleamdb_mnesia_ffi:persist/1,
        fun gleamdb_mnesia_ffi:persist_batch/1,
        fun gleamdb_mnesia_ffi:recover/0}.
