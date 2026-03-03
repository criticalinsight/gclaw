-module(gleamdb@reactive).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/reactive.gleam").
-export([start_link/0]).
-export_type([active_query/0, state/0]).

-type active_query() :: {active_query,
        list(gleamdb@shared@types:body_clause()),
        list(binary()),
        gleam@erlang@process:subject(gleamdb@shared@types:reactive_delta()),
        gleamdb@shared@types:query_result()}.

-type state() :: {state, list(active_query())}.

-file("src/gleamdb/reactive.gleam", 68).
-spec diff(
    gleamdb@shared@types:query_result(),
    gleamdb@shared@types:query_result()
) -> {gleamdb@shared@types:query_result(), gleamdb@shared@types:query_result()}.
diff(Old, New) ->
    Old_set = gleam@set:from_list(erlang:element(2, Old)),
    New_set = gleam@set:from_list(erlang:element(2, New)),
    Added_rows = begin
        _pipe = gleam@set:difference(New_set, Old_set),
        gleam@set:to_list(_pipe)
    end,
    Removed_rows = begin
        _pipe@1 = gleam@set:difference(Old_set, New_set),
        gleam@set:to_list(_pipe@1)
    end,
    {{query_result, Added_rows, erlang:element(3, New)},
        {query_result, Removed_rows, erlang:element(3, New)}}.

-file("src/gleamdb/reactive.gleam", 23).
-spec start_link() -> {ok,
        gleam@erlang@process:subject(gleamdb@shared@types:reactive_message())} |
    {error, gleam@otp@actor:start_error()}.
start_link() ->
    _pipe = gleam@otp@actor:new({state, []}),
    _pipe@1 = gleam@otp@actor:on_message(_pipe, fun(State, Msg) -> case Msg of
                {subscribe, Query, Attrs, Sub, Initial_state} ->
                    New_query = {active_query, Query, Attrs, Sub, Initial_state},
                    gleam@otp@actor:continue(
                        {state, [New_query | erlang:element(2, State)]}
                    );

                {notify, Changed_attrs, Db_state} ->
                    New_queries = gleam@list:filter_map(
                        erlang:element(2, State),
                        fun(Aq) ->
                            case gleamdb_process_ffi:is_alive(
                                erlang:element(4, Aq)
                            ) of
                                false ->
                                    {error, nil};

                                true ->
                                    Is_affected = gleam@list:any(
                                        Changed_attrs,
                                        fun(Ca) ->
                                            gleam@list:contains(
                                                erlang:element(3, Aq),
                                                Ca
                                            )
                                        end
                                    ),
                                    case Is_affected of
                                        true ->
                                            Current_result = gleamdb@engine:run(
                                                Db_state,
                                                erlang:element(2, Aq),
                                                [],
                                                none,
                                                none
                                            ),
                                            {Added, Removed} = diff(
                                                erlang:element(5, Aq),
                                                Current_result
                                            ),
                                            case (erlang:element(2, Added) =:= [])
                                            andalso (erlang:element(2, Removed)
                                            =:= []) of
                                                true ->
                                                    {ok, Aq};

                                                false ->
                                                    gleam@erlang@process:send(
                                                        erlang:element(4, Aq),
                                                        {delta, Added, Removed}
                                                    ),
                                                    {ok,
                                                        {active_query,
                                                            erlang:element(
                                                                2,
                                                                Aq
                                                            ),
                                                            erlang:element(
                                                                3,
                                                                Aq
                                                            ),
                                                            erlang:element(
                                                                4,
                                                                Aq
                                                            ),
                                                            Current_result}}
                                            end;

                                        false ->
                                            {ok, Aq}
                                    end
                            end
                        end
                    ),
                    gleam@otp@actor:continue({state, New_queries})
            end end),
    _pipe@2 = gleam@otp@actor:start(_pipe@1),
    gleam@result:map(_pipe@2, fun(Started) -> erlang:element(3, Started) end).
