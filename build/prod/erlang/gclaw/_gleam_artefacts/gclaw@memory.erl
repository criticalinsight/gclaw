-module(gclaw@memory).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gclaw/memory.gleam").
-export([init_ephemeral/0, init_persistent/1, remember/2, remember_semantic/3, recall_hybrid/4, get_context_window/4]).
-export_type([memory/0]).

-type memory() :: {memory,
        gleam@erlang@process:subject(gleamdb@transactor:message())}.

-file("src/gclaw/memory.gleam", 29).
-spec init(gleamdb@storage:storage_adapter()) -> memory().
init(Adapter) ->
    Db@1 = case gleamdb@transactor:start(Adapter) of
        {ok, Db} -> Db;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gclaw/memory"/utf8>>,
                        function => <<"init"/utf8>>,
                        line => 30,
                        value => _assert_fail,
                        start => 591,
                        'end' => 636,
                        pattern_start => 602,
                        pattern_end => 608})
    end,
    _ = gleamdb@transactor:set_schema(
        Db@1,
        <<"msg/timestamp"/utf8>>,
        {attribute_config, false, false, all, one, none}
    ),
    _ = gleamdb@transactor:set_schema(
        Db@1,
        <<"mem/vector"/utf8>>,
        {attribute_config, false, false, latest_only, one, none}
    ),
    _ = gleamdb@transactor:set_schema(
        Db@1,
        <<"msg/session"/utf8>>,
        {attribute_config, false, false, all, one, none}
    ),
    _ = gleamdb@transactor:create_bm25_index(Db@1, <<"content"/utf8>>),
    _ = gleamdb@transactor:set_schema(
        Db@1,
        <<"type"/utf8>>,
        {attribute_config, false, false, all, one, none}
    ),
    _ = gleamdb@transactor:set_schema(
        Db@1,
        <<"source"/utf8>>,
        {attribute_config, false, false, all, one, none}
    ),
    _ = gleamdb@transactor:set_schema(
        Db@1,
        <<"tags"/utf8>>,
        {attribute_config, false, false, all, many, none}
    ),
    _ = gleamdb@transactor:register_index_adapter(
        Db@1,
        gclaw@metrics:new_adapter()
    ),
    _ = gleamdb@transactor:create_index(
        Db@1,
        <<"importance"/utf8>>,
        <<"metric"/utf8>>,
        <<"importance"/utf8>>
    ),
    _ = gleamdb@transactor:create_index(
        Db@1,
        <<"sentiment"/utf8>>,
        <<"metric"/utf8>>,
        <<"sentiment"/utf8>>
    ),
    {memory, Db@1}.

-file("src/gclaw/memory.gleam", 21).
-spec init_ephemeral() -> memory().
init_ephemeral() ->
    init(gleamdb@storage:ephemeral()).

-file("src/gclaw/memory.gleam", 25).
-spec init_persistent(binary()) -> memory().
init_persistent(Path) ->
    init(gleamdb@storage@disk:disk(Path)).

-file("src/gclaw/memory.gleam", 99).
-spec remember(
    memory(),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()})
) -> memory().
remember(Mem, Facts) ->
    _ = gleamdb@transactor:transact(erlang:element(2, Mem), Facts),
    Mem.

-file("src/gclaw/memory.gleam", 105).
-spec remember_semantic(
    memory(),
    list({gleamdb@fact:eid(), binary(), gleamdb@fact:value()}),
    list(float())
) -> memory().
remember_semantic(Mem, Facts, Vector) ->
    Facts_with_vector = case Facts of
        [{Eid, _, _} | _] ->
            [{Eid, <<"mem/vector"/utf8>>, {vec, Vector}} | Facts];

        _ ->
            Facts
    end,
    remember(Mem, Facts_with_vector).

-file("src/gclaw/memory.gleam", 117).
-spec recall_hybrid(memory(), binary(), list(float()), integer()) -> list(binary()).
recall_hybrid(Mem, Query_text, Query_vec, Limit) ->
    State = gleamdb@transactor:get_state(erlang:element(2, Mem)),
    Bm25_query = [{b_m25,
            <<"val"/utf8>>,
            <<"content"/utf8>>,
            Query_text,
            +0.0,
            1.2,
            0.75}],
    Bm25_results = erlang:element(
        2,
        gleamdb@engine:run(State, Bm25_query, [], none, none)
    ),
    Bm25_scored = gleam@list:filter_map(
        Bm25_results,
        fun(Row) -> case gleam_stdlib:map_get(Row, <<"val"/utf8>>) of
                {ok, {ref, Eid}} ->
                    {ok, {scored_result, Eid, 1.0}};

                _ ->
                    {error, nil}
            end end
    ),
    Vec_query = [{similarity_entity, <<"val"/utf8>>, Query_vec, 0.7}],
    Vec_results = erlang:element(
        2,
        gleamdb@engine:run(State, Vec_query, [], none, none)
    ),
    Vec_scored = gleam@list:filter_map(
        Vec_results,
        fun(Row@1) -> case gleam_stdlib:map_get(Row@1, <<"val"/utf8>>) of
                {ok, {ref, Eid@1}} ->
                    {ok, {scored_result, Eid@1, 1.0}};

                _ ->
                    {error, nil}
            end end
    ),
    Combined = gleamdb@scoring:weighted_union(
        Bm25_scored,
        Vec_scored,
        0.3,
        0.7,
        min_max
    ),
    _pipe = gleam@list:take(Combined, Limit),
    gleam@list:map(
        _pipe,
        fun(R) ->
            {entity_id, Eid@2} = erlang:element(2, R),
            <<"Entity: "/utf8, (erlang:integer_to_binary(Eid@2))/binary>>
        end
    ).

-file("src/gclaw/memory.gleam", 177).
-spec get_context_window(memory(), binary(), integer(), list(float())) -> list(binary()).
get_context_window(Mem, Session_id, Limit, Query_vec) ->
    State = gleamdb@transactor:get_state(erlang:element(2, Mem)),
    Recent_clauses = [{positive,
            {{var, <<"m"/utf8>>},
                <<"msg/session"/utf8>>,
                {val, {str, Session_id}}}},
        {positive,
            {{var, <<"m"/utf8>>},
                <<"msg/content"/utf8>>,
                {var, <<"content"/utf8>>}}},
        {positive,
            {{var, <<"m"/utf8>>}, <<"msg/role"/utf8>>, {var, <<"role"/utf8>>}}},
        {positive,
            {{var, <<"m"/utf8>>},
                <<"msg/timestamp"/utf8>>,
                {var, <<"ts"/utf8>>}}},
        {order_by, <<"ts"/utf8>>, desc},
        {limit, Limit}],
    Recent_results = erlang:element(
        2,
        gleamdb@engine:run(State, Recent_clauses, [], none, none)
    ),
    Semantic_results = case gleam@list:is_empty(Query_vec) of
        true ->
            [];

        false ->
            Vec_clauses = [{similarity_entity, <<"m"/utf8>>, Query_vec, +0.0},
                {positive,
                    {{var, <<"m"/utf8>>},
                        <<"msg/session"/utf8>>,
                        {var, <<"sess"/utf8>>}}},
                {positive,
                    {{var, <<"m"/utf8>>},
                        <<"msg/content"/utf8>>,
                        {var, <<"content"/utf8>>}}},
                {positive,
                    {{var, <<"m"/utf8>>},
                        <<"msg/role"/utf8>>,
                        {var, <<"role"/utf8>>}}},
                {positive,
                    {{var, <<"m"/utf8>>},
                        <<"msg/timestamp"/utf8>>,
                        {var, <<"ts"/utf8>>}}},
                {filter, {eq, {var, <<"sess"/utf8>>}, {val, {str, Session_id}}}},
                {limit, Limit}],
            Res = erlang:element(
                2,
                gleamdb@engine:run(State, Vec_clauses, [], none, none)
            ),
            Res
    end,
    Merged = gleam@list:fold(
        lists:append(Recent_results, Semantic_results),
        maps:new(),
        fun(Acc, R) ->
            Ts@1 = case gleam_stdlib:map_get(R, <<"ts"/utf8>>) of
                {ok, {int, Ts}} -> Ts;
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gclaw/memory"/utf8>>,
                                function => <<"get_context_window"/utf8>>,
                                line => 213,
                                value => _assert_fail,
                                start => 6978,
                                'end' => 7025,
                                pattern_start => 6989,
                                pattern_end => 7005})
            end,
            gleam@dict:insert(Acc, Ts@1, R)
        end
    ),
    _pipe = maps:values(Merged),
    _pipe@1 = gleam@list:sort(
        _pipe,
        fun(A, B) ->
            Ts_a@1 = case gleam_stdlib:map_get(A, <<"ts"/utf8>>) of
                {ok, {int, Ts_a}} -> Ts_a;
                _assert_fail@1 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gclaw/memory"/utf8>>,
                                function => <<"get_context_window"/utf8>>,
                                line => 220,
                                value => _assert_fail@1,
                                start => 7138,
                                'end' => 7187,
                                pattern_start => 7149,
                                pattern_end => 7167})
            end,
            Ts_b@1 = case gleam_stdlib:map_get(B, <<"ts"/utf8>>) of
                {ok, {int, Ts_b}} -> Ts_b;
                _assert_fail@2 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gclaw/memory"/utf8>>,
                                function => <<"get_context_window"/utf8>>,
                                line => 221,
                                value => _assert_fail@2,
                                start => 7192,
                                'end' => 7241,
                                pattern_start => 7203,
                                pattern_end => 7221})
            end,
            case Ts_a@1 =< Ts_b@1 of
                true ->
                    lt;

                false ->
                    gt
            end
        end
    ),
    gleam@list:map(
        _pipe@1,
        fun(R@1) ->
            Role@1 = case gleam_stdlib:map_get(R@1, <<"role"/utf8>>) of
                {ok, {str, Role}} -> Role;
                _assert_fail@3 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gclaw/memory"/utf8>>,
                                function => <<"get_context_window"/utf8>>,
                                line => 228,
                                value => _assert_fail@3,
                                start => 7350,
                                'end' => 7401,
                                pattern_start => 7361,
                                pattern_end => 7379})
            end,
            Content@1 = case gleam_stdlib:map_get(R@1, <<"content"/utf8>>) of
                {ok, {str, Content}} -> Content;
                _assert_fail@4 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gclaw/memory"/utf8>>,
                                function => <<"get_context_window"/utf8>>,
                                line => 229,
                                value => _assert_fail@4,
                                start => 7406,
                                'end' => 7463,
                                pattern_start => 7417,
                                pattern_end => 7438})
            end,
            <<<<Role@1/binary, ": "/utf8>>/binary, Content@1/binary>>
        end
    ).
