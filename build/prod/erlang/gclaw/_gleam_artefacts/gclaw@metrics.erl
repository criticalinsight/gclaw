-module(gclaw@metrics).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gclaw/metrics.gleam").
-export([new_adapter/0]).

-file("src/gclaw/metrics.gleam", 14).
-spec create(binary()) -> gleam@dynamic:dynamic_().
create(_) ->
    gleam@dynamic:nil().

-file("src/gclaw/metrics.gleam", 18).
-spec update(gleam@dynamic:dynamic_(), list(gleamdb@fact:datom())) -> gleam@dynamic:dynamic_().
update(Data, _) ->
    Data.

-file("src/gclaw/metrics.gleam", 22).
-spec search(
    gleam@dynamic:dynamic_(),
    gleamdb@shared@types:index_query(),
    float()
) -> list(gleamdb@fact:entity_id()).
search(_, _, _) ->
    [].

-file("src/gclaw/metrics.gleam", 5).
-spec new_adapter() -> gleamdb@shared@types:index_adapter().
new_adapter() ->
    {index_adapter, <<"metric"/utf8>>, fun create/1, fun update/2, fun search/3}.
