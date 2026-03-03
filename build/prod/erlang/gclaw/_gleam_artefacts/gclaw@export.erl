-module(gclaw@export).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gclaw/export.gleam").
-export([to_markdown/1]).
-export_type([export_format/0]).

-type export_format() :: markdown | j_s_o_n.

-file("src/gclaw/export.gleam", 18).
-spec format_fact({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}) -> binary().
format_fact(F) ->
    {Entity, Attribute, Value} = F,
    Content = case Value of
        {str, S} ->
            S;

        {int, I} ->
            erlang:integer_to_binary(I);

        {float, Fl} ->
            gleam_stdlib:float_to_string(Fl);

        {bool, B} ->
            case B of
                true ->
                    <<"true"/utf8>>;

                false ->
                    <<"false"/utf8>>
            end;

        _ ->
            <<"complex value"/utf8>>
    end,
    Eid_str = case Entity of
        {uid, {entity_id, Id}} ->
            erlang:integer_to_binary(Id);

        _ ->
            <<"lookup-ref"/utf8>>
    end,
    <<<<<<<<<<<<<<<<"## Fact "/utf8, Eid_str/binary>>/binary, "\n"/utf8>>/binary,
                            "- Attribute: "/utf8>>/binary,
                        Attribute/binary>>/binary,
                    "\n"/utf8>>/binary,
                "- Value: "/utf8>>/binary,
            Content/binary>>/binary,
        "\n"/utf8>>.

-file("src/gclaw/export.gleam", 12).
-spec to_markdown(list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()})) -> binary().
to_markdown(Facts) ->
    Header = <<"# GClaw Memory Export\n\n"/utf8>>,
    Body = begin
        _pipe = gleam@list:map(Facts, fun format_fact/1),
        gleam@string:join(_pipe, <<"\n---\n"/utf8>>)
    end,
    <<Header/binary, Body/binary>>.
