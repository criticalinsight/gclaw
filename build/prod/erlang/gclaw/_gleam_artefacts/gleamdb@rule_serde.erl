-module(gleamdb@rule_serde).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/rule_serde.gleam").
-export([serialize/1, deserialize/1]).

-file("src/gleamdb/rule_serde.gleam", 11).
-spec serialize(gleamdb@shared@types:rule()) -> binary().
serialize(Rule) ->
    Bits = erlang:term_to_binary(Rule),
    gleam_stdlib:base64_encode(Bits, false).

-file("src/gleamdb/rule_serde.gleam", 16).
-spec deserialize(binary()) -> {ok, gleamdb@shared@types:rule()} | {error, nil}.
deserialize(S) ->
    gleam@result:'try'(
        gleam@bit_array:base64_decode(S),
        fun(Bits) -> {ok, erlang:binary_to_term(Bits)} end
    ).
