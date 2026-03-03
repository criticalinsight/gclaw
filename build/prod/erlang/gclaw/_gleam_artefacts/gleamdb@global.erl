-module(gleamdb@global).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/global.gleam").
-export([register/2, whereis/1, unregister/1]).

-file("src/gleamdb/global.gleam", 4).
-spec register(binary(), gleam@erlang@process:pid_()) -> {ok, nil} |
    {error, nil}.
register(Name, Pid) ->
    gleamdb_global_ffi:register(Name, Pid).

-file("src/gleamdb/global.gleam", 7).
-spec whereis(binary()) -> {ok, gleam@erlang@process:pid_()} | {error, nil}.
whereis(Name) ->
    gleamdb_global_ffi:whereis(Name).

-file("src/gleamdb/global.gleam", 10).
-spec unregister(binary()) -> nil.
unregister(Name) ->
    gleamdb_global_ffi:unregister(Name).
