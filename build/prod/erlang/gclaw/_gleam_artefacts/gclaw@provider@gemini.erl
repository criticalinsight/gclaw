-module(gclaw@provider@gemini).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gclaw/provider/gemini.gleam").
-export([generate/5, embed/3]).
-export_type([message/0, tool/0, tool_call/0, gemini_response/0]).

-type message() :: {message, binary(), binary()}.

-type tool() :: {tool, binary(), binary(), gleam@json:json()}.

-type tool_call() :: {tool_call,
        binary(),
        gleam@dict:dict(binary(), gleam@dynamic:dynamic_())}.

-type gemini_response() :: {text_response, binary()} |
    {tool_call_response, list(tool_call())}.

-file("src/gclaw/provider/gemini.gleam", 121).
-spec decode_response(binary()) -> {ok, gemini_response()} | {error, binary()}.
decode_response(Body_string) ->
    Text_decoder = begin
        _pipe = gleam@dynamic@decode:at(
            [<<"candidates"/utf8>>],
            gleam@dynamic@decode:at(
                [0],
                gleam@dynamic@decode:at(
                    [<<"content"/utf8>>, <<"parts"/utf8>>],
                    gleam@dynamic@decode:at(
                        [0],
                        gleam@dynamic@decode:at(
                            [<<"text"/utf8>>],
                            {decoder, fun gleam@dynamic@decode:decode_string/1}
                        )
                    )
                )
            )
        ),
        gleam@dynamic@decode:map(
            _pipe,
            fun(Field@0) -> {text_response, Field@0} end
        )
    end,
    case gleam@json:parse(Body_string, Text_decoder) of
        {ok, Resp} ->
            {ok, Resp};

        {error, _} ->
            Tool_call_decoder = begin
                gleam@dynamic@decode:field(
                    <<"name"/utf8>>,
                    {decoder, fun gleam@dynamic@decode:decode_string/1},
                    fun(Name) ->
                        gleam@dynamic@decode:field(
                            <<"args"/utf8>>,
                            gleam@dynamic@decode:dict(
                                {decoder,
                                    fun gleam@dynamic@decode:decode_string/1},
                                {decoder,
                                    fun gleam@dynamic@decode:decode_dynamic/1}
                            ),
                            fun(Args) ->
                                gleam@dynamic@decode:success(
                                    {tool_call, Name, Args}
                                )
                            end
                        )
                    end
                )
            end,
            Tool_decoder = begin
                _pipe@1 = gleam@dynamic@decode:at(
                    [<<"candidates"/utf8>>],
                    gleam@dynamic@decode:at(
                        [0],
                        gleam@dynamic@decode:at(
                            [<<"content"/utf8>>, <<"parts"/utf8>>],
                            gleam@dynamic@decode:at(
                                [0],
                                gleam@dynamic@decode:at(
                                    [<<"functionCall"/utf8>>],
                                    Tool_call_decoder
                                )
                            )
                        )
                    )
                ),
                gleam@dynamic@decode:map(
                    _pipe@1,
                    fun(Call) -> {tool_call_response, [Call]} end
                )
            end,
            case gleam@json:parse(Body_string, Tool_decoder) of
                {ok, Resp@1} ->
                    {ok, Resp@1};

                {error, Err} ->
                    {error,
                        <<<<<<"Failed to decode Gemini response: "/utf8,
                                    (gleam@string:inspect(Err))/binary>>/binary,
                                "\nBody: "/utf8>>/binary,
                            Body_string/binary>>}
            end
    end.

-file("src/gclaw/provider/gemini.gleam", 28).
-spec generate(binary(), binary(), binary(), list(message()), list(tool())) -> {ok,
        gemini_response()} |
    {error, binary()}.
generate(Api_key, Model, System_instruction, Messages, Tools) ->
    Url = <<<<<<"https://generativelanguage.googleapis.com/v1beta/models/"/utf8,
                Model/binary>>/binary,
            ":generateContent?key="/utf8>>/binary,
        Api_key/binary>>,
    Contents = gleam@list:map(
        Messages,
        fun(M) ->
            gleam@json:object(
                [{<<"role"/utf8>>,
                        gleam@json:string(case erlang:element(2, M) of
                                <<"assistant"/utf8>> ->
                                    <<"model"/utf8>>;

                                _ ->
                                    <<"user"/utf8>>
                            end)},
                    {<<"parts"/utf8>>,
                        gleam@json:array(
                            [gleam@json:object(
                                    [{<<"text"/utf8>>,
                                            gleam@json:string(
                                                erlang:element(3, M)
                                            )}]
                                )],
                            fun(X) -> X end
                        )}]
            )
        end
    ),
    Req_body_fields = [{<<"system_instruction"/utf8>>,
            gleam@json:object(
                [{<<"parts"/utf8>>,
                        gleam@json:array(
                            [gleam@json:object(
                                    [{<<"text"/utf8>>,
                                            gleam@json:string(
                                                System_instruction
                                            )}]
                                )],
                            fun(X@1) -> X@1 end
                        )}]
            )},
        {<<"contents"/utf8>>, gleam@json:array(Contents, fun(X@2) -> X@2 end)}],
    Req_body_fields@1 = case Tools of
        [] ->
            Req_body_fields;

        _ ->
            Tool_json = gleam@json:object(
                [{<<"function_declarations"/utf8>>,
                        gleam@json:array(
                            gleam@list:map(
                                Tools,
                                fun(T) ->
                                    gleam@json:object(
                                        [{<<"name"/utf8>>,
                                                gleam@json:string(
                                                    erlang:element(2, T)
                                                )},
                                            {<<"description"/utf8>>,
                                                gleam@json:string(
                                                    erlang:element(3, T)
                                                )},
                                            {<<"parameters"/utf8>>,
                                                erlang:element(4, T)}]
                                    )
                                end
                            ),
                            fun(X@3) -> X@3 end
                        )}]
            ),
            lists:append(
                Req_body_fields,
                [{<<"tools"/utf8>>,
                        gleam@json:array([Tool_json], fun(X@4) -> X@4 end)}]
            )
    end,
    Body = begin
        _pipe = gleam@json:object(Req_body_fields@1),
        gleam@json:to_string(_pipe)
    end,
    Req@1 = case gleam@http@request:to(Url) of
        {ok, Req} -> Req;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gclaw/provider/gemini"/utf8>>,
                        function => <<"generate"/utf8>>,
                        line => 76,
                        value => _assert_fail,
                        start => 1965,
                        'end' => 2001,
                        pattern_start => 1976,
                        pattern_end => 1983})
    end,
    Req@2 = begin
        _pipe@1 = Req@1,
        _pipe@2 = gleam@http@request:set_method(_pipe@1, post),
        _pipe@3 = gleam@http@request:set_header(
            _pipe@2,
            <<"content-type"/utf8>>,
            <<"application/json"/utf8>>
        ),
        gleam@http@request:set_body(_pipe@3, Body)
    end,
    case gleam@hackney:send(Req@2) of
        {ok, Resp} ->
            case erlang:element(2, Resp) of
                200 ->
                    decode_response(erlang:element(4, Resp));

                _ ->
                    {error,
                        <<<<<<"API Error "/utf8,
                                    (gleam@string:inspect(
                                        erlang:element(2, Resp)
                                    ))/binary>>/binary,
                                ": "/utf8>>/binary,
                            (erlang:element(4, Resp))/binary>>}
            end;

        {error, Err} ->
            {error,
                <<"HTTP Request failed: "/utf8,
                    (gleam@string:inspect(Err))/binary>>}
    end.

-file("src/gclaw/provider/gemini.gleam", 169).
-spec decode_embedding(binary()) -> {ok, list(float())} | {error, binary()}.
decode_embedding(Body_string) ->
    Embedding_decoder = (gleam@dynamic@decode:at(
        [<<"embedding"/utf8>>, <<"values"/utf8>>],
        gleam@dynamic@decode:list(
            {decoder, fun gleam@dynamic@decode:decode_float/1}
        )
    )),
    case gleam@json:parse(Body_string, Embedding_decoder) of
        {ok, Values} ->
            {ok, Values};

        {error, Err} ->
            {error,
                <<"Failed to decode embedding: "/utf8,
                    (gleam@string:inspect(Err))/binary>>}
    end.

-file("src/gclaw/provider/gemini.gleam", 93).
-spec embed(binary(), binary(), binary()) -> {ok, list(float())} |
    {error, binary()}.
embed(Api_key, Model, Text) ->
    Url = <<<<<<"https://generativelanguage.googleapis.com/v1beta/models/"/utf8,
                Model/binary>>/binary,
            ":embedContent?key="/utf8>>/binary,
        Api_key/binary>>,
    Body = begin
        _pipe = gleam@json:object(
            [{<<"content"/utf8>>,
                    gleam@json:object(
                        [{<<"parts"/utf8>>,
                                gleam@json:array(
                                    [gleam@json:object(
                                            [{<<"text"/utf8>>,
                                                    gleam@json:string(Text)}]
                                        )],
                                    fun(X) -> X end
                                )}]
                    )}]
        ),
        gleam@json:to_string(_pipe)
    end,
    Req@1 = case gleam@http@request:to(Url) of
        {ok, Req} -> Req;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gclaw/provider/gemini"/utf8>>,
                        function => <<"embed"/utf8>>,
                        line => 104,
                        value => _assert_fail,
                        start => 2851,
                        'end' => 2887,
                        pattern_start => 2862,
                        pattern_end => 2869})
    end,
    Req@2 = begin
        _pipe@1 = Req@1,
        _pipe@2 = gleam@http@request:set_method(_pipe@1, post),
        _pipe@3 = gleam@http@request:set_header(
            _pipe@2,
            <<"content-type"/utf8>>,
            <<"application/json"/utf8>>
        ),
        gleam@http@request:set_body(_pipe@3, Body)
    end,
    case gleam@hackney:send(Req@2) of
        {ok, Resp} ->
            case erlang:element(2, Resp) of
                200 ->
                    decode_embedding(erlang:element(4, Resp));

                _ ->
                    {error,
                        <<<<<<"Embedding API Error "/utf8,
                                    (gleam@string:inspect(
                                        erlang:element(2, Resp)
                                    ))/binary>>/binary,
                                ": "/utf8>>/binary,
                            (erlang:element(4, Resp))/binary>>}
            end;

        {error, Err} ->
            {error,
                <<"HTTP Request failed: "/utf8,
                    (gleam@string:inspect(Err))/binary>>}
    end.
