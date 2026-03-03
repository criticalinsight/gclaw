-module(gleamdb@sharded).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/sharded.gleam").
-export([query_at/4, 'query'/2, stop/1, pull/3, transact/2, start_sharded/3, start_local_sharded/3]).
-export_type([sharded_db/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type sharded_db() :: {sharded_db,
        gleam@dict:dict(integer(), gleam@erlang@process:subject(gleamdb@transactor:message())),
        integer(),
        binary()}.

-file("src/gleamdb/sharded.gleam", 170).
?DOC(" Query the sharded database at a specific temporal basis.\n").
-spec query_at(
    sharded_db(),
    list(gleamdb@shared@types:body_clause()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> gleamdb@shared@types:query_result().
query_at(Db, Clauses, As_of_tx, As_of_valid) ->
    Shard_list = maps:to_list(erlang:element(2, Db)),
    Self = gleam@erlang@process:new_subject(),
    gleam@list:each(
        Shard_list,
        fun(Pair) ->
            {_, Shard_db} = Pair,
            proc_lib:spawn_link(
                fun() ->
                    Res = gleamdb@engine:run(
                        gleamdb:get_state(Shard_db),
                        Clauses,
                        [],
                        As_of_tx,
                        As_of_valid
                    ),
                    gleam@erlang@process:send(Self, Res)
                end
            )
        end
    ),
    gleam@int:range(
        0,
        erlang:length(Shard_list),
        {query_result, [], {query_metadata, none, none, 0, none}},
        fun(Acc, _) ->
            Res@1 = begin
                _pipe = gleam@erlang@process:'receive'(Self, 5000),
                gleam@result:unwrap(
                    _pipe,
                    {query_result, [], {query_metadata, none, none, 0, none}}
                )
            end,
            {query_result,
                lists:append(erlang:element(2, Acc), erlang:element(2, Res@1)),
                {query_metadata,
                    case {erlang:element(2, erlang:element(3, Acc)),
                        erlang:element(2, erlang:element(3, Res@1))} of
                        {{some, A}, {some, B}} ->
                            {some, gleam@int:max(A, B)};

                        {{some, _}, none} ->
                            erlang:element(2, erlang:element(3, Acc));

                        {none, {some, _}} ->
                            erlang:element(2, erlang:element(3, Res@1));

                        {none, none} ->
                            none
                    end,
                    case {erlang:element(3, erlang:element(3, Acc)),
                        erlang:element(3, erlang:element(3, Res@1))} of
                        {{some, A@1}, {some, B@1}} ->
                            {some, gleam@int:max(A@1, B@1)};

                        {{some, _}, none} ->
                            erlang:element(3, erlang:element(3, Acc));

                        {none, {some, _}} ->
                            erlang:element(3, erlang:element(3, Res@1));

                        {none, none} ->
                            none
                    end,
                    erlang:element(4, erlang:element(3, Acc)) + erlang:element(
                        4,
                        erlang:element(3, Res@1)
                    ),
                    erlang:element(5, erlang:element(3, Acc))}}
        end
    ).

-file("src/gleamdb/sharded.gleam", 165).
?DOC(
    " Query the sharded database (Parallel Scatter-Gather).\n"
    " Warning: This performs a full scan across all shards.\n"
).
-spec 'query'(sharded_db(), list(gleamdb@shared@types:body_clause())) -> gleamdb@shared@types:query_result().
'query'(Db, Clauses) ->
    query_at(Db, Clauses, none, none).

-file("src/gleamdb/sharded.gleam", 271).
?DOC(" Stop the sharded database.\n").
-spec stop(sharded_db()) -> nil.
stop(Db) ->
    Shard_list = maps:to_list(erlang:element(2, Db)),
    gleam@list:each(
        Shard_list,
        fun(Pair) ->
            {_, Shard_db} = Pair,
            Pid@1 = case gleam@erlang@process:subject_owner(Shard_db) of
                {ok, Pid} -> Pid;
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gleamdb/sharded"/utf8>>,
                                function => <<"stop"/utf8>>,
                                line => 275,
                                value => _assert_fail,
                                start => 7746,
                                'end' => 7798,
                                pattern_start => 7757,
                                pattern_end => 7764})
            end,
            gleam@erlang@process:unlink(Pid@1),
            gleam@erlang@process:kill(Pid@1)
        end
    ).

-file("src/gleamdb/sharded.gleam", 281).
-spec merge_pull_results(
    gleamdb@engine:pull_result(),
    gleamdb@engine:pull_result()
) -> gleamdb@engine:pull_result().
merge_pull_results(A, B) ->
    case {A, B} of
        {{map, D1}, {map, D2}} ->
            {map, maps:merge(D1, D2)};

        {_, {map, _}} ->
            B;

        {{map, _}, _} ->
            A;

        {_, _} ->
            A
    end.

-file("src/gleamdb/sharded.gleam", 245).
?DOC(" Pull an entity in parallel across all shards.\n").
-spec pull(sharded_db(), gleamdb@fact:eid(), list(gleamdb@engine:pull_item())) -> gleamdb@engine:pull_result().
pull(Db, Eid, Pattern) ->
    Shard_list = maps:to_list(erlang:element(2, Db)),
    Self = gleam@erlang@process:new_subject(),
    gleam@list:each(
        Shard_list,
        fun(Pair) ->
            {_, Shard_db} = Pair,
            proc_lib:spawn_link(
                fun() ->
                    Res = gleamdb:pull(Shard_db, Eid, Pattern),
                    gleam@erlang@process:send(Self, Res)
                end
            )
        end
    ),
    gleam@int:range(
        0,
        erlang:length(Shard_list),
        {map, maps:new()},
        fun(Acc, _) ->
            Res@1 = begin
                _pipe = gleam@erlang@process:'receive'(Self, 5000),
                gleam@result:unwrap(_pipe, {map, maps:new()})
            end,
            merge_pull_results(Acc, Res@1)
        end
    ).

-file("src/gleamdb/sharded.gleam", 290).
-spec get_shard_id(gleamdb@fact:eid(), integer()) -> integer().
get_shard_id(Eid, Shard_count) ->
    case Eid of
        {uid, {entity_id, Id}} ->
            case Shard_count of
                0 -> 0;
                Gleam@denominator -> Id rem Gleam@denominator
            end;

        {lookup, {_, Val}} ->
            case Shard_count of
                0 -> 0;
                Gleam@denominator@1 -> erlang:phash2(Val) rem Gleam@denominator@1
            end
    end.

-file("src/gleamdb/sharded.gleam", 123).
?DOC(
    " Ingest facts into the sharded database in parallel.\n"
    " Routing is determined by hashing the Entity ID (Eid).\n"
).
-spec transact(
    sharded_db(),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()})
) -> {ok, list(gleamdb@shared@types:db_state())} | {error, binary()}.
transact(Db, Facts) ->
    Grouped = gleam@list:fold(
        Facts,
        maps:new(),
        fun(Acc, F) ->
            Shard_id = get_shard_id(erlang:element(1, F), erlang:element(3, Db)),
            Shard_facts = begin
                _pipe = gleam_stdlib:map_get(Acc, Shard_id),
                gleam@result:unwrap(_pipe, [])
            end,
            gleam@dict:insert(Acc, Shard_id, [F | Shard_facts])
        end
    ),
    Grouped_list = maps:to_list(Grouped),
    case Grouped_list of
        [] ->
            {ok, []};

        _ ->
            Self = gleam@erlang@process:new_subject(),
            gleam@list:each(
                Grouped_list,
                fun(Pair) ->
                    {Shard_id@1, Shard_facts@1} = Pair,
                    proc_lib:spawn_link(
                        fun() ->
                            Shard_db@1 = case gleam_stdlib:map_get(
                                erlang:element(2, Db),
                                Shard_id@1
                            ) of
                                {ok, Shard_db} -> Shard_db;
                                _assert_fail ->
                                    erlang:error(#{gleam_error => let_assert,
                                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                                file => <<?FILEPATH/utf8>>,
                                                module => <<"gleamdb/sharded"/utf8>>,
                                                function => <<"transact"/utf8>>,
                                                line => 141,
                                                value => _assert_fail,
                                                start => 3870,
                                                'end' => 3925,
                                                pattern_start => 3881,
                                                pattern_end => 3893})
                            end,
                            Res = case gleamdb:transact(
                                Shard_db@1,
                                Shard_facts@1
                            ) of
                                {ok, State} ->
                                    {ok, State};

                                {error, E} ->
                                    {error,
                                        <<<<<<"Shard "/utf8,
                                                    (gleam@string:inspect(
                                                        Shard_id@1
                                                    ))/binary>>/binary,
                                                " transact failed: "/utf8>>/binary,
                                            E/binary>>}
                            end,
                            gleam@erlang@process:send(Self, Res)
                        end
                    )
                end
            ),
            _pipe@1 = gleam@int:range(
                0,
                erlang:length(Grouped_list),
                [],
                fun(Acc@1, _) ->
                    Res@2 = case gleam@erlang@process:'receive'(Self, 5000) of
                        {ok, Res@1} ->
                            Res@1;

                        {error, _} ->
                            {error, <<"Timeout waiting for shard"/utf8>>}
                    end,
                    [Res@2 | Acc@1]
                end
            ),
            gleam@list:try_map(_pipe@1, fun(X) -> X end)
    end.

-file("src/gleamdb/sharded.gleam", 297).
-spec string_inspect_actor_error(gleam@otp@actor:start_error()) -> binary().
string_inspect_actor_error(E) ->
    gleam@string:inspect(E).

-file("src/gleamdb/sharded.gleam", 24).
?DOC(" Start a sharded database cluster.\n").
-spec start_sharded(
    binary(),
    integer(),
    gleam@option:option(gleamdb@storage:storage_adapter())
) -> {ok, sharded_db()} | {error, binary()}.
start_sharded(Cluster_id, Shard_count, Adapter) ->
    Self = gleam@erlang@process:new_subject(),
    _pipe = gleam@int:range(0, Shard_count, [], fun(Acc, I) -> [I | Acc] end),
    gleam@list:each(
        _pipe,
        fun(I@1) ->
            proc_lib:spawn_link(
                fun() ->
                    Shard_cluster_id = <<<<Cluster_id/binary, "_s"/utf8>>/binary,
                        (gleam@string:inspect(I@1))/binary>>,
                    Res = case gleamdb:start_distributed(
                        Shard_cluster_id,
                        Adapter
                    ) of
                        {ok, Db} ->
                            {ok, {I@1, Db}};

                        {error, E} ->
                            {error,
                                <<<<<<"Failed to start shard "/utf8,
                                            (gleam@string:inspect(I@1))/binary>>/binary,
                                        ": "/utf8>>/binary,
                                    (string_inspect_actor_error(E))/binary>>}
                    end,
                    gleam@erlang@process:send(Self, Res)
                end
            )
        end
    ),
    Shards = begin
        _pipe@1 = gleam@int:range(
            0,
            Shard_count,
            [],
            fun(Acc@1, _) ->
                case gleam@erlang@process:'receive'(Self, 600000) of
                    {ok, Res@1} ->
                        [Res@1 | Acc@1];

                    {error, _} ->
                        [{error, <<"Timeout starting shards"/utf8>>} | Acc@1]
                end
            end
        ),
        gleam@list:try_map(_pipe@1, fun(X) -> X end)
    end,
    case Shards of
        {ok, S} ->
            {ok, {sharded_db, maps:from_list(S), Shard_count, Cluster_id}};

        {error, E@1} ->
            {error, E@1}
    end.

-file("src/gleamdb/sharded.gleam", 73).
?DOC(" Start a sharded database cluster in local (named) mode.\n").
-spec start_local_sharded(
    binary(),
    integer(),
    gleam@option:option(gleamdb@storage:storage_adapter())
) -> {ok, sharded_db()} | {error, binary()}.
start_local_sharded(Cluster_id, Shard_count, Adapter) ->
    Self = gleam@erlang@process:new_subject(),
    _pipe = gleam@int:range(0, Shard_count, [], fun(Acc, I) -> [I | Acc] end),
    gleam@list:each(
        _pipe,
        fun(I@1) ->
            proc_lib:spawn_link(
                fun() ->
                    Shard_cluster_id = <<<<Cluster_id/binary, "_s"/utf8>>/binary,
                        (gleam@string:inspect(I@1))/binary>>,
                    Res = case gleamdb:start_named(Shard_cluster_id, Adapter) of
                        {ok, Db} ->
                            {ok, {I@1, Db}};

                        {error, E} ->
                            {error,
                                <<<<<<"Failed to start local shard "/utf8,
                                            (gleam@string:inspect(I@1))/binary>>/binary,
                                        ": "/utf8>>/binary,
                                    (string_inspect_actor_error(E))/binary>>}
                    end,
                    gleam@erlang@process:send(Self, Res)
                end
            )
        end
    ),
    Shards = begin
        _pipe@1 = gleam@int:range(
            0,
            Shard_count,
            [],
            fun(Acc@1, _) ->
                case gleam@erlang@process:'receive'(Self, 300000) of
                    {ok, Res@1} ->
                        [Res@1 | Acc@1];

                    {error, _} ->
                        [{error, <<"Timeout starting shards"/utf8>>} | Acc@1]
                end
            end
        ),
        gleam@list:try_map(_pipe@1, fun(X) -> X end)
    end,
    case Shards of
        {ok, S} ->
            {ok, {sharded_db, maps:from_list(S), Shard_count, Cluster_id}};

        {error, E@1} ->
            {error, E@1}
    end.
