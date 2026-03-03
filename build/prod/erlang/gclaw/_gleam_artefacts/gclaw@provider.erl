-module(gclaw@provider).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gclaw/provider.gleam").
-export([auto_select/2]).
-export_type([provider/0, capabilities/0]).

-type provider() :: gemini | open_a_i | anthropic | local.

-type capabilities() :: {capabilities,
        boolean(),
        boolean(),
        boolean(),
        integer()}.

-file("src/gclaw/provider.gleam", 21).
-spec auto_select(capabilities(), list({provider(), capabilities()})) -> {ok,
        provider()} |
    {error, nil}.
auto_select(Required_caps, Available) ->
    _pipe = Available,
    _pipe@1 = gleam@list:filter(
        _pipe,
        fun(Pair) ->
            Caps = erlang:element(2, Pair),
            (((erlang:element(2, Caps) =:= erlang:element(2, Required_caps))
            andalso (erlang:element(3, Caps) =:= erlang:element(
                3,
                Required_caps
            )))
            andalso (erlang:element(4, Caps) =:= erlang:element(
                4,
                Required_caps
            )))
            andalso (erlang:element(5, Caps) >= erlang:element(5, Required_caps))
        end
    ),
    _pipe@2 = gleam@list:sort(
        _pipe@1,
        fun(A, B) ->
            gleam@int:compare(
                erlang:element(5, erlang:element(2, B)),
                erlang:element(5, erlang:element(2, A))
            )
        end
    ),
    _pipe@3 = gleam@list:first(_pipe@2),
    gleam@result:map(_pipe@3, fun(Pair@1) -> erlang:element(1, Pair@1) end).
