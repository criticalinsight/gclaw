-module(gleamdb@transactor).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/transactor.gleam").
-export([transact_with_timeout/3, retract_with_timeout/3, get_state/1, set_schema_with_timeout/4, set_schema/3, transact/2, retract/2, register_function/3, register_predicate/3, store_rule/2, create_bm25_index/2, register_composite/2, set_config/2, compute_next_state/4, start_named/2, start_distributed/2, start_with_timeout/2, start/1, register_index_adapter/2, create_index/4]).
-export_type([message/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type message() :: {transact,
        list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
        gleam@option:option(integer()),
        gleam@erlang@process:subject({ok, gleamdb@shared@types:db_state()} |
            {error, binary()})} |
    {retract,
        list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
        gleam@option:option(integer()),
        gleam@erlang@process:subject({ok, gleamdb@shared@types:db_state()} |
            {error, binary()})} |
    {get_state, gleam@erlang@process:subject(gleamdb@shared@types:db_state())} |
    {set_schema,
        binary(),
        gleamdb@fact:attribute_config(),
        gleam@erlang@process:subject({ok, nil} | {error, binary()})} |
    {register_function,
        binary(),
        fun((gleamdb@shared@types:db_state(), integer(), integer(), list(gleamdb@fact:value())) -> list({gleamdb@fact:eid(),
            binary(),
            gleamdb@fact:value()})),
        gleam@erlang@process:subject(nil)} |
    {register_predicate,
        binary(),
        fun((gleamdb@fact:value()) -> boolean()),
        gleam@erlang@process:subject(nil)} |
    {register_composite,
        list(binary()),
        gleam@erlang@process:subject({ok, nil} | {error, binary()})} |
    {store_rule,
        gleamdb@shared@types:rule(),
        gleam@erlang@process:subject({ok, nil} | {error, binary()})} |
    {set_reactive,
        gleam@erlang@process:subject(gleamdb@shared@types:reactive_message())} |
    {join, gleam@erlang@process:pid_()} |
    {sync_datoms, list(gleamdb@fact:datom())} |
    {raft_msg, gleamdb@raft:raft_message()} |
    {compact, gleam@erlang@process:subject(nil)} |
    {set_config,
        gleamdb@shared@types:config(),
        gleam@erlang@process:subject(nil)} |
    {sync, gleam@erlang@process:subject(nil)} |
    {boot,
        gleam@option:option(binary()),
        gleamdb@storage:storage_adapter(),
        gleam@erlang@process:subject(nil)} |
    {register_index_adapter,
        gleamdb@shared@types:index_adapter(),
        gleam@erlang@process:subject(nil)} |
    {create_index,
        binary(),
        binary(),
        binary(),
        gleam@erlang@process:subject({ok, nil} | {error, binary()})} |
    {create_b_m25_index,
        binary(),
        gleam@erlang@process:subject({ok, nil} | {error, binary()})}.

-file("src/gleamdb/transactor.gleam", 397).
-spec print_config_update(gleamdb@shared@types:config()) -> nil.
print_config_update(Config) ->
    Msg = <<<<<<"Config updated: threshold="/utf8,
                (erlang:integer_to_binary(erlang:element(2, Config)))/binary>>/binary,
            ", batch="/utf8>>/binary,
        (erlang:integer_to_binary(erlang:element(3, Config)))/binary>>,
    case io:format(Msg) of
        _ ->
            nil
    end.

-file("src/gleamdb/transactor.gleam", 408).
-spec is_leader(gleamdb@shared@types:db_state()) -> boolean().
is_leader(State) ->
    case erlang:element(13, State) of
        false ->
            true;

        true ->
            gleamdb@raft:is_leader(erlang:element(15, State))
    end.

-file("src/gleamdb/transactor.gleam", 422).
-spec execute_raft_effect(
    gleamdb@raft:raft_effect(),
    gleam@erlang@process:pid_()
) -> nil.
execute_raft_effect(Effect, Self_pid) ->
    case Effect of
        {send_heartbeat, To, Term, Leader} ->
            Target = gleamdb_process_ffi:pid_to_subject(To),
            gleam@erlang@process:send(
                Target,
                {raft_msg, {heartbeat, Term, Leader}}
            ),
            nil;

        {send_vote_request, To@1, Term@1, Candidate} ->
            Target@1 = gleamdb_process_ffi:pid_to_subject(To@1),
            gleam@erlang@process:send(
                Target@1,
                {raft_msg, {vote_request, Term@1, Candidate}}
            ),
            nil;

        {send_vote_response, To@2, Term@2, Granted} ->
            Target@2 = gleamdb_process_ffi:pid_to_subject(To@2),
            gleam@erlang@process:send(
                Target@2,
                {raft_msg, {vote_response, Term@2, Granted, Self_pid}}
            ),
            nil;

        register_as_leader ->
            _ = gleamdb_global_ffi:register(<<"gleamdb_leader"/utf8>>, Self_pid),
            nil;

        unregister_as_leader ->
            gleamdb_global_ffi:unregister(<<"gleamdb_leader"/utf8>>);

        reset_election_timer ->
            nil;

        start_heartbeat_timer ->
            nil;

        stop_heartbeat_timer ->
            nil
    end.

-file("src/gleamdb/transactor.gleam", 416).
?DOC(" Execute a list of Raft effects — the effectful shell around the pure state machine.\n").
-spec execute_raft_effects(
    gleamdb@shared@types:db_state(),
    list(gleamdb@raft:raft_effect()),
    gleam@erlang@process:pid_()
) -> nil.
execute_raft_effects(_, Effects, Self_pid) ->
    gleam@list:each(
        Effects,
        fun(Effect) -> execute_raft_effect(Effect, Self_pid) end
    ).

-file("src/gleamdb/transactor.gleam", 462).
-spec transact_with_timeout(
    gleam@erlang@process:subject(message()),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
    integer()
) -> {ok, gleamdb@shared@types:db_state()} | {error, binary()}.
transact_with_timeout(Db, Facts, Timeout_ms) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {transact, Facts, none, Reply}),
    case gleam@erlang@process:'receive'(Reply, Timeout_ms) of
        {ok, Res} ->
            Res;

        {error, _} ->
            {error, <<"Timeout"/utf8>>}
    end.

-file("src/gleamdb/transactor.gleam", 475).
-spec retract_with_timeout(
    gleam@erlang@process:subject(message()),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
    integer()
) -> {ok, gleamdb@shared@types:db_state()} | {error, binary()}.
retract_with_timeout(Db, Facts, Timeout_ms) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {retract, Facts, none, Reply}),
    case gleam@erlang@process:'receive'(Reply, Timeout_ms) of
        {ok, Res} ->
            Res;

        {error, _} ->
            {error, <<"Timeout"/utf8>>}
    end.

-file("src/gleamdb/transactor.gleam", 488).
-spec get_state(gleam@erlang@process:subject(message())) -> gleamdb@shared@types:db_state().
get_state(Db) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {get_state, Reply}),
    gleam_erlang_ffi:'receive'(Reply).

-file("src/gleamdb/transactor.gleam", 498).
-spec set_schema_with_timeout(
    gleam@erlang@process:subject(message()),
    binary(),
    gleamdb@fact:attribute_config(),
    integer()
) -> {ok, nil} | {error, binary()}.
set_schema_with_timeout(Db, Attr, Config, Timeout_ms) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {set_schema, Attr, Config, Reply}),
    case gleam@erlang@process:'receive'(Reply, Timeout_ms) of
        {ok, Res} ->
            Res;

        {error, _} ->
            {error, <<"Timeout"/utf8>>}
    end.

-file("src/gleamdb/transactor.gleam", 494).
-spec set_schema(
    gleam@erlang@process:subject(message()),
    binary(),
    gleamdb@fact:attribute_config()
) -> {ok, nil} | {error, binary()}.
set_schema(Db, Attr, Config) ->
    set_schema_with_timeout(Db, Attr, Config, 5000).

-file("src/gleamdb/transactor.gleam", 540).
-spec filter_active(list(gleamdb@fact:datom())) -> list(gleamdb@fact:datom()).
filter_active(Datoms) ->
    Latest = gleam@list:fold(
        Datoms,
        maps:new(),
        fun(Acc, D) ->
            Key = {erlang:element(2, D),
                erlang:element(3, D),
                erlang:element(4, D)},
            case gleam_stdlib:map_get(Acc, Key) of
                {ok, {Tx, _}} when Tx > erlang:element(5, D) ->
                    Acc;

                _ ->
                    gleam@dict:insert(
                        Acc,
                        Key,
                        {erlang:element(5, D), erlang:element(7, D)}
                    )
            end
        end
    ),
    gleam@list:filter(
        Datoms,
        fun(D@1) ->
            Key@1 = {erlang:element(2, D@1),
                erlang:element(3, D@1),
                erlang:element(4, D@1)},
            case gleam_stdlib:map_get(Latest, Key@1) of
                {ok, {Tx@1, Op}} ->
                    (Tx@1 =:= erlang:element(5, D@1)) andalso (Op =:= assert);

                _ ->
                    false
            end
        end
    ).

-file("src/gleamdb/transactor.gleam", 678).
-spec resolve_transaction_functions(
    gleamdb@shared@types:db_state(),
    integer(),
    integer(),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()})
) -> list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}).
resolve_transaction_functions(State, Tx_id, Vt, Facts) ->
    gleam@list:flat_map(Facts, fun(F) -> case erlang:element(1, F) of
                {lookup, {<<"db/fn"/utf8>>, {str, Fn_name}}} ->
                    case gleam_stdlib:map_get(erlang:element(9, State), Fn_name) of
                        {ok, Func} ->
                            Args = case erlang:element(3, F) of
                                {list, L} ->
                                    L;

                                _ ->
                                    [erlang:element(3, F)]
                            end,
                            New_facts = Func(State, Tx_id, Vt, Args),
                            resolve_transaction_functions(
                                State,
                                Tx_id,
                                Vt,
                                New_facts
                            );

                        {error, _} ->
                            [F]
                    end;

                _ ->
                    [F]
            end end).

-file("src/gleamdb/transactor.gleam", 699).
-spec check_composite_uniqueness(
    gleamdb@shared@types:db_state(),
    gleamdb@fact:datom()
) -> {ok, nil} | {error, binary()}.
check_composite_uniqueness(State, Datom) ->
    Composites = gleam@list:filter(
        erlang:element(10, State),
        fun(C) -> gleam@list:contains(C, erlang:element(3, Datom)) end
    ),
    gleam@list:fold_until(
        Composites,
        {ok, nil},
        fun(_, Composite) ->
            Values_res = gleam@list:fold_until(
                Composite,
                {ok, []},
                fun(Acc_res, Attr) ->
                    Acc@1 = case Acc_res of
                        {ok, Acc} -> Acc;
                        _assert_fail ->
                            erlang:error(#{gleam_error => let_assert,
                                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                        file => <<?FILEPATH/utf8>>,
                                        module => <<"gleamdb/transactor"/utf8>>,
                                        function => <<"check_composite_uniqueness"/utf8>>,
                                        line => 705,
                                        value => _assert_fail,
                                        start => 25096,
                                        'end' => 25124,
                                        pattern_start => 25107,
                                        pattern_end => 25114})
                    end,
                    Val = case Attr =:= erlang:element(3, Datom) of
                        true ->
                            {ok, erlang:element(4, Datom)};

                        false ->
                            Existing = begin
                                _pipe = gleamdb@index:get_datoms_by_entity_attr(
                                    erlang:element(3, State),
                                    erlang:element(2, Datom),
                                    Attr
                                ),
                                filter_active(_pipe)
                            end,
                            case gleam@list:first(Existing) of
                                {ok, D} ->
                                    {ok, erlang:element(4, D)};

                                {error, _} ->
                                    {error, nil}
                            end
                    end,
                    case Val of
                        {ok, V} ->
                            {continue, {ok, [{Attr, V} | Acc@1]}};

                        {error, _} ->
                            {stop, {error, nil}}
                    end
                end
            ),
            case Values_res of
                {error, _} ->
                    {continue, {ok, nil}};

                {ok, Attr_vals} ->
                    Clauses = gleam@list:map(
                        Attr_vals,
                        fun(Pair) ->
                            {positive,
                                {{var, <<"e"/utf8>>},
                                    erlang:element(1, Pair),
                                    {val, erlang:element(2, Pair)}}}
                        end
                    ),
                    Results = gleamdb@engine:run(State, Clauses, [], none, none),
                    Has_violation = gleam@list:any(
                        erlang:element(2, Results),
                        fun(Binding) ->
                            case gleam_stdlib:map_get(Binding, <<"e"/utf8>>) of
                                {ok, {ref, Eid}} ->
                                    Eid /= erlang:element(2, Datom);

                                {ok, {int, Eid@1}} ->
                                    {entity_id, Eid@1} /= erlang:element(
                                        2,
                                        Datom
                                    );

                                _ ->
                                    false
                            end
                        end
                    ),
                    case Has_violation of
                        true ->
                            {stop,
                                {error,
                                    <<"Composite uniqueness violation: "/utf8,
                                        (gleam@string:inspect(Composite))/binary>>}};

                        false ->
                            {continue, {ok, nil}}
                    end
            end
        end
    ).

-file("src/gleamdb/transactor.gleam", 748).
-spec transact(
    gleam@erlang@process:subject(message()),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()})
) -> {ok, gleamdb@shared@types:db_state()} | {error, binary()}.
transact(Db, Facts) ->
    transact_with_timeout(Db, Facts, 5000).

-file("src/gleamdb/transactor.gleam", 787).
-spec apply_datom_bm25(gleamdb@shared@types:db_state(), gleamdb@fact:datom()) -> gleamdb@shared@types:db_state().
apply_datom_bm25(State, Datom) ->
    case gleam_stdlib:map_get(
        erlang:element(17, State),
        erlang:element(3, Datom)
    ) of
        {ok, Index} ->
            case erlang:element(4, Datom) of
                {str, Text} ->
                    New_index = case erlang:element(7, Datom) of
                        assert ->
                            gleamdb@index@bm25:add(
                                Index,
                                erlang:element(2, Datom),
                                Text
                            );

                        retract ->
                            gleamdb@index@bm25:remove(
                                Index,
                                erlang:element(2, Datom),
                                Text
                            )
                    end,
                    New_indices = gleam@dict:insert(
                        erlang:element(17, State),
                        erlang:element(3, Datom),
                        New_index
                    ),
                    {db_state,
                        erlang:element(2, State),
                        erlang:element(3, State),
                        erlang:element(4, State),
                        erlang:element(5, State),
                        erlang:element(6, State),
                        erlang:element(7, State),
                        erlang:element(8, State),
                        erlang:element(9, State),
                        erlang:element(10, State),
                        erlang:element(11, State),
                        erlang:element(12, State),
                        erlang:element(13, State),
                        erlang:element(14, State),
                        erlang:element(15, State),
                        erlang:element(16, State),
                        New_indices,
                        erlang:element(18, State),
                        erlang:element(19, State),
                        erlang:element(20, State),
                        erlang:element(21, State),
                        erlang:element(22, State),
                        erlang:element(23, State),
                        erlang:element(24, State)};

                _ ->
                    State
            end;

        {error, _} ->
            State
    end.

-file("src/gleamdb/transactor.gleam", 806).
-spec apply_datom_extensions(
    gleamdb@shared@types:db_state(),
    gleamdb@fact:datom()
) -> gleamdb@shared@types:db_state().
apply_datom_extensions(State, Datom) ->
    New_extensions = gleam@dict:map_values(
        erlang:element(20, State),
        fun(_, Instance) ->
            case erlang:element(3, Instance) =:= erlang:element(3, Datom) of
                true ->
                    case gleam_stdlib:map_get(
                        erlang:element(19, State),
                        erlang:element(2, Instance)
                    ) of
                        {ok, Adapter} ->
                            New_data = (erlang:element(4, Adapter))(
                                erlang:element(4, Instance),
                                [Datom]
                            ),
                            {extension_instance,
                                erlang:element(2, Instance),
                                erlang:element(3, Instance),
                                New_data};

                        {error, _} ->
                            Instance
                    end;

                false ->
                    Instance
            end
        end
    ),
    {db_state,
        erlang:element(2, State),
        erlang:element(3, State),
        erlang:element(4, State),
        erlang:element(5, State),
        erlang:element(6, State),
        erlang:element(7, State),
        erlang:element(8, State),
        erlang:element(9, State),
        erlang:element(10, State),
        erlang:element(11, State),
        erlang:element(12, State),
        erlang:element(13, State),
        erlang:element(14, State),
        erlang:element(15, State),
        erlang:element(16, State),
        erlang:element(17, State),
        erlang:element(18, State),
        erlang:element(19, State),
        New_extensions,
        erlang:element(21, State),
        erlang:element(22, State),
        erlang:element(23, State),
        erlang:element(24, State)}.

-file("src/gleamdb/transactor.gleam", 824).
-spec apply_datom_art(gleamdb@shared@types:db_state(), gleamdb@fact:datom()) -> gleamdb@shared@types:db_state().
apply_datom_art(State, Datom) ->
    case erlang:element(4, Datom) of
        {str, _} ->
            New_art = case erlang:element(7, Datom) of
                assert ->
                    gleamdb@index@art:insert(
                        erlang:element(18, State),
                        erlang:element(4, Datom),
                        erlang:element(2, Datom)
                    );

                retract ->
                    gleamdb@index@art:delete(
                        erlang:element(18, State),
                        erlang:element(4, Datom),
                        erlang:element(2, Datom)
                    )
            end,
            {db_state,
                erlang:element(2, State),
                erlang:element(3, State),
                erlang:element(4, State),
                erlang:element(5, State),
                erlang:element(6, State),
                erlang:element(7, State),
                erlang:element(8, State),
                erlang:element(9, State),
                erlang:element(10, State),
                erlang:element(11, State),
                erlang:element(12, State),
                erlang:element(13, State),
                erlang:element(14, State),
                erlang:element(15, State),
                erlang:element(16, State),
                erlang:element(17, State),
                New_art,
                erlang:element(19, State),
                erlang:element(20, State),
                erlang:element(21, State),
                erlang:element(22, State),
                erlang:element(23, State),
                erlang:element(24, State)};

        _ ->
            State
    end.

-file("src/gleamdb/transactor.gleam", 837).
-spec apply_datom_no_vector(
    gleamdb@shared@types:db_state(),
    gleamdb@fact:datom()
) -> gleamdb@shared@types:db_state().
apply_datom_no_vector(State, Datom) ->
    Config = begin
        _pipe = gleam_stdlib:map_get(
            erlang:element(8, State),
            erlang:element(3, Datom)
        ),
        gleam@result:unwrap(
            _pipe,
            {attribute_config, false, false, all, many, none}
        )
    end,
    Retention = erlang:element(4, Config),
    State@1 = case erlang:element(3, Datom) of
        <<"_rule/content"/utf8>> ->
            case {erlang:element(4, Datom), erlang:element(7, Datom)} of
                {{str, Encoded}, assert} ->
                    case gleamdb@rule_serde:deserialize(Encoded) of
                        {ok, Rule} ->
                            {db_state,
                                erlang:element(2, State),
                                erlang:element(3, State),
                                erlang:element(4, State),
                                erlang:element(5, State),
                                erlang:element(6, State),
                                erlang:element(7, State),
                                erlang:element(8, State),
                                erlang:element(9, State),
                                erlang:element(10, State),
                                erlang:element(11, State),
                                erlang:element(12, State),
                                erlang:element(13, State),
                                erlang:element(14, State),
                                erlang:element(15, State),
                                erlang:element(16, State),
                                erlang:element(17, State),
                                erlang:element(18, State),
                                erlang:element(19, State),
                                erlang:element(20, State),
                                erlang:element(21, State),
                                [Rule | erlang:element(22, State)],
                                erlang:element(23, State),
                                erlang:element(24, State)};

                        _ ->
                            State
                    end;

                {_, _} ->
                    State
            end;

        <<"_meta/composite"/utf8>> ->
            case {erlang:element(4, Datom), erlang:element(7, Datom)} of
                {{str, Attrs_str}, assert} ->
                    Attrs = gleam@string:split(Attrs_str, <<","/utf8>>),
                    case gleam@list:contains(erlang:element(10, State), Attrs) of
                        true ->
                            State;

                        false ->
                            {db_state,
                                erlang:element(2, State),
                                erlang:element(3, State),
                                erlang:element(4, State),
                                erlang:element(5, State),
                                erlang:element(6, State),
                                erlang:element(7, State),
                                erlang:element(8, State),
                                erlang:element(9, State),
                                [Attrs | erlang:element(10, State)],
                                erlang:element(11, State),
                                erlang:element(12, State),
                                erlang:element(13, State),
                                erlang:element(14, State),
                                erlang:element(15, State),
                                erlang:element(16, State),
                                erlang:element(17, State),
                                erlang:element(18, State),
                                erlang:element(19, State),
                                erlang:element(20, State),
                                erlang:element(21, State),
                                erlang:element(22, State),
                                erlang:element(23, State),
                                erlang:element(24, State)}
                    end;

                {_, _} ->
                    State
            end;

        _ ->
            State
    end,
    case erlang:element(14, State@1) of
        {some, Name} ->
            case Retention of
                latest_only ->
                    gleamdb@index@ets:prune_historical(
                        <<Name/binary, "_eavt"/utf8>>,
                        erlang:element(2, Datom),
                        erlang:element(3, Datom)
                    ),
                    gleamdb@index@ets:prune_historical_aevt(
                        <<Name/binary, "_aevt"/utf8>>,
                        erlang:element(3, Datom),
                        erlang:element(2, Datom)
                    );

                _ ->
                    nil
            end,
            gleamdb@index@ets:insert_datom(
                <<Name/binary, "_eavt"/utf8>>,
                erlang:element(2, Datom),
                Datom
            ),
            gleamdb@index@ets:insert_datom(
                <<Name/binary, "_aevt"/utf8>>,
                erlang:element(3, Datom),
                Datom
            ),
            case erlang:element(7, Datom) of
                assert ->
                    gleamdb@index@ets:insert_avet(
                        <<Name/binary, "_avet"/utf8>>,
                        {erlang:element(3, Datom), erlang:element(4, Datom)},
                        erlang:element(2, Datom)
                    );

                retract ->
                    gleamdb@index@ets:delete(
                        <<Name/binary, "_avet"/utf8>>,
                        {erlang:element(3, Datom), erlang:element(4, Datom)}
                    )
            end,
            State@1;

        none ->
            case erlang:element(7, Datom) of
                assert ->
                    {db_state,
                        erlang:element(2, State@1),
                        gleamdb@index:insert_eavt(
                            erlang:element(3, State@1),
                            Datom,
                            Retention
                        ),
                        gleamdb@index:insert_aevt(
                            erlang:element(4, State@1),
                            Datom,
                            Retention
                        ),
                        gleamdb@index:insert_avet(
                            erlang:element(5, State@1),
                            Datom
                        ),
                        erlang:element(6, State@1),
                        erlang:element(7, State@1),
                        erlang:element(8, State@1),
                        erlang:element(9, State@1),
                        erlang:element(10, State@1),
                        erlang:element(11, State@1),
                        erlang:element(12, State@1),
                        erlang:element(13, State@1),
                        erlang:element(14, State@1),
                        erlang:element(15, State@1),
                        erlang:element(16, State@1),
                        erlang:element(17, State@1),
                        erlang:element(18, State@1),
                        erlang:element(19, State@1),
                        erlang:element(20, State@1),
                        erlang:element(21, State@1),
                        erlang:element(22, State@1),
                        erlang:element(23, State@1),
                        erlang:element(24, State@1)};

                retract ->
                    {db_state,
                        erlang:element(2, State@1),
                        gleamdb@index:delete_eavt(
                            erlang:element(3, State@1),
                            Datom
                        ),
                        gleamdb@index:delete_aevt(
                            erlang:element(4, State@1),
                            Datom
                        ),
                        gleamdb@index:delete_avet(
                            erlang:element(5, State@1),
                            Datom
                        ),
                        erlang:element(6, State@1),
                        erlang:element(7, State@1),
                        erlang:element(8, State@1),
                        erlang:element(9, State@1),
                        erlang:element(10, State@1),
                        erlang:element(11, State@1),
                        erlang:element(12, State@1),
                        erlang:element(13, State@1),
                        erlang:element(14, State@1),
                        erlang:element(15, State@1),
                        erlang:element(16, State@1),
                        erlang:element(17, State@1),
                        erlang:element(18, State@1),
                        erlang:element(19, State@1),
                        erlang:element(20, State@1),
                        erlang:element(21, State@1),
                        erlang:element(22, State@1),
                        erlang:element(23, State@1),
                        erlang:element(24, State@1)}
            end
    end.

-file("src/gleamdb/transactor.gleam", 910).
-spec apply_datom_vector_only(
    gleamdb@shared@types:db_state(),
    gleamdb@fact:datom()
) -> gleamdb@shared@types:db_state().
apply_datom_vector_only(State, Datom) ->
    case erlang:element(7, Datom) of
        assert ->
            New_vec_idx = case erlang:element(4, Datom) of
                {vec, V} ->
                    gleamdb@vec_index:insert(
                        erlang:element(16, State),
                        erlang:element(2, Datom),
                        V
                    );

                _ ->
                    erlang:element(16, State)
            end,
            {db_state,
                erlang:element(2, State),
                erlang:element(3, State),
                erlang:element(4, State),
                erlang:element(5, State),
                erlang:element(6, State),
                erlang:element(7, State),
                erlang:element(8, State),
                erlang:element(9, State),
                erlang:element(10, State),
                erlang:element(11, State),
                erlang:element(12, State),
                erlang:element(13, State),
                erlang:element(14, State),
                erlang:element(15, State),
                New_vec_idx,
                erlang:element(17, State),
                erlang:element(18, State),
                erlang:element(19, State),
                erlang:element(20, State),
                erlang:element(21, State),
                erlang:element(22, State),
                erlang:element(23, State),
                erlang:element(24, State)};

        retract ->
            New_vec_idx@1 = case erlang:element(4, Datom) of
                {vec, _} ->
                    gleamdb@vec_index:delete(
                        erlang:element(16, State),
                        erlang:element(2, Datom)
                    );

                _ ->
                    erlang:element(16, State)
            end,
            {db_state,
                erlang:element(2, State),
                erlang:element(3, State),
                erlang:element(4, State),
                erlang:element(5, State),
                erlang:element(6, State),
                erlang:element(7, State),
                erlang:element(8, State),
                erlang:element(9, State),
                erlang:element(10, State),
                erlang:element(11, State),
                erlang:element(12, State),
                erlang:element(13, State),
                erlang:element(14, State),
                erlang:element(15, State),
                New_vec_idx@1,
                erlang:element(17, State),
                erlang:element(18, State),
                erlang:element(19, State),
                erlang:element(20, State),
                erlang:element(21, State),
                erlang:element(22, State),
                erlang:element(23, State),
                erlang:element(24, State)}
    end.

-file("src/gleamdb/transactor.gleam", 557).
-spec recover_state(gleamdb@shared@types:db_state()) -> gleamdb@shared@types:db_state().
recover_state(State) ->
    case (erlang:element(5, erlang:element(2, State)))() of
        {ok, Datoms} ->
            {Inter_state, Max_tx} = gleam@list:fold(
                Datoms,
                {State, 0},
                fun(Acc, D) ->
                    {Curr_state, Curr_max} = Acc,
                    Next_state = apply_datom_no_vector(Curr_state, D),
                    Next_max = case erlang:element(5, D) > Curr_max of
                        true ->
                            erlang:element(5, D);

                        false ->
                            Curr_max
                    end,
                    {Next_state, Next_max}
                end
            ),
            Active_datoms = filter_active(Datoms),
            Final_state = gleam@list:fold(
                Active_datoms,
                Inter_state,
                fun(Acc@1, D@1) -> apply_datom_vector_only(Acc@1, D@1) end
            ),
            {db_state,
                erlang:element(2, Final_state),
                erlang:element(3, Final_state),
                erlang:element(4, Final_state),
                erlang:element(5, Final_state),
                Max_tx,
                erlang:element(7, Final_state),
                erlang:element(8, Final_state),
                erlang:element(9, Final_state),
                erlang:element(10, Final_state),
                erlang:element(11, Final_state),
                erlang:element(12, Final_state),
                erlang:element(13, Final_state),
                erlang:element(14, Final_state),
                erlang:element(15, Final_state),
                erlang:element(16, Final_state),
                erlang:element(17, Final_state),
                erlang:element(18, Final_state),
                erlang:element(19, Final_state),
                erlang:element(20, Final_state),
                erlang:element(21, Final_state),
                erlang:element(22, Final_state),
                erlang:element(23, Final_state),
                erlang:element(24, Final_state)};

        {error, _} ->
            State
    end.

-file("src/gleamdb/transactor.gleam", 772).
-spec apply_datom(gleamdb@shared@types:db_state(), gleamdb@fact:datom()) -> gleamdb@shared@types:db_state().
apply_datom(State, Datom) ->
    Datom@1 = case erlang:element(4, Datom) of
        {vec, V} ->
            {datom,
                erlang:element(2, Datom),
                erlang:element(3, Datom),
                {vec, gleamdb@vector:normalize(V)},
                erlang:element(5, Datom),
                erlang:element(6, Datom),
                erlang:element(7, Datom)};

        _ ->
            Datom
    end,
    _pipe = State,
    apply_datom_no_vector(_pipe, Datom@1),
    State@1 = apply_datom_art(State, Datom@1),
    State@2 = apply_datom_extensions(State@1, Datom@1),
    State@3 = apply_datom_bm25(State@2, Datom@1),
    _pipe@1 = State@3,
    _pipe@2 = apply_datom_no_vector(_pipe@1, Datom@1),
    apply_datom_vector_only(_pipe@2, Datom@1).

-file("src/gleamdb/transactor.gleam", 752).
-spec retract_recursive_collected(
    gleamdb@shared@types:db_state(),
    gleamdb@fact:entity_id(),
    integer(),
    integer(),
    list(gleamdb@fact:datom())
) -> {gleamdb@shared@types:db_state(), list(gleamdb@fact:datom())}.
retract_recursive_collected(State, Eid, Tx_id, Valid_time, Acc) ->
    Children = begin
        _pipe = gleamdb@index:filter_by_entity(erlang:element(3, State), Eid),
        filter_active(_pipe)
    end,
    gleam@list:fold(
        Children,
        {State, Acc},
        fun(Curr, D) ->
            {Curr_state, Curr_acc} = Curr,
            Config = begin
                _pipe@1 = gleam_stdlib:map_get(
                    erlang:element(8, Curr_state),
                    erlang:element(3, D)
                ),
                gleam@result:unwrap(
                    _pipe@1,
                    {attribute_config, false, false, all, many, none}
                )
            end,
            {Sub_state, Sub_acc} = case erlang:element(3, Config) of
                true ->
                    case erlang:element(4, D) of
                        {ref, {entity_id, Sub_id}} ->
                            retract_recursive_collected(
                                Curr_state,
                                {entity_id, Sub_id},
                                Tx_id,
                                Valid_time,
                                Curr_acc
                            );

                        {int, Sub_id@1} ->
                            retract_recursive_collected(
                                Curr_state,
                                {entity_id, Sub_id@1},
                                Tx_id,
                                Valid_time,
                                Curr_acc
                            );

                        _ ->
                            {Curr_state, Curr_acc}
                    end;

                false ->
                    {Curr_state, Curr_acc}
            end,
            Retract_datom = {datom,
                erlang:element(2, D),
                erlang:element(3, D),
                erlang:element(4, D),
                Tx_id,
                Valid_time,
                retract},
            {apply_datom(Sub_state, Retract_datom), [Retract_datom | Sub_acc]}
        end
    ).

-file("src/gleamdb/transactor.gleam", 931).
-spec retract(
    gleam@erlang@process:subject(message()),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()})
) -> {ok, gleamdb@shared@types:db_state()} | {error, binary()}.
retract(Db, Facts) ->
    retract_with_timeout(Db, Facts, 5000).

-file("src/gleamdb/transactor.gleam", 935).
-spec register_function(
    gleam@erlang@process:subject(message()),
    binary(),
    fun((gleamdb@shared@types:db_state(), integer(), integer(), list(gleamdb@fact:value())) -> list({gleamdb@fact:eid(),
        binary(),
        gleamdb@fact:value()}))
) -> nil.
register_function(Db, Name, Func) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {register_function, Name, Func, Reply}),
    _ = gleam@erlang@process:'receive'(Reply, 5000),
    nil.

-file("src/gleamdb/transactor.gleam", 946).
-spec register_predicate(
    gleam@erlang@process:subject(message()),
    binary(),
    fun((gleamdb@fact:value()) -> boolean())
) -> nil.
register_predicate(Db, Name, Pred) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {register_predicate, Name, Pred, Reply}),
    _ = gleam@erlang@process:'receive'(Reply, 5000),
    nil.

-file("src/gleamdb/transactor.gleam", 957).
-spec store_rule(
    gleam@erlang@process:subject(message()),
    gleamdb@shared@types:rule()
) -> {ok, nil} | {error, binary()}.
store_rule(Db, Rule) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {store_rule, Rule, Reply}),
    case gleam@erlang@process:'receive'(Reply, 5000) of
        {ok, Res} ->
            Res;

        {error, _} ->
            {error, <<"Timeout storing rule"/utf8>>}
    end.

-file("src/gleamdb/transactor.gleam", 966).
-spec create_bm25_index(gleam@erlang@process:subject(message()), binary()) -> {ok,
        nil} |
    {error, binary()}.
create_bm25_index(Db, Attribute) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {create_b_m25_index, Attribute, Reply}),
    case gleam@erlang@process:'receive'(Reply, 5000) of
        {ok, Res} ->
            Res;

        {error, _} ->
            {error, <<"Timeout creating BM25 index"/utf8>>}
    end.

-file("src/gleamdb/transactor.gleam", 975).
-spec register_composite(
    gleam@erlang@process:subject(message()),
    list(binary())
) -> {ok, nil} | {error, binary()}.
register_composite(Db, Attrs) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {register_composite, Attrs, Reply}),
    case gleam@erlang@process:'receive'(Reply, 5000) of
        {ok, Res} ->
            Res;

        {error, _} ->
            {error, <<"Timeout registering composite"/utf8>>}
    end.

-file("src/gleamdb/transactor.gleam", 984).
-spec set_config(
    gleam@erlang@process:subject(message()),
    gleamdb@shared@types:config()
) -> nil.
set_config(Db, Config) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {set_config, Config, Reply}),
    _ = gleam@erlang@process:'receive'(Reply, 5000),
    nil.

-file("src/gleamdb/transactor.gleam", 991).
-spec resolve_eid(gleamdb@shared@types:db_state(), gleamdb@fact:eid()) -> gleam@option:option(gleamdb@fact:entity_id()).
resolve_eid(State, Eid) ->
    case Eid of
        {uid, Id} ->
            {some, Id};

        {lookup, {A, V}} ->
            _pipe = gleamdb@index:get_entity_by_av(
                erlang:element(5, State),
                A,
                V
            ),
            gleam@option:from_result(_pipe)
    end.

-file("src/gleamdb/transactor.gleam", 998).
-spec check_constraints(gleamdb@shared@types:db_state(), gleamdb@fact:datom()) -> {ok,
        nil} |
    {error, binary()}.
check_constraints(State, Datom) ->
    Config = begin
        _pipe = gleam_stdlib:map_get(
            erlang:element(8, State),
            erlang:element(3, Datom)
        ),
        gleam@result:unwrap(
            _pipe,
            {attribute_config, false, false, all, many, none}
        )
    end,
    Res = case erlang:element(2, Config) of
        true ->
            case gleamdb@index:get_entity_by_av(
                erlang:element(5, State),
                erlang:element(3, Datom),
                erlang:element(4, Datom)
            ) of
                {ok, Existing_id} when Existing_id =/= erlang:element(2, Datom) ->
                    {error,
                        <<"Unique constraint violation on "/utf8,
                            (erlang:element(3, Datom))/binary>>};

                _ ->
                    {ok, nil}
            end;

        false ->
            {ok, nil}
    end,
    case Res of
        {ok, _} ->
            case erlang:element(6, Config) of
                {some, Pred_name} ->
                    case gleam_stdlib:map_get(
                        erlang:element(21, State),
                        Pred_name
                    ) of
                        {ok, Pred} ->
                            case Pred(erlang:element(4, Datom)) of
                                true ->
                                    {ok, nil};

                                false ->
                                    {error,
                                        <<<<<<<<"CHECK constraint violation on "/utf8,
                                                        (erlang:element(
                                                            3,
                                                            Datom
                                                        ))/binary>>/binary,
                                                    " (predicate: "/utf8>>/binary,
                                                Pred_name/binary>>/binary,
                                            ")"/utf8>>}
                            end;

                        {error, _} ->
                            {ok, nil}
                    end;

                none ->
                    {ok, nil}
            end;

        {error, E} ->
            {error, E}
    end.

-file("src/gleamdb/transactor.gleam", 583).
-spec compute_next_state(
    gleamdb@shared@types:db_state(),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
    gleam@option:option(integer()),
    gleamdb@fact:operation()
) -> {ok, {gleamdb@shared@types:db_state(), list(gleamdb@fact:datom())}} |
    {error, binary()}.
compute_next_state(State, Facts, Valid_time, Op) ->
    Tx_id = erlang:element(6, State) + 1,
    Vt = gleam@option:unwrap(Valid_time, Tx_id),
    Resolved_facts = resolve_transaction_functions(State, Tx_id, Vt, Facts),
    Result = gleam@list:fold_until(
        Resolved_facts,
        {ok, {State, []}},
        fun(Acc_res, F) ->
            {Curr_state@1, Acc_datoms@1} = case Acc_res of
                {ok, {Curr_state, Acc_datoms}} -> {Curr_state, Acc_datoms};
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gleamdb/transactor"/utf8>>,
                                function => <<"compute_next_state"/utf8>>,
                                line => 597,
                                value => _assert_fail,
                                start => 20680,
                                'end' => 20730,
                                pattern_start => 20691,
                                pattern_end => 20720})
            end,
            case resolve_eid(Curr_state@1, erlang:element(1, F)) of
                {some, Id} ->
                    case Op of
                        assert ->
                            Config = begin
                                _pipe = gleam_stdlib:map_get(
                                    erlang:element(8, Curr_state@1),
                                    erlang:element(2, F)
                                ),
                                gleam@result:unwrap(
                                    _pipe,
                                    {attribute_config,
                                        false,
                                        false,
                                        all,
                                        many,
                                        none}
                                )
                            end,
                            {Sub_state, Sub_datoms} = case (erlang:element(
                                5,
                                Config
                            )
                            =:= one)
                            orelse (erlang:element(4, Config) =:= latest_only) of
                                true ->
                                    Existing = begin
                                        _pipe@1 = gleamdb@index:get_datoms_by_entity_attr(
                                            erlang:element(3, Curr_state@1),
                                            Id,
                                            erlang:element(2, F)
                                        ),
                                        filter_active(_pipe@1)
                                    end,
                                    gleam@list:fold(
                                        Existing,
                                        {Curr_state@1, []},
                                        fun(Acc, D) ->
                                            {St, Ds} = Acc,
                                            Retract_datom = {datom,
                                                erlang:element(2, D),
                                                erlang:element(3, D),
                                                erlang:element(4, D),
                                                Tx_id,
                                                Vt,
                                                retract},
                                            {apply_datom(St, Retract_datom),
                                                [Retract_datom | Ds]}
                                        end
                                    );

                                false ->
                                    {Curr_state@1, []}
                            end,
                            Datom = {datom,
                                Id,
                                erlang:element(2, F),
                                erlang:element(3, F),
                                Tx_id,
                                Vt,
                                assert},
                            case check_constraints(Sub_state, Datom) of
                                {ok, _} ->
                                    case check_composite_uniqueness(
                                        Sub_state,
                                        Datom
                                    ) of
                                        {ok, _} ->
                                            {continue,
                                                {ok,
                                                    {apply_datom(
                                                            Sub_state,
                                                            Datom
                                                        ),
                                                        [Datom |
                                                            lists:append(
                                                                Sub_datoms,
                                                                Acc_datoms@1
                                                            )]}}};

                                        {error, E} ->
                                            {stop, {error, E}}
                                    end;

                                {error, E@1} ->
                                    {stop, {error, E@1}}
                            end;

                        retract ->
                            Config@1 = begin
                                _pipe@2 = gleam_stdlib:map_get(
                                    erlang:element(8, Curr_state@1),
                                    erlang:element(2, F)
                                ),
                                gleam@result:unwrap(
                                    _pipe@2,
                                    {attribute_config,
                                        false,
                                        false,
                                        all,
                                        many,
                                        none}
                                )
                            end,
                            {Sub_state@1, Sub_datoms@1} = case erlang:element(
                                3,
                                Config@1
                            ) of
                                true ->
                                    case erlang:element(3, F) of
                                        {ref, {entity_id, Sub_id}} ->
                                            retract_recursive_collected(
                                                Curr_state@1,
                                                {entity_id, Sub_id},
                                                Tx_id,
                                                Vt,
                                                []
                                            );

                                        {int, Sub_id@1} ->
                                            retract_recursive_collected(
                                                Curr_state@1,
                                                {entity_id, Sub_id@1},
                                                Tx_id,
                                                Vt,
                                                []
                                            );

                                        _ ->
                                            {Curr_state@1, []}
                                    end;

                                false ->
                                    {Curr_state@1, []}
                            end,
                            Datom@1 = {datom,
                                Id,
                                erlang:element(2, F),
                                erlang:element(3, F),
                                Tx_id,
                                Vt,
                                retract},
                            {continue,
                                {ok,
                                    {apply_datom(Sub_state@1, Datom@1),
                                        [Datom@1 |
                                            lists:append(
                                                Sub_datoms@1,
                                                Acc_datoms@1
                                            )]}}}
                    end;

                none ->
                    {continue, {ok, {Curr_state@1, Acc_datoms@1}}}
            end
        end
    ),
    case Result of
        {ok, {Final_state, All_datoms}} ->
            Reversed = lists:reverse(All_datoms),
            {ok,
                {{db_state,
                        erlang:element(2, Final_state),
                        erlang:element(3, Final_state),
                        erlang:element(4, Final_state),
                        erlang:element(5, Final_state),
                        Tx_id,
                        erlang:element(7, Final_state),
                        erlang:element(8, Final_state),
                        erlang:element(9, Final_state),
                        erlang:element(10, Final_state),
                        erlang:element(11, Final_state),
                        erlang:element(12, Final_state),
                        erlang:element(13, Final_state),
                        erlang:element(14, Final_state),
                        erlang:element(15, Final_state),
                        erlang:element(16, Final_state),
                        erlang:element(17, Final_state),
                        erlang:element(18, Final_state),
                        erlang:element(19, Final_state),
                        erlang:element(20, Final_state),
                        erlang:element(21, Final_state),
                        erlang:element(22, Final_state),
                        erlang:element(23, Final_state),
                        erlang:element(24, Final_state)},
                    Reversed}};

        {error, E@2} ->
            {error, E@2}
    end.

-file("src/gleamdb/transactor.gleam", 663).
-spec do_transact(
    gleamdb@shared@types:db_state(),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
    gleam@option:option(integer()),
    gleamdb@fact:operation()
) -> {ok, {gleamdb@shared@types:db_state(), list(gleamdb@fact:datom())}} |
    {error, binary()}.
do_transact(State, Facts, Valid_time, Op) ->
    case compute_next_state(State, Facts, Valid_time, Op) of
        {ok, {Final_state, Reversed}} ->
            (erlang:element(4, erlang:element(2, Final_state)))(Reversed),
            {ok, {Final_state, Reversed}};

        {error, E} ->
            {error, E}
    end.

-file("src/gleamdb/transactor.gleam", 512).
-spec do_handle_transact(
    gleamdb@shared@types:db_state(),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
    gleam@option:option(integer()),
    gleamdb@fact:operation(),
    gleam@erlang@process:subject({ok, gleamdb@shared@types:db_state()} |
        {error, binary()})
) -> gleam@otp@actor:next(gleamdb@shared@types:db_state(), message()).
do_handle_transact(State, Facts, Valid_time, Op, Reply_to) ->
    case do_transact(State, Facts, Valid_time, Op) of
        {ok, {New_state, Datoms}} ->
            gleam@erlang@process:send(Reply_to, {ok, New_state}),
            Changed_attrs = begin
                _pipe = gleam@list:map(
                    Facts,
                    fun(F) -> erlang:element(2, F) end
                ),
                gleam@list:unique(_pipe)
            end,
            gleam@erlang@process:send(
                erlang:element(11, State),
                {notify, Changed_attrs, New_state}
            ),
            gleam@list:each(
                erlang:element(12, State),
                fun(F_pid) ->
                    F_subject = gleamdb_process_ffi:pid_to_subject(F_pid),
                    gleam@erlang@process:send(F_subject, {sync_datoms, Datoms})
                end
            ),
            gleam@otp@actor:continue(New_state);

        {error, Err} ->
            gleam@erlang@process:send(Reply_to, {error, Err}),
            gleam@otp@actor:continue(State)
    end.

-file("src/gleamdb/transactor.gleam", 154).
-spec handle_message(gleamdb@shared@types:db_state(), message()) -> gleam@otp@actor:next(gleamdb@shared@types:db_state(), message()).
handle_message(State, Msg) ->
    case Msg of
        {boot, Ets_name, Store, Reply} ->
            case Ets_name of
                {some, Name} ->
                    gleamdb@index@ets:init_tables(Name);

                none ->
                    nil
            end,
            (erlang:element(2, Store))(),
            New_state = recover_state(State),
            gleam@erlang@process:send(Reply, nil),
            gleam@otp@actor:continue(New_state);

        {transact, Facts, Vt, Reply_to} ->
            case is_leader(State) of
                true ->
                    do_handle_transact(State, Facts, Vt, assert, Reply_to);

                false ->
                    case gleamdb_global_ffi:whereis(<<"gleamdb_leader"/utf8>>) of
                        {ok, Leader_pid} ->
                            Leader_subject = gleamdb_process_ffi:pid_to_subject(
                                Leader_pid
                            ),
                            gleam@erlang@process:send(
                                Leader_subject,
                                {transact, Facts, Vt, Reply_to}
                            ),
                            gleam@otp@actor:continue(State);

                        {error, _} ->
                            do_handle_transact(
                                State,
                                Facts,
                                Vt,
                                assert,
                                Reply_to
                            )
                    end
            end;

        {retract, Facts@1, Vt@1, Reply_to@1} ->
            case is_leader(State) of
                true ->
                    do_handle_transact(
                        State,
                        Facts@1,
                        Vt@1,
                        retract,
                        Reply_to@1
                    );

                false ->
                    case gleamdb_global_ffi:whereis(<<"gleamdb_leader"/utf8>>) of
                        {ok, Leader_pid@1} ->
                            Leader_subject@1 = gleamdb_process_ffi:pid_to_subject(
                                Leader_pid@1
                            ),
                            gleam@erlang@process:send(
                                Leader_subject@1,
                                {retract, Facts@1, Vt@1, Reply_to@1}
                            ),
                            gleam@otp@actor:continue(State);

                        {error, _} ->
                            do_handle_transact(
                                State,
                                Facts@1,
                                Vt@1,
                                retract,
                                Reply_to@1
                            )
                    end
            end;

        {get_state, Reply_to@2} ->
            gleam@erlang@process:send(Reply_to@2, State),
            gleam@otp@actor:continue(State);

        {set_schema, Attr, Config, Reply_to@3} ->
            Existing = begin
                _pipe = gleamdb@index:get_all_datoms_for_attr(
                    erlang:element(3, State),
                    Attr
                ),
                filter_active(_pipe)
            end,
            Values = gleam@list:map(
                Existing,
                fun(D) -> erlang:element(4, D) end
            ),
            Has_dupes = begin
                _pipe@1 = gleam@list:unique(Values),
                erlang:length(_pipe@1)
            end
            /= erlang:length(Values),
            Entities_with_multiple = begin
                _pipe@3 = gleam@list:fold(
                    Existing,
                    maps:new(),
                    fun(Acc, D@1) ->
                        Count = begin
                            _pipe@2 = gleam_stdlib:map_get(
                                Acc,
                                erlang:element(2, D@1)
                            ),
                            gleam@result:unwrap(_pipe@2, 0)
                        end,
                        gleam@dict:insert(
                            Acc,
                            erlang:element(2, D@1),
                            Count + 1
                        )
                    end
                ),
                _pipe@4 = maps:to_list(_pipe@3),
                gleam@list:filter(
                    _pipe@4,
                    fun(Pair) -> erlang:element(2, Pair) > 1 end
                )
            end,
            Cardinality_violation = (erlang:element(5, Config) =:= one) andalso not gleam@list:is_empty(
                Entities_with_multiple
            ),
            case {erlang:element(2, Config) andalso Has_dupes,
                Cardinality_violation} of
                {true, _} ->
                    gleam@erlang@process:send(
                        Reply_to@3,
                        {error,
                            <<"Cannot make non-unique attribute unique: existing data has duplicates"/utf8>>}
                    ),
                    gleam@otp@actor:continue(State);

                {_, true} ->
                    gleam@erlang@process:send(
                        Reply_to@3,
                        {error,
                            <<"Cannot set cardinality to ONE: existing entities have multiple values"/utf8>>}
                    ),
                    gleam@otp@actor:continue(State);

                {false, false} ->
                    New_schema = gleam@dict:insert(
                        erlang:element(8, State),
                        Attr,
                        Config
                    ),
                    New_state@1 = {db_state,
                        erlang:element(2, State),
                        erlang:element(3, State),
                        erlang:element(4, State),
                        erlang:element(5, State),
                        erlang:element(6, State),
                        erlang:element(7, State),
                        New_schema,
                        erlang:element(9, State),
                        erlang:element(10, State),
                        erlang:element(11, State),
                        erlang:element(12, State),
                        erlang:element(13, State),
                        erlang:element(14, State),
                        erlang:element(15, State),
                        erlang:element(16, State),
                        erlang:element(17, State),
                        erlang:element(18, State),
                        erlang:element(19, State),
                        erlang:element(20, State),
                        erlang:element(21, State),
                        erlang:element(22, State),
                        erlang:element(23, State),
                        erlang:element(24, State)},
                    gleam@erlang@process:send(Reply_to@3, {ok, nil}),
                    gleam@otp@actor:continue(New_state@1)
            end;

        {register_function, Name@1, Func, Reply_to@4} ->
            New_functions = gleam@dict:insert(
                erlang:element(9, State),
                Name@1,
                Func
            ),
            New_state@2 = {db_state,
                erlang:element(2, State),
                erlang:element(3, State),
                erlang:element(4, State),
                erlang:element(5, State),
                erlang:element(6, State),
                erlang:element(7, State),
                erlang:element(8, State),
                New_functions,
                erlang:element(10, State),
                erlang:element(11, State),
                erlang:element(12, State),
                erlang:element(13, State),
                erlang:element(14, State),
                erlang:element(15, State),
                erlang:element(16, State),
                erlang:element(17, State),
                erlang:element(18, State),
                erlang:element(19, State),
                erlang:element(20, State),
                erlang:element(21, State),
                erlang:element(22, State),
                erlang:element(23, State),
                erlang:element(24, State)},
            gleam@erlang@process:send(Reply_to@4, nil),
            gleam@otp@actor:continue(New_state@2);

        {register_predicate, Name@2, Pred, Reply_to@5} ->
            New_predicates = gleam@dict:insert(
                erlang:element(21, State),
                Name@2,
                Pred
            ),
            New_state@3 = {db_state,
                erlang:element(2, State),
                erlang:element(3, State),
                erlang:element(4, State),
                erlang:element(5, State),
                erlang:element(6, State),
                erlang:element(7, State),
                erlang:element(8, State),
                erlang:element(9, State),
                erlang:element(10, State),
                erlang:element(11, State),
                erlang:element(12, State),
                erlang:element(13, State),
                erlang:element(14, State),
                erlang:element(15, State),
                erlang:element(16, State),
                erlang:element(17, State),
                erlang:element(18, State),
                erlang:element(19, State),
                erlang:element(20, State),
                New_predicates,
                erlang:element(22, State),
                erlang:element(23, State),
                erlang:element(24, State)},
            gleam@erlang@process:send(Reply_to@5, nil),
            gleam@otp@actor:continue(New_state@3);

        {register_composite, Attrs, Reply_to@6} ->
            Clauses = gleam@list:map(
                Attrs,
                fun(Attr@1) ->
                    {positive, {{var, <<"e"/utf8>>}, Attr@1, {var, Attr@1}}}
                end
            ),
            Results = gleamdb@engine:run(State, Clauses, [], none, none),
            Seen = gleam@list:fold_until(
                erlang:element(2, Results),
                {ok, maps:new()},
                fun(Acc_res, Binding) ->
                    Acc@2 = case Acc_res of
                        {ok, Acc@1} -> Acc@1;
                        _assert_fail ->
                            erlang:error(#{gleam_error => let_assert,
                                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                        file => <<?FILEPATH/utf8>>,
                                        module => <<"gleamdb/transactor"/utf8>>,
                                        function => <<"handle_message"/utf8>>,
                                        line => 255,
                                        value => _assert_fail,
                                        start => 8746,
                                        'end' => 8774,
                                        pattern_start => 8757,
                                        pattern_end => 8764})
                    end,
                    E = begin
                        _pipe@5 = gleam_stdlib:map_get(Binding, <<"e"/utf8>>),
                        gleam@result:unwrap(_pipe@5, {int, 0})
                    end,
                    Vals = gleam@list:map(
                        Attrs,
                        fun(A) -> _pipe@6 = gleam_stdlib:map_get(Binding, A),
                            gleam@result:unwrap(_pipe@6, {int, 0}) end
                    ),
                    case gleam_stdlib:map_get(Acc@2, Vals) of
                        {ok, Existing_e} when Existing_e =/= E ->
                            {stop,
                                {error,
                                    <<"Existing data violates new composite: "/utf8,
                                        (gleam@string:inspect(Attrs))/binary>>}};

                        _ ->
                            {continue, {ok, gleam@dict:insert(Acc@2, Vals, E)}}
                    end
                end
            ),
            case Seen of
                {ok, _} ->
                    Serialized_attrs = gleam@string:join(Attrs, <<","/utf8>>),
                    Meta_eid = gleamdb@fact:deterministic_uid(
                        <<"_meta/composite/"/utf8, Serialized_attrs/binary>>
                    ),
                    Meta_fact = {Meta_eid,
                        <<"_meta/composite"/utf8>>,
                        {str, Serialized_attrs}},
                    case do_transact(State, [Meta_fact], none, assert) of
                        {ok, {New_state@4, _}} ->
                            gleam@erlang@process:send(Reply_to@6, {ok, nil}),
                            gleam@otp@actor:continue(New_state@4);

                        {error, E@1} ->
                            gleam@erlang@process:send(Reply_to@6, {error, E@1}),
                            gleam@otp@actor:continue(State)
                    end;

                {error, E@2} ->
                    gleam@erlang@process:send(Reply_to@6, {error, E@2}),
                    gleam@otp@actor:continue(State)
            end;

        {store_rule, Rule, Reply_to@7} ->
            Encoded = gleamdb@rule_serde:serialize(Rule),
            Eid = gleamdb@fact:deterministic_uid(Encoded),
            Rule_fact = {Eid, <<"_rule/content"/utf8>>, {str, Encoded}},
            case do_transact(State, [Rule_fact], none, assert) of
                {ok, {New_state@5, _}} ->
                    New_stored = [Rule | erlang:element(22, State)],
                    gleam@erlang@process:send(Reply_to@7, {ok, nil}),
                    gleam@otp@actor:continue(
                        {db_state,
                            erlang:element(2, New_state@5),
                            erlang:element(3, New_state@5),
                            erlang:element(4, New_state@5),
                            erlang:element(5, New_state@5),
                            erlang:element(6, New_state@5),
                            erlang:element(7, New_state@5),
                            erlang:element(8, New_state@5),
                            erlang:element(9, New_state@5),
                            erlang:element(10, New_state@5),
                            erlang:element(11, New_state@5),
                            erlang:element(12, New_state@5),
                            erlang:element(13, New_state@5),
                            erlang:element(14, New_state@5),
                            erlang:element(15, New_state@5),
                            erlang:element(16, New_state@5),
                            erlang:element(17, New_state@5),
                            erlang:element(18, New_state@5),
                            erlang:element(19, New_state@5),
                            erlang:element(20, New_state@5),
                            erlang:element(21, New_state@5),
                            New_stored,
                            erlang:element(23, New_state@5),
                            erlang:element(24, New_state@5)}
                    );

                {error, E@3} ->
                    gleam@erlang@process:send(Reply_to@7, {error, E@3}),
                    gleam@otp@actor:continue(State)
            end;

        {set_reactive, Subject} ->
            gleam@otp@actor:continue(
                {db_state,
                    erlang:element(2, State),
                    erlang:element(3, State),
                    erlang:element(4, State),
                    erlang:element(5, State),
                    erlang:element(6, State),
                    erlang:element(7, State),
                    erlang:element(8, State),
                    erlang:element(9, State),
                    erlang:element(10, State),
                    Subject,
                    erlang:element(12, State),
                    erlang:element(13, State),
                    erlang:element(14, State),
                    erlang:element(15, State),
                    erlang:element(16, State),
                    erlang:element(17, State),
                    erlang:element(18, State),
                    erlang:element(19, State),
                    erlang:element(20, State),
                    erlang:element(21, State),
                    erlang:element(22, State),
                    erlang:element(23, State),
                    erlang:element(24, State)}
            );

        {join, Pid} ->
            New_followers = [Pid | erlang:element(12, State)],
            gleam@otp@actor:continue(
                {db_state,
                    erlang:element(2, State),
                    erlang:element(3, State),
                    erlang:element(4, State),
                    erlang:element(5, State),
                    erlang:element(6, State),
                    erlang:element(7, State),
                    erlang:element(8, State),
                    erlang:element(9, State),
                    erlang:element(10, State),
                    erlang:element(11, State),
                    New_followers,
                    erlang:element(13, State),
                    erlang:element(14, State),
                    erlang:element(15, State),
                    erlang:element(16, State),
                    erlang:element(17, State),
                    erlang:element(18, State),
                    erlang:element(19, State),
                    erlang:element(20, State),
                    erlang:element(21, State),
                    erlang:element(22, State),
                    erlang:element(23, State),
                    erlang:element(24, State)}
            );

        {sync_datoms, Datoms} ->
            New_state@6 = gleam@list:fold(
                Datoms,
                State,
                fun(Acc@3, D@2) -> apply_datom(Acc@3, D@2) end
            ),
            Changed_attrs = begin
                _pipe@7 = gleam@list:map(
                    Datoms,
                    fun(D@3) -> erlang:element(3, D@3) end
                ),
                gleam@list:unique(_pipe@7)
            end,
            gleam@erlang@process:send(
                erlang:element(11, State),
                {notify, Changed_attrs, New_state@6}
            ),
            Max_tx = gleam@list:fold(
                Datoms,
                erlang:element(6, State),
                fun(Acc@4, D@4) -> case erlang:element(5, D@4) > Acc@4 of
                        true ->
                            erlang:element(5, D@4);

                        false ->
                            Acc@4
                    end end
            ),
            gleam@otp@actor:continue(
                {db_state,
                    erlang:element(2, New_state@6),
                    erlang:element(3, New_state@6),
                    erlang:element(4, New_state@6),
                    erlang:element(5, New_state@6),
                    Max_tx,
                    erlang:element(7, New_state@6),
                    erlang:element(8, New_state@6),
                    erlang:element(9, New_state@6),
                    erlang:element(10, New_state@6),
                    erlang:element(11, New_state@6),
                    erlang:element(12, New_state@6),
                    erlang:element(13, New_state@6),
                    erlang:element(14, New_state@6),
                    erlang:element(15, New_state@6),
                    erlang:element(16, New_state@6),
                    erlang:element(17, New_state@6),
                    erlang:element(18, New_state@6),
                    erlang:element(19, New_state@6),
                    erlang:element(20, New_state@6),
                    erlang:element(21, New_state@6),
                    erlang:element(22, New_state@6),
                    erlang:element(23, New_state@6),
                    erlang:element(24, New_state@6)}
            );

        {raft_msg, Raft_msg} ->
            Self_pid = gleamdb_process_ffi:self(),
            {New_raft, Effects} = gleamdb@raft:handle_message(
                erlang:element(15, State),
                Raft_msg,
                Self_pid
            ),
            New_state@7 = {db_state,
                erlang:element(2, State),
                erlang:element(3, State),
                erlang:element(4, State),
                erlang:element(5, State),
                erlang:element(6, State),
                erlang:element(7, State),
                erlang:element(8, State),
                erlang:element(9, State),
                erlang:element(10, State),
                erlang:element(11, State),
                erlang:element(12, State),
                erlang:element(13, State),
                erlang:element(14, State),
                New_raft,
                erlang:element(16, State),
                erlang:element(17, State),
                erlang:element(18, State),
                erlang:element(19, State),
                erlang:element(20, State),
                erlang:element(21, State),
                erlang:element(22, State),
                erlang:element(23, State),
                erlang:element(24, State)},
            execute_raft_effects(New_state@7, Effects, Self_pid),
            gleam@otp@actor:continue(New_state@7);

        {compact, Reply_to@8} ->
            _ = gleamdb@index:filter_by_entity(
                erlang:element(3, State),
                {entity_id, 0}
            ),
            gleam@erlang@process:send(Reply_to@8, nil),
            gleam@otp@actor:continue(State);

        {set_config, Config@1, Reply_to@9} ->
            print_config_update(Config@1),
            gleam@erlang@process:send(Reply_to@9, nil),
            gleam@otp@actor:continue(
                {db_state,
                    erlang:element(2, State),
                    erlang:element(3, State),
                    erlang:element(4, State),
                    erlang:element(5, State),
                    erlang:element(6, State),
                    erlang:element(7, State),
                    erlang:element(8, State),
                    erlang:element(9, State),
                    erlang:element(10, State),
                    erlang:element(11, State),
                    erlang:element(12, State),
                    erlang:element(13, State),
                    erlang:element(14, State),
                    erlang:element(15, State),
                    erlang:element(16, State),
                    erlang:element(17, State),
                    erlang:element(18, State),
                    erlang:element(19, State),
                    erlang:element(20, State),
                    erlang:element(21, State),
                    erlang:element(22, State),
                    erlang:element(23, State),
                    Config@1}
            );

        {register_index_adapter, Adapter, Reply_to@10} ->
            New_registry = gleam@dict:insert(
                erlang:element(19, State),
                erlang:element(2, Adapter),
                Adapter
            ),
            gleam@erlang@process:send(Reply_to@10, nil),
            gleam@otp@actor:continue(
                {db_state,
                    erlang:element(2, State),
                    erlang:element(3, State),
                    erlang:element(4, State),
                    erlang:element(5, State),
                    erlang:element(6, State),
                    erlang:element(7, State),
                    erlang:element(8, State),
                    erlang:element(9, State),
                    erlang:element(10, State),
                    erlang:element(11, State),
                    erlang:element(12, State),
                    erlang:element(13, State),
                    erlang:element(14, State),
                    erlang:element(15, State),
                    erlang:element(16, State),
                    erlang:element(17, State),
                    erlang:element(18, State),
                    New_registry,
                    erlang:element(20, State),
                    erlang:element(21, State),
                    erlang:element(22, State),
                    erlang:element(23, State),
                    erlang:element(24, State)}
            );

        {create_index, Name@3, Adapter_name, Attribute, Reply_to@11} ->
            case gleam@dict:has_key(erlang:element(19, State), Adapter_name) of
                true ->
                    case gleam_stdlib:map_get(
                        erlang:element(19, State),
                        Adapter_name
                    ) of
                        {ok, Adapter@1} ->
                            Initial_data = (erlang:element(3, Adapter@1))(
                                Attribute
                            ),
                            Instance = {extension_instance,
                                Adapter_name,
                                Attribute,
                                Initial_data},
                            New_extensions = gleam@dict:insert(
                                erlang:element(20, State),
                                Name@3,
                                Instance
                            ),
                            gleam@erlang@process:send(Reply_to@11, {ok, nil}),
                            gleam@otp@actor:continue(
                                {db_state,
                                    erlang:element(2, State),
                                    erlang:element(3, State),
                                    erlang:element(4, State),
                                    erlang:element(5, State),
                                    erlang:element(6, State),
                                    erlang:element(7, State),
                                    erlang:element(8, State),
                                    erlang:element(9, State),
                                    erlang:element(10, State),
                                    erlang:element(11, State),
                                    erlang:element(12, State),
                                    erlang:element(13, State),
                                    erlang:element(14, State),
                                    erlang:element(15, State),
                                    erlang:element(16, State),
                                    erlang:element(17, State),
                                    erlang:element(18, State),
                                    erlang:element(19, State),
                                    New_extensions,
                                    erlang:element(21, State),
                                    erlang:element(22, State),
                                    erlang:element(23, State),
                                    erlang:element(24, State)}
                            );

                        {error, _} ->
                            gleam@erlang@process:send(
                                Reply_to@11,
                                {error, <<"Adapter not registered"/utf8>>}
                            ),
                            gleam@otp@actor:continue(State)
                    end;

                false ->
                    gleam@erlang@process:send(
                        Reply_to@11,
                        {error,
                            <<"Unknown index adapter: "/utf8,
                                Adapter_name/binary>>}
                    ),
                    gleam@otp@actor:continue(State)
            end;

        {create_b_m25_index, Attribute@1, Reply_to@12} ->
            New_indices = gleam@dict:insert(
                erlang:element(17, State),
                Attribute@1,
                gleamdb@index@bm25:empty(Attribute@1)
            ),
            gleam@erlang@process:send(Reply_to@12, {ok, nil}),
            gleam@otp@actor:continue(
                {db_state,
                    erlang:element(2, State),
                    erlang:element(3, State),
                    erlang:element(4, State),
                    erlang:element(5, State),
                    erlang:element(6, State),
                    erlang:element(7, State),
                    erlang:element(8, State),
                    erlang:element(9, State),
                    erlang:element(10, State),
                    erlang:element(11, State),
                    erlang:element(12, State),
                    erlang:element(13, State),
                    erlang:element(14, State),
                    erlang:element(15, State),
                    erlang:element(16, State),
                    New_indices,
                    erlang:element(18, State),
                    erlang:element(19, State),
                    erlang:element(20, State),
                    erlang:element(21, State),
                    erlang:element(22, State),
                    erlang:element(23, State),
                    erlang:element(24, State)}
            );

        {sync, Reply_to@13} ->
            gleam@erlang@process:send(Reply_to@13, nil),
            gleam@otp@actor:continue(State)
    end.

-file("src/gleamdb/transactor.gleam", 102).
-spec do_start_named(
    gleamdb@storage:storage_adapter(),
    boolean(),
    gleam@option:option(binary())
) -> {ok, gleam@erlang@process:subject(message())} |
    {error, gleam@otp@actor:start_error()}.
do_start_named(Store, Is_distributed, Ets_name) ->
    Reactive_subject@1 = case gleamdb@reactive:start_link() of
        {ok, Reactive_subject} -> Reactive_subject;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gleamdb/transactor"/utf8>>,
                        function => <<"do_start_named"/utf8>>,
                        line => 107,
                        value => _assert_fail,
                        start => 3496,
                        'end' => 3551,
                        pattern_start => 3507,
                        pattern_end => 3527})
    end,
    Base_state = {db_state,
        Store,
        gleamdb@index:new_index(),
        gleamdb@index:new_aindex(),
        gleamdb@index:new_avindex(),
        0,
        [],
        maps:new(),
        maps:new(),
        [],
        Reactive_subject@1,
        [],
        Is_distributed,
        Ets_name,
        gleamdb@raft:new([]),
        gleamdb@vec_index:new(),
        maps:new(),
        gleamdb@index@art:new(),
        maps:new(),
        maps:new(),
        maps:new(),
        [],
        maps:new(),
        {config, 1000, 1000}},
    Res = begin
        _pipe = gleam@otp@actor:new(Base_state),
        _pipe@1 = gleam@otp@actor:on_message(_pipe, fun handle_message/2),
        gleam@otp@actor:start(_pipe@1)
    end,
    case Res of
        {ok, Started} ->
            Subj = erlang:element(3, Started),
            Reply = gleam@erlang@process:new_subject(),
            gleam@erlang@process:send(Subj, {boot, Ets_name, Store, Reply}),
            _ = gleam@erlang@process:'receive'(Reply, 600000),
            {ok, Subj};

        {error, E} ->
            {error, E}
    end.

-file("src/gleamdb/transactor.gleam", 56).
-spec start_named(binary(), gleamdb@storage:storage_adapter()) -> {ok,
        gleam@erlang@process:subject(message())} |
    {error, gleam@otp@actor:start_error()}.
start_named(Name, Store) ->
    do_start_named(Store, false, {some, Name}).

-file("src/gleamdb/transactor.gleam", 65).
-spec start_distributed(binary(), gleamdb@storage:storage_adapter()) -> {ok,
        gleam@erlang@process:subject(message())} |
    {error, gleam@otp@actor:start_error()}.
start_distributed(Name, Store) ->
    Res = do_start_named(Store, true, {some, Name}),
    case Res of
        {ok, Subject} ->
            Pid = gleamdb_process_ffi:subject_to_pid(Subject),
            _ = gleamdb_global_ffi:register(
                <<"gleamdb_"/utf8, Name/binary>>,
                Pid
            ),
            {ok, Subject};

        {error, Err} ->
            {error, Err}
    end.

-file("src/gleamdb/transactor.gleam", 95).
-spec start_with_timeout(gleamdb@storage:storage_adapter(), integer()) -> {ok,
        gleam@erlang@process:subject(message())} |
    {error, gleam@otp@actor:start_error()}.
start_with_timeout(Store, _) ->
    do_start_named(Store, false, none).

-file("src/gleamdb/transactor.gleam", 50).
-spec start(gleamdb@storage:storage_adapter()) -> {ok,
        gleam@erlang@process:subject(message())} |
    {error, gleam@otp@actor:start_error()}.
start(Store) ->
    start_with_timeout(Store, 1000).

-file("src/gleamdb/transactor.gleam", 1034).
-spec register_index_adapter(
    gleam@erlang@process:subject(message()),
    gleamdb@shared@types:index_adapter()
) -> nil.
register_index_adapter(Db, Adapter) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {register_index_adapter, Adapter, Reply}),
    _ = gleam@erlang@process:'receive'(Reply, 5000),
    nil.

-file("src/gleamdb/transactor.gleam", 1044).
-spec create_index(
    gleam@erlang@process:subject(message()),
    binary(),
    binary(),
    binary()
) -> {ok, nil} | {error, binary()}.
create_index(Db, Attribute, Adapter_name, Name) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(
        Db,
        {create_index, Name, Adapter_name, Attribute, Reply}
    ),
    case gleam@erlang@process:'receive'(Reply, 5000) of
        {ok, Res} ->
            Res;

        {error, _} ->
            {error, <<"Timeout"/utf8>>}
    end.
