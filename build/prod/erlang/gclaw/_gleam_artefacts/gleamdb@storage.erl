-module(gleamdb@storage).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/storage.gleam").
-export([ephemeral/0]).
-export_type([storage_adapter/0]).

-type storage_adapter() :: {storage_adapter,
        fun(() -> nil),
        fun((gleamdb@fact:datom()) -> nil),
        fun((list(gleamdb@fact:datom())) -> nil),
        fun(() -> {ok, list(gleamdb@fact:datom())} | {error, binary()})}.

-file("src/gleamdb/storage.gleam", 11).
-spec ephemeral() -> storage_adapter().
ephemeral() ->
    {storage_adapter,
        fun() -> nil end,
        fun(_) -> nil end,
        fun(_) -> nil end,
        fun() -> {ok, []} end}.
