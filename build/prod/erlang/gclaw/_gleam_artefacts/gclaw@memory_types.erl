-module(gclaw@memory_types).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gclaw/memory_types.gleam").
-export([to_string/1, from_string/1]).
-export_type([memory_type/0]).

-type memory_type() :: conversation |
    document |
    code_snippet |
    observation |
    plan.

-file("src/gclaw/memory_types.gleam", 19).
-spec to_string(memory_type()) -> binary().
to_string(Mt) ->
    case Mt of
        conversation ->
            <<"conversation"/utf8>>;

        document ->
            <<"document"/utf8>>;

        code_snippet ->
            <<"code_snippet"/utf8>>;

        observation ->
            <<"observation"/utf8>>;

        plan ->
            <<"plan"/utf8>>
    end.

-file("src/gclaw/memory_types.gleam", 29).
-spec from_string(binary()) -> gleam@option:option(memory_type()).
from_string(S) ->
    case S of
        <<"conversation"/utf8>> ->
            {some, conversation};

        <<"document"/utf8>> ->
            {some, document};

        <<"code_snippet"/utf8>> ->
            {some, code_snippet};

        <<"observation"/utf8>> ->
            {some, observation};

        <<"plan"/utf8>> ->
            {some, plan};

        _ ->
            none
    end.
