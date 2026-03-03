-module(gclaw@fact).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gclaw/fact.gleam").
-export([value_to_string/1, format_datom/1]).

-file("src/gclaw/fact.gleam", 14).
-spec value_to_string(gleamdb@fact:value()) -> binary().
value_to_string(V) ->
    case V of
        {str, S} ->
            S;

        {int, I} ->
            gleam@string:inspect(I);

        {float, F} ->
            gleam@string:inspect(F);

        {bool, B} ->
            gleam@string:inspect(B);

        {vec, Floats} ->
            <<<<"["/utf8,
                    (gleam@string:join(
                        gleam@list:map(Floats, fun gleam@string:inspect/1),
                        <<", "/utf8>>
                    ))/binary>>/binary,
                "]"/utf8>>;

        _ ->
            <<""/utf8>>
    end.

-file("src/gclaw/fact.gleam", 25).
-spec format_datom(gleamdb@fact:datom()) -> binary().
format_datom(D) ->
    <<<<<<"["/utf8, (erlang:element(3, D))/binary>>/binary, "]: "/utf8>>/binary,
        (value_to_string(erlang:element(4, D)))/binary>>.
