-module(gclaw).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gclaw.gleam").
-export([main/0]).

-file("src/gclaw.gleam", 67).
-spec process_gemini(gclaw@memory:memory(), binary(), integer(), list(float())) -> nil.
process_gemini(Mem, Api_key, Ts, Embedding) ->
    Context = gclaw@memory:get_context_window(
        Mem,
        <<"user"/utf8>>,
        20,
        Embedding
    ),
    Sys_prompt = <<"You are OpenClaw (GClaw), a minimalist, fact-based AI assistant. Use tools when necessary."/utf8>>,
    Gemini_msgs = gleam@list:map(
        Context,
        fun(C) -> case gleam@string:split_once(C, <<": "/utf8>>) of
                {ok, {Role, Content}} ->
                    {message, Role, Content};

                {error, _} ->
                    {message, <<"user"/utf8>>, C}
            end end
    ),
    Tools = [{tool,
            <<"get_datetime"/utf8>>,
            <<"Get the current date and time."/utf8>>,
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"OBJECT"/utf8>>)},
                    {<<"properties"/utf8>>, gleam@json:object([])},
                    {<<"required"/utf8>>, gleam@json:array([], fun(X) -> X end)}]
            )}],
    case gclaw@provider@gemini:generate(
        Api_key,
        <<"gemini-1.5-flash"/utf8>>,
        Sys_prompt,
        Gemini_msgs,
        Tools
    ) of
        {ok, {text_response, Resp}} ->
            gleam_stdlib:println(<<"Claw: "/utf8, Resp/binary>>),
            Assist_eid = gleamdb@fact:deterministic_uid(
                <<"assist_"/utf8, (gleam@string:inspect(Ts))/binary>>
            ),
            Assist_facts = [{Assist_eid, <<"msg/content"/utf8>>, {str, Resp}},
                {Assist_eid, <<"msg/role"/utf8>>, {str, <<"assistant"/utf8>>}},
                {Assist_eid, <<"msg/session"/utf8>>, {str, <<"user"/utf8>>}},
                {Assist_eid, <<"msg/timestamp"/utf8>>, {int, Ts}}],
            _ = gclaw@memory:remember(Mem, Assist_facts),
            nil;

        {ok, {tool_call_response, Calls}} ->
            gleam@list:each(
                Calls,
                fun(Call) ->
                    gleam_stdlib:println(
                        <<"Executing tool: "/utf8,
                            (erlang:element(2, Call))/binary>>
                    ),
                    case erlang:element(2, Call) of
                        <<"get_datetime"/utf8>> ->
                            Result_str = <<"2026-02-14 05:15:00"/utf8>>,
                            gleam_stdlib:println(
                                <<"Tool Result: "/utf8, Result_str/binary>>
                            ),
                            Tool_eid = gleamdb@fact:deterministic_uid(
                                <<"tool_"/utf8,
                                    (gleam@string:inspect(Ts))/binary>>
                            ),
                            Tool_facts = [{Tool_eid,
                                    <<"msg/content"/utf8>>,
                                    {str,
                                        <<<<<<"Executed "/utf8,
                                                    (erlang:element(2, Call))/binary>>/binary,
                                                " -> "/utf8>>/binary,
                                            Result_str/binary>>}},
                                {Tool_eid,
                                    <<"msg/role"/utf8>>,
                                    {str, <<"assistant"/utf8>>}},
                                {Tool_eid,
                                    <<"msg/session"/utf8>>,
                                    {str, <<"user"/utf8>>}},
                                {Tool_eid, <<"msg/timestamp"/utf8>>, {int, Ts}}],
                            Mem@1 = gclaw@memory:remember(Mem, Tool_facts),
                            process_gemini(Mem@1, Api_key, Ts + 1, Embedding);

                        _ ->
                            gleam_stdlib:println(
                                <<"Unknown tool: "/utf8,
                                    (erlang:element(2, Call))/binary>>
                            )
                    end
                end
            );

        {error, Err} ->
            gleam_stdlib:println(<<"Error: "/utf8, Err/binary>>)
    end.

-file("src/gclaw.gleam", 32).
-spec chat_loop(gclaw@memory:memory(), binary()) -> nil.
chat_loop(Mem, Api_key) ->
    Input = begin
        _pipe = gclaw_ffi:get_line(<<"> "/utf8>>),
        _pipe@1 = gleam@result:unwrap(_pipe, <<""/utf8>>),
        gleam@string:trim(_pipe@1)
    end,
    case Input of
        <<"exit"/utf8>> ->
            gleam_stdlib:println(<<"Bye!"/utf8>>);

        <<"quit"/utf8>> ->
            gleam_stdlib:println(<<"Bye!"/utf8>>);

        _ ->
            Ts = 1707880000,
            Embedding = case gclaw@provider@gemini:embed(
                Api_key,
                <<"text-embedding-004"/utf8>>,
                Input
            ) of
                {ok, Vec} ->
                    Vec;

                {error, E} ->
                    gleam_stdlib:println(
                        <<"Warning: Embedding failed: "/utf8, E/binary>>
                    ),
                    []
            end,
            Msg_eid = gleamdb@fact:deterministic_uid(
                <<<<<<"msg_"/utf8, (gleam@string:inspect(Ts))/binary>>/binary,
                        "_"/utf8>>/binary,
                    Input/binary>>
            ),
            Msg_facts = [{Msg_eid, <<"msg/content"/utf8>>, {str, Input}},
                {Msg_eid, <<"msg/role"/utf8>>, {str, <<"user"/utf8>>}},
                {Msg_eid, <<"msg/session"/utf8>>, {str, <<"user"/utf8>>}},
                {Msg_eid, <<"msg/timestamp"/utf8>>, {int, Ts}}],
            Mem@1 = gclaw@memory:remember_semantic(Mem, Msg_facts, Embedding),
            process_gemini(Mem@1, Api_key, Ts + 1, Embedding),
            chat_loop(Mem@1, Api_key)
    end.

-file("src/gclaw.gleam", 17).
-spec main() -> nil.
main() ->
    Api_key = case gclaw_ffi:get_env(<<"GEMINI_API_KEY"/utf8>>) of
        {ok, K} ->
            K;

        {error, _} ->
            gleam_stdlib:println(<<"Warning: GEMINI_API_KEY not set"/utf8>>),
            <<""/utf8>>
    end,
    Mem = gclaw@memory:init_persistent(<<"gclaw.db"/utf8>>),
    gleam_stdlib:println(
        <<"🧙🏾‍♂️: GClaw initialized. How can I help you today?"/utf8>>
    ),
    chat_loop(Mem, Api_key).
