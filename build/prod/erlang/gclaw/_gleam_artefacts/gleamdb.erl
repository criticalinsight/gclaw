-module(gleamdb).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb.gleam").
-export([start_link/2, new_with_adapter_and_timeout/2, new_with_adapter/1, new/0, start_named/2, start_distributed/2, connect/1, transact/2, transact_at/3, transact_with_timeout/3, retract/2, retract_at/3, with_facts/2, explain_speculation/1, get/3, get_one/3, set_schema/3, set_schema_with_timeout/4, history/2, pull/3, diff/3, pull_all/0, pull_attr/1, pull_except/1, pull_recursive/2, query_at/4, 'query'/2, query_state_at/4, query_state/2, query_state_with_rules/3, query_with_rules/3, explain/1, as_of/3, as_of_valid/3, as_of_bitemporal/4, p/1, register_function/3, register_composite/2, register_predicate/3, store_rule/2, set_config/2, subscribe/3, get_state/1, sync/1, is_leader/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/gleamdb.gleam", 34).
-spec start_link(
    gleam@option:option(gleamdb@storage:storage_adapter()),
    integer()
) -> {ok, gleam@erlang@process:subject(gleamdb@transactor:message())} |
    {error, gleam@otp@actor:start_error()}.
start_link(Adapter, Timeout_ms) ->
    Store = case Adapter of
        {some, S} ->
            S;

        none ->
            gleamdb@storage:ephemeral()
    end,
    gleamdb@transactor:start_with_timeout(Store, Timeout_ms).

-file("src/gleamdb.gleam", 29).
-spec new_with_adapter_and_timeout(
    gleam@option:option(gleamdb@storage:storage_adapter()),
    integer()
) -> gleam@erlang@process:subject(gleamdb@transactor:message()).
new_with_adapter_and_timeout(Adapter, Timeout_ms) ->
    Db@1 = case start_link(Adapter, Timeout_ms) of
        {ok, Db} -> Db;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gleamdb"/utf8>>,
                        function => <<"new_with_adapter_and_timeout"/utf8>>,
                        line => 30,
                        value => _assert_fail,
                        start => 876,
                        'end' => 927,
                        pattern_start => 887,
                        pattern_end => 893})
    end,
    Db@1.

-file("src/gleamdb.gleam", 25).
-spec new_with_adapter(gleam@option:option(gleamdb@storage:storage_adapter())) -> gleam@erlang@process:subject(gleamdb@transactor:message()).
new_with_adapter(Adapter) ->
    new_with_adapter_and_timeout(Adapter, 5000).

-file("src/gleamdb.gleam", 21).
-spec new() -> gleam@erlang@process:subject(gleamdb@transactor:message()).
new() ->
    new_with_adapter(none).

-file("src/gleamdb.gleam", 46).
-spec start_named(
    binary(),
    gleam@option:option(gleamdb@storage:storage_adapter())
) -> {ok, gleam@erlang@process:subject(gleamdb@transactor:message())} |
    {error, gleam@otp@actor:start_error()}.
start_named(Name, Adapter) ->
    Store = case Adapter of
        {some, S} ->
            S;

        none ->
            gleamdb@storage:ephemeral()
    end,
    gleamdb@transactor:start_named(Name, Store).

-file("src/gleamdb.gleam", 57).
-spec start_distributed(
    binary(),
    gleam@option:option(gleamdb@storage:storage_adapter())
) -> {ok, gleam@erlang@process:subject(gleamdb@transactor:message())} |
    {error, gleam@otp@actor:start_error()}.
start_distributed(Name, Adapter) ->
    Store = case Adapter of
        {some, S} ->
            S;

        none ->
            gleamdb@storage:ephemeral()
    end,
    gleamdb@transactor:start_distributed(Name, Store).

-file("src/gleamdb.gleam", 68).
-spec connect(binary()) -> {ok,
        gleam@erlang@process:subject(gleamdb@transactor:message())} |
    {error, binary()}.
connect(Name) ->
    case gleamdb_global_ffi:whereis(<<"gleamdb_"/utf8, Name/binary>>) of
        {ok, Pid} ->
            {ok, gleamdb_process_ffi:pid_to_subject(Pid)};

        {error, _} ->
            {error, <<"Could not find database named "/utf8, Name/binary>>}
    end.

-file("src/gleamdb.gleam", 75).
-spec transact(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()})
) -> {ok, gleamdb@shared@types:db_state()} | {error, binary()}.
transact(Db, Facts) ->
    gleamdb@transactor:transact(Db, Facts).

-file("src/gleamdb.gleam", 79).
-spec transact_at(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
    integer()
) -> {ok, gleamdb@shared@types:db_state()} | {error, binary()}.
transact_at(Db, Facts, Valid_time) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {transact, Facts, {some, Valid_time}, Reply}),
    case gleam@erlang@process:'receive'(Reply, 5000) of
        {ok, Res} ->
            Res;

        {error, _} ->
            {error, <<"Timeout"/utf8>>}
    end.

-file("src/gleamdb.gleam", 88).
-spec transact_with_timeout(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
    integer()
) -> {ok, gleamdb@shared@types:db_state()} | {error, binary()}.
transact_with_timeout(Db, Facts, Timeout_ms) ->
    gleamdb@transactor:transact_with_timeout(Db, Facts, Timeout_ms).

-file("src/gleamdb.gleam", 92).
-spec retract(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()})
) -> {ok, gleamdb@shared@types:db_state()} | {error, binary()}.
retract(Db, Facts) ->
    gleamdb@transactor:retract(Db, Facts).

-file("src/gleamdb.gleam", 96).
-spec retract_at(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
    integer()
) -> {ok, gleamdb@shared@types:db_state()} | {error, binary()}.
retract_at(Db, Facts, Valid_time) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {retract, Facts, {some, Valid_time}, Reply}),
    case gleam@erlang@process:'receive'(Reply, 5000) of
        {ok, Res} ->
            Res;

        {error, _} ->
            {error, <<"Timeout"/utf8>>}
    end.

-file("src/gleamdb.gleam", 105).
-spec with_facts(
    gleamdb@shared@types:db_state(),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()})
) -> {ok, gleamdb@shared@types:speculative_result()} | {error, binary()}.
with_facts(State, Facts) ->
    _pipe = gleamdb@transactor:compute_next_state(State, Facts, none, assert),
    gleam@result:map(
        _pipe,
        fun(Res) ->
            {speculative_result, erlang:element(1, Res), erlang:element(2, Res)}
        end
    ).

-file("src/gleamdb.gleam", 111).
?DOC(" Provides a human-readable explanation of a speculative result or failure.\n").
-spec explain_speculation(
    {ok, gleamdb@shared@types:speculative_result()} | {error, binary()}
) -> binary().
explain_speculation(Res) ->
    case Res of
        {ok, S} ->
            <<<<"Speculation successful: "/utf8,
                    (erlang:integer_to_binary(
                        erlang:length(erlang:element(3, S))
                    ))/binary>>/binary,
                " datoms predicted."/utf8>>;

        {error, E} ->
            <<"Speculation failed: "/utf8, E/binary>>
    end.

-file("src/gleamdb.gleam", 118).
-spec get(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    gleamdb@fact:eid(),
    binary()
) -> list(gleamdb@fact:value()).
get(Db, Eid, Attr) ->
    State = gleamdb@transactor:get_state(Db),
    Id = case Eid of
        {uid, I} ->
            I;

        {lookup, {A, V}} ->
            _pipe = gleamdb@index:get_entity_by_av(
                erlang:element(5, State),
                A,
                V
            ),
            gleam@result:unwrap(_pipe, {entity_id, 0})
    end,
    _pipe@1 = gleamdb@index:get_datoms_by_entity_attr(
        erlang:element(3, State),
        Id,
        Attr
    ),
    gleam@list:map(_pipe@1, fun(D) -> erlang:element(4, D) end).

-file("src/gleamdb.gleam", 130).
-spec get_one(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    gleamdb@fact:eid(),
    binary()
) -> {ok, gleamdb@fact:value()} | {error, nil}.
get_one(Db, Eid, Attr) ->
    _pipe = get(Db, Eid, Attr),
    gleam@list:first(_pipe).

-file("src/gleamdb.gleam", 134).
-spec set_schema(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    binary(),
    gleamdb@fact:attribute_config()
) -> {ok, nil} | {error, binary()}.
set_schema(Db, Attr, Config) ->
    gleamdb@transactor:set_schema(Db, Attr, Config).

-file("src/gleamdb.gleam", 138).
-spec set_schema_with_timeout(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    binary(),
    gleamdb@fact:attribute_config(),
    integer()
) -> {ok, nil} | {error, binary()}.
set_schema_with_timeout(Db, Attr, Config, Timeout_ms) ->
    gleamdb@transactor:set_schema_with_timeout(Db, Attr, Config, Timeout_ms).

-file("src/gleamdb.gleam", 142).
-spec history(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    gleamdb@fact:eid()
) -> list(gleamdb@fact:datom()).
history(Db, Eid) ->
    State = gleamdb@transactor:get_state(Db),
    Id = case Eid of
        {uid, I} ->
            I;

        {lookup, {A, V}} ->
            _pipe = gleamdb@index:get_entity_by_av(
                erlang:element(5, State),
                A,
                V
            ),
            gleam@result:unwrap(_pipe, {entity_id, 0})
    end,
    gleamdb@engine:entity_history(State, Id).

-file("src/gleamdb.gleam", 153).
-spec pull(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    gleamdb@fact:eid(),
    list(gleamdb@engine:pull_item())
) -> gleamdb@engine:pull_result().
pull(Db, Eid, Pattern) ->
    State = gleamdb@transactor:get_state(Db),
    Id = case Eid of
        {uid, I} ->
            I;

        {lookup, {A, V}} ->
            _pipe = gleamdb@index:get_entity_by_av(
                erlang:element(5, State),
                A,
                V
            ),
            gleam@result:unwrap(_pipe, {entity_id, 0})
    end,
    gleamdb@engine:pull(State, {uid, Id}, Pattern).

-file("src/gleamdb.gleam", 168).
-spec diff(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    integer(),
    integer()
) -> list(gleamdb@fact:datom()).
diff(Db, From_tx, To_tx) ->
    State = gleamdb@transactor:get_state(Db),
    gleamdb@engine:diff(State, From_tx, To_tx).

-file("src/gleamdb.gleam", 173).
-spec pull_all() -> list(gleamdb@engine:pull_item()).
pull_all() ->
    [wildcard].

-file("src/gleamdb.gleam", 177).
-spec pull_attr(binary()) -> list(gleamdb@engine:pull_item()).
pull_attr(Attr) ->
    [{attr, Attr}].

-file("src/gleamdb.gleam", 181).
-spec pull_except(list(binary())) -> list(gleamdb@engine:pull_item()).
pull_except(Exclusions) ->
    [{except, Exclusions}].

-file("src/gleamdb.gleam", 185).
-spec pull_recursive(binary(), integer()) -> list(gleamdb@engine:pull_item()).
pull_recursive(Attr, Depth) ->
    [{recursion, Attr, Depth}].

-file("src/gleamdb.gleam", 193).
-spec query_at(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    list(gleamdb@shared@types:body_clause()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> gleamdb@shared@types:query_result().
query_at(Db, Q_clauses, As_of_tx, As_of_valid) ->
    State = gleamdb@transactor:get_state(Db),
    gleamdb@engine:run(State, Q_clauses, [], As_of_tx, As_of_valid).

-file("src/gleamdb.gleam", 189).
-spec 'query'(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    list(gleamdb@shared@types:body_clause())
) -> gleamdb@shared@types:query_result().
'query'(Db, Q_clauses) ->
    query_at(Db, Q_clauses, none, none).

-file("src/gleamdb.gleam", 207).
-spec query_state_at(
    gleamdb@shared@types:db_state(),
    list(gleamdb@shared@types:body_clause()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> gleamdb@shared@types:query_result().
query_state_at(State, Q_clauses, As_of_tx, As_of_valid) ->
    gleamdb@engine:run(State, Q_clauses, [], As_of_tx, As_of_valid).

-file("src/gleamdb.gleam", 203).
-spec query_state(
    gleamdb@shared@types:db_state(),
    list(gleamdb@shared@types:body_clause())
) -> gleamdb@shared@types:query_result().
query_state(State, Q_clauses) ->
    query_state_at(State, Q_clauses, none, none).

-file("src/gleamdb.gleam", 216).
-spec query_state_with_rules(
    gleamdb@shared@types:db_state(),
    list(gleamdb@shared@types:body_clause()),
    list(gleamdb@shared@types:rule())
) -> gleamdb@shared@types:query_result().
query_state_with_rules(State, Q_clauses, Rules) ->
    gleamdb@engine:run(State, Q_clauses, Rules, none, none).

-file("src/gleamdb.gleam", 224).
-spec query_with_rules(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    list(gleamdb@shared@types:body_clause()),
    list(gleamdb@shared@types:rule())
) -> gleamdb@shared@types:query_result().
query_with_rules(Db, Q_clauses, Rules) ->
    State = gleamdb@transactor:get_state(Db),
    gleamdb@engine:run(State, Q_clauses, Rules, none, none).

-file("src/gleamdb.gleam", 229).
-spec explain(list(gleamdb@shared@types:body_clause())) -> binary().
explain(Q_clauses) ->
    gleamdb@engine:explain(Q_clauses).

-file("src/gleamdb.gleam", 233).
-spec as_of(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    integer(),
    list(gleamdb@shared@types:body_clause())
) -> gleamdb@shared@types:query_result().
as_of(Db, Tx, Q_clauses) ->
    State = gleamdb@transactor:get_state(Db),
    gleamdb@engine:run(State, Q_clauses, [], {some, Tx}, none).

-file("src/gleamdb.gleam", 238).
-spec as_of_valid(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    integer(),
    list(gleamdb@shared@types:body_clause())
) -> gleamdb@shared@types:query_result().
as_of_valid(Db, Valid_time, Q_clauses) ->
    State = gleamdb@transactor:get_state(Db),
    gleamdb@engine:run(State, Q_clauses, [], none, {some, Valid_time}).

-file("src/gleamdb.gleam", 243).
-spec as_of_bitemporal(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    integer(),
    integer(),
    list(gleamdb@shared@types:body_clause())
) -> gleamdb@shared@types:query_result().
as_of_bitemporal(Db, Tx, Valid_time, Q_clauses) ->
    State = gleamdb@transactor:get_state(Db),
    gleamdb@engine:run(State, Q_clauses, [], {some, Tx}, {some, Valid_time}).

-file("src/gleamdb.gleam", 248).
-spec p({gleamdb@shared@types:part(), binary(), gleamdb@shared@types:part()}) -> gleamdb@shared@types:body_clause().
p(Triple) ->
    {positive, Triple}.

-file("src/gleamdb.gleam", 252).
-spec register_function(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    binary(),
    fun((gleamdb@shared@types:db_state(), integer(), integer(), list(gleamdb@fact:value())) -> list({gleamdb@fact:eid(),
        binary(),
        gleamdb@fact:value()}))
) -> nil.
register_function(Db, Name, Func) ->
    gleamdb@transactor:register_function(Db, Name, Func).

-file("src/gleamdb.gleam", 260).
-spec register_composite(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    list(binary())
) -> {ok, nil} | {error, binary()}.
register_composite(Db, Attrs) ->
    gleamdb@transactor:register_composite(Db, Attrs).

-file("src/gleamdb.gleam", 264).
-spec register_predicate(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    binary(),
    fun((gleamdb@fact:value()) -> boolean())
) -> nil.
register_predicate(Db, Name, Pred) ->
    gleamdb@transactor:register_predicate(Db, Name, Pred).

-file("src/gleamdb.gleam", 268).
-spec store_rule(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    gleamdb@shared@types:rule()
) -> {ok, nil} | {error, binary()}.
store_rule(Db, Rule) ->
    gleamdb@transactor:store_rule(Db, Rule).

-file("src/gleamdb.gleam", 272).
-spec set_config(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    gleamdb@shared@types:config()
) -> nil.
set_config(Db, Config) ->
    gleamdb@transactor:set_config(Db, Config).

-file("src/gleamdb.gleam", 276).
-spec subscribe(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    list(gleamdb@shared@types:body_clause()),
    gleam@erlang@process:subject(gleamdb@shared@types:reactive_delta())
) -> nil.
subscribe(Db, Query, Subscriber) ->
    State = gleamdb@transactor:get_state(Db),
    Results = gleamdb@engine:run(State, Query, [], none, none),
    Attrs = gleam@list:filter_map(Query, fun(C) -> case C of
                {positive, {_, A, _}} ->
                    {ok, A};

                {negative, {_, A@1, _}} ->
                    {ok, A@1};

                _ ->
                    {error, nil}
            end end),
    Msg = {subscribe, Query, Attrs, Subscriber, Results},
    gleam@erlang@process:send(erlang:element(11, State), Msg),
    gleam@erlang@process:send(Subscriber, {initial, Results}),
    nil.

-file("src/gleamdb.gleam", 298).
-spec get_state(gleam@erlang@process:subject(gleamdb@transactor:message())) -> gleamdb@shared@types:db_state().
get_state(Db) ->
    gleamdb@transactor:get_state(Db).

-file("src/gleamdb.gleam", 302).
-spec sync(gleam@erlang@process:subject(gleamdb@transactor:message())) -> nil.
sync(Db) ->
    Reply = gleam@erlang@process:new_subject(),
    gleam@erlang@process:send(Db, {sync, Reply}),
    _ = gleam@erlang@process:'receive'(Reply, 5000),
    nil.

-file("src/gleamdb.gleam", 309).
-spec is_leader(gleam@erlang@process:subject(gleamdb@transactor:message())) -> boolean().
is_leader(Db) ->
    State = gleamdb@transactor:get_state(Db),
    gleamdb@raft:is_leader(erlang:element(15, State)).
