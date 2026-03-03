-module(gleamdb@engine).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/engine.gleam").
-export([entity_history/2, pull/3, diff/3, explain/1, filter_by_time/3, run/5]).
-export_type([pull_item/0, pull_result/0]).

-type pull_item() :: wildcard |
    {attr, binary()} |
    {nested, binary(), list(pull_item())} |
    {except, list(binary())} |
    {recursion, binary(), integer()}.

-type pull_result() :: {map, gleam@dict:dict(binary(), pull_result())} |
    {single, gleamdb@fact:value()} |
    {many, list(gleamdb@fact:value())} |
    {nested_many, list(pull_result())}.

-file("src/gleamdb/engine.gleam", 538).
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
    _pipe = gleam@list:filter(
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
    ),
    gleam@list:unique(_pipe).

-file("src/gleamdb/engine.gleam", 557).
-spec resolve_part(
    gleamdb@shared@types:part(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> gleam@option:option(gleamdb@fact:value()).
resolve_part(Part, Ctx) ->
    case Part of
        {var, Name} ->
            gleam@option:from_result(gleam_stdlib:map_get(Ctx, Name));

        {val, Val} ->
            {some, Val}
    end.

-file("src/gleamdb/engine.gleam", 564).
-spec resolve_part_optional(
    gleamdb@shared@types:part(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> gleam@option:option(gleamdb@fact:value()).
resolve_part_optional(Part, Ctx) ->
    case Part of
        {var, Name} ->
            gleam@option:from_result(gleam_stdlib:map_get(Ctx, Name));

        {val, Val} ->
            {some, Val}
    end.

-file("src/gleamdb/engine.gleam", 664).
-spec compare_values(gleamdb@fact:value(), gleamdb@fact:value()) -> gleam@order:order().
compare_values(A, B) ->
    case {A, B} of
        {{int, I1}, {int, I2}} ->
            gleam@int:compare(I1, I2);

        {{float, F1}, {float, F2}} ->
            gleam@float:compare(F1, F2);

        {{str, S1}, {str, S2}} ->
            gleam@string:compare(S1, S2);

        {{int, I}, {float, F}} ->
            gleam@float:compare(erlang:float(I), F);

        {{float, F@1}, {int, I@1}} ->
            gleam@float:compare(F@1, erlang:float(I@1));

        {_, _} ->
            eq
    end.

-file("src/gleamdb/engine.gleam", 737).
-spec entity_history(gleamdb@shared@types:db_state(), gleamdb@fact:entity_id()) -> list(gleamdb@fact:datom()).
entity_history(Db_state, Eid) ->
    _pipe = gleam_stdlib:map_get(erlang:element(3, Db_state), Eid),
    _pipe@1 = gleam@result:unwrap(_pipe, []),
    gleam@list:sort(
        _pipe@1,
        fun(A, B) ->
            case gleam@int:compare(erlang:element(5, A), erlang:element(5, B)) of
                eq ->
                    case {erlang:element(7, A), erlang:element(7, B)} of
                        {retract, assert} ->
                            lt;

                        {assert, retract} ->
                            gt;

                        {_, _} ->
                            eq
                    end;

                Other ->
                    Other
            end
        end
    ).

-file("src/gleamdb/engine.gleam", 754).
-spec pull(
    gleamdb@shared@types:db_state(),
    gleamdb@fact:eid(),
    list(pull_item())
) -> pull_result().
pull(Db_state, Eid, Pattern) ->
    Id = case Eid of
        {uid, {entity_id, I}} ->
            {entity_id, I};

        {lookup, {A, V}} ->
            _pipe = gleamdb@index:get_entity_by_av(
                erlang:element(5, Db_state),
                A,
                V
            ),
            gleam@result:unwrap(_pipe, {entity_id, 0})
    end,
    Datoms = begin
        _pipe@1 = gleamdb@index:filter_by_entity(
            erlang:element(3, Db_state),
            Id
        ),
        _pipe@2 = lists:reverse(_pipe@1),
        filter_active(_pipe@2)
    end,
    M = gleam@list:fold(Pattern, maps:new(), fun(Acc, Item) -> case Item of
                wildcard ->
                    gleam@list:fold(
                        Datoms,
                        Acc,
                        fun(Inner_acc, D) ->
                            gleam@dict:insert(
                                Inner_acc,
                                erlang:element(3, D),
                                {single, erlang:element(4, D)}
                            )
                        end
                    );

                {attr, Name} ->
                    Values = begin
                        _pipe@3 = gleam@list:filter(
                            Datoms,
                            fun(D@1) -> erlang:element(3, D@1) =:= Name end
                        ),
                        gleam@list:map(
                            _pipe@3,
                            fun(D@2) -> erlang:element(4, D@2) end
                        )
                    end,
                    case Values of
                        [V@1] ->
                            gleam@dict:insert(Acc, Name, {single, V@1});

                        [_ | _] ->
                            gleam@dict:insert(Acc, Name, {many, Values});

                        [] ->
                            Acc
                    end;

                {except, Exclusions} ->
                    gleam@list:fold(
                        Datoms,
                        Acc,
                        fun(Inner_acc@1, D@3) ->
                            case gleam@list:contains(
                                Exclusions,
                                erlang:element(3, D@3)
                            ) of
                                true ->
                                    Inner_acc@1;

                                false ->
                                    gleam@dict:insert(
                                        Inner_acc@1,
                                        erlang:element(3, D@3),
                                        {single, erlang:element(4, D@3)}
                                    )
                            end
                        end
                    );

                {recursion, Attr, Depth} ->
                    case Depth =< 0 of
                        true ->
                            Acc;

                        false ->
                            Values@1 = begin
                                _pipe@4 = gleam@list:filter(
                                    Datoms,
                                    fun(D@4) ->
                                        erlang:element(3, D@4) =:= Attr
                                    end
                                ),
                                gleam@list:map(
                                    _pipe@4,
                                    fun(D@5) -> erlang:element(4, D@5) end
                                )
                            end,
                            Results = gleam@list:map(
                                Values@1,
                                fun(V@2) -> case V@2 of
                                        {ref, Next_id} ->
                                            pull(
                                                Db_state,
                                                {uid, Next_id},
                                                [wildcard,
                                                    {recursion, Attr, Depth - 1}]
                                            );

                                        {int, Next_id_int} ->
                                            pull(
                                                Db_state,
                                                {uid, {entity_id, Next_id_int}},
                                                [wildcard,
                                                    {recursion, Attr, Depth - 1}]
                                            );

                                        _ ->
                                            {single, V@2}
                                    end end
                            ),
                            case Results of
                                [R] ->
                                    gleam@dict:insert(Acc, Attr, R);

                                [_ | _] ->
                                    gleam@dict:insert(
                                        Acc,
                                        Attr,
                                        {nested_many, Results}
                                    );

                                [] ->
                                    Acc
                            end
                    end;

                {nested, Name@1, Sub_pattern} ->
                    Values@2 = begin
                        _pipe@5 = gleam@list:filter(
                            Datoms,
                            fun(D@6) -> erlang:element(3, D@6) =:= Name@1 end
                        ),
                        gleam@list:map(
                            _pipe@5,
                            fun(D@7) -> erlang:element(4, D@7) end
                        )
                    end,
                    case Values@2 of
                        [{ref, Eid@1}] ->
                            Res = pull(Db_state, {uid, Eid@1}, Sub_pattern),
                            gleam@dict:insert(Acc, Name@1, Res);

                        [{int, Sub_id}] ->
                            Res@1 = pull(
                                Db_state,
                                {uid, {entity_id, Sub_id}},
                                Sub_pattern
                            ),
                            gleam@dict:insert(Acc, Name@1, Res@1);

                        [_ | _] ->
                            Res_list = gleam@list:map(
                                Values@2,
                                fun(V@3) -> case V@3 of
                                        {ref, Eid@2} ->
                                            pull(
                                                Db_state,
                                                {uid, Eid@2},
                                                Sub_pattern
                                            );

                                        {int, Sub_id@1} ->
                                            pull(
                                                Db_state,
                                                {uid, {entity_id, Sub_id@1}},
                                                Sub_pattern
                                            );

                                        _ ->
                                            {single, V@3}
                                    end end
                            ),
                            case Res_list of
                                [R@1] ->
                                    gleam@dict:insert(Acc, Name@1, R@1);

                                [_ | _] ->
                                    gleam@dict:insert(
                                        Acc,
                                        Name@1,
                                        {nested_many, Res_list}
                                    );

                                _ ->
                                    Acc
                            end;

                        _ ->
                            Acc
                    end
            end end),
    {map, M}.

-file("src/gleamdb/engine.gleam", 850).
-spec solve_temporal(
    gleamdb@shared@types:db_state(),
    binary(),
    gleamdb@shared@types:part(),
    binary(),
    integer(),
    integer(),
    gleamdb@shared@types:temporal_type(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_temporal(Db_state, Var, E_p, Attr, Start, End, Basis, Ctx) ->
    E_val = resolve_part(E_p, Ctx),
    Base_datoms = case E_val of
        {some, {ref, {entity_id, E}}} ->
            gleamdb@index:get_datoms_by_entity_attr(
                erlang:element(3, Db_state),
                {entity_id, E},
                Attr
            );

        {some, {int, E@1}} ->
            gleamdb@index:get_datoms_by_entity_attr(
                erlang:element(3, Db_state),
                {entity_id, E@1},
                Attr
            );

        _ ->
            []
    end,
    _pipe = Base_datoms,
    _pipe@1 = filter_active(_pipe),
    _pipe@2 = gleam@list:filter(
        _pipe@1,
        fun(D) ->
            Time = case Basis of
                tx ->
                    erlang:element(5, D);

                valid ->
                    erlang:element(6, D)
            end,
            (Time >= Start) andalso (Time =< End)
        end
    ),
    gleam@list:map(
        _pipe@2,
        fun(D@1) -> gleam@dict:insert(Ctx, Var, erlang:element(4, D@1)) end
    ).

-file("src/gleamdb/engine.gleam", 884).
-spec eval_expression(
    gleamdb@shared@types:expression(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> boolean().
eval_expression(Expr, Ctx) ->
    case Expr of
        {eq, A, B} ->
            Val_a = resolve_part_optional(A, Ctx),
            Val_b = resolve_part_optional(B, Ctx),
            (Val_a =:= Val_b) andalso gleam@option:is_some(Val_a);

        {neq, A@1, B@1} ->
            Val_a@1 = resolve_part_optional(A@1, Ctx),
            Val_b@1 = resolve_part_optional(B@1, Ctx),
            Val_a@1 /= Val_b@1;

        {gt, A@2, B@2} ->
            Val_a@2 = begin
                _pipe = resolve_part_optional(A@2, Ctx),
                gleam@option:unwrap(_pipe, {int, 0})
            end,
            Val_b@2 = begin
                _pipe@1 = resolve_part_optional(B@2, Ctx),
                gleam@option:unwrap(_pipe@1, {int, 0})
            end,
            compare_values(Val_a@2, Val_b@2) =:= gt;

        {lt, A@3, B@3} ->
            Val_a@3 = begin
                _pipe@2 = resolve_part_optional(A@3, Ctx),
                gleam@option:unwrap(_pipe@2, {int, 0})
            end,
            Val_b@3 = begin
                _pipe@3 = resolve_part_optional(B@3, Ctx),
                gleam@option:unwrap(_pipe@3, {int, 0})
            end,
            compare_values(Val_a@3, Val_b@3) =:= lt;

        {'and', L, R} ->
            eval_expression(L, Ctx) andalso eval_expression(R, Ctx);

        {'or', L@1, R@1} ->
            eval_expression(L@1, Ctx) orelse eval_expression(R@1, Ctx)
    end.

-file("src/gleamdb/engine.gleam", 911).
-spec resolve_entity_id_from_part(
    gleamdb@shared@types:part(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> gleam@option:option(gleamdb@fact:entity_id()).
resolve_entity_id_from_part(Part, Ctx) ->
    case resolve_part_optional(Part, Ctx) of
        {some, {ref, Eid}} ->
            {some, Eid};

        {some, {int, I}} ->
            {some, {entity_id, I}};

        _ ->
            none
    end.

-file("src/gleamdb/engine.gleam", 920).
-spec solve_starts_with(
    gleamdb@shared@types:db_state(),
    binary(),
    binary(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_starts_with(Db_state, Var, Prefix, Ctx) ->
    case gleam_stdlib:map_get(Ctx, Var) of
        {ok, Val} ->
            case Val of
                {str, S} ->
                    case gleam_stdlib:string_starts_with(S, Prefix) of
                        true ->
                            [Ctx];

                        false ->
                            []
                    end;

                _ ->
                    []
            end;

        {error, _} ->
            Entries = gleamdb@index@art:search_prefix_entries(
                erlang:element(18, Db_state),
                Prefix
            ),
            _pipe = gleam@list:map(
                Entries,
                fun(Entry) ->
                    {Val@1, _} = Entry,
                    gleam@dict:insert(Ctx, Var, Val@1)
                end
            ),
            gleam@list:unique(_pipe)
    end.

-file("src/gleamdb/engine.gleam", 982).
-spec solve_shortest_path(
    gleamdb@shared@types:db_state(),
    gleamdb@shared@types:part(),
    gleamdb@shared@types:part(),
    binary(),
    binary(),
    gleam@option:option(binary()),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_shortest_path(Db_state, From, To, Edge, Path_var, Cost_var, Ctx) ->
    From_eid = resolve_entity_id_from_part(From, Ctx),
    To_eid = resolve_entity_id_from_part(To, Ctx),
    case {From_eid, To_eid} of
        {{some, F}, {some, T}} ->
            case gleamdb@algo@graph:shortest_path(Db_state, F, T, Edge) of
                {some, Path} ->
                    Path_val = {list,
                        gleam@list:map(Path, fun(Field@0) -> {ref, Field@0} end)},
                    Ctx@1 = gleam@dict:insert(Ctx, Path_var, Path_val),
                    Ctx@2 = case Cost_var of
                        {some, Cv} ->
                            gleam@dict:insert(
                                Ctx@1,
                                Cv,
                                {int, erlang:length(Path) - 1}
                            );

                        none ->
                            Ctx@1
                    end,
                    [Ctx@2];

                none ->
                    []
            end;

        {_, _} ->
            []
    end.

-file("src/gleamdb/engine.gleam", 1013).
-spec solve_pagerank(
    gleamdb@shared@types:db_state(),
    binary(),
    binary(),
    binary(),
    float(),
    integer(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_pagerank(Db_state, Entity_var, Edge, Rank_var, Damping, Iterations, Ctx) ->
    Ranks = gleamdb@algo@graph:pagerank(Db_state, Edge, Damping, Iterations),
    case gleam_stdlib:map_get(Ctx, Entity_var) of
        {ok, {ref, Eid}} ->
            case gleam_stdlib:map_get(Ranks, Eid) of
                {ok, Rank} ->
                    [gleam@dict:insert(Ctx, Rank_var, {float, Rank})];

                {error, _} ->
                    []
            end;

        {ok, {int, Eid_int}} ->
            Eid@1 = {entity_id, Eid_int},
            case gleam_stdlib:map_get(Ranks, Eid@1) of
                {ok, Rank@1} ->
                    [gleam@dict:insert(Ctx, Rank_var, {float, Rank@1})];

                {error, _} ->
                    []
            end;

        {error, _} ->
            gleam@dict:fold(
                Ranks,
                [],
                fun(Acc, Eid@2, Rank@2) ->
                    New_ctx = gleam@dict:insert(Ctx, Entity_var, {ref, Eid@2}),
                    New_ctx@1 = gleam@dict:insert(
                        New_ctx,
                        Rank_var,
                        {float, Rank@2}
                    ),
                    [New_ctx@1 | Acc]
                end
            );

        _ ->
            []
    end.

-file("src/gleamdb/engine.gleam", 1050).
-spec solve_reachable(
    gleamdb@shared@types:db_state(),
    gleamdb@shared@types:part(),
    binary(),
    binary(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_reachable(Db_state, From, Edge, Node_var, Ctx) ->
    From_eid = resolve_entity_id_from_part(From, Ctx),
    case From_eid of
        {some, Eid} ->
            Nodes = gleamdb@algo@graph:reachable(Db_state, Eid, Edge),
            gleam@list:map(
                Nodes,
                fun(N) -> gleam@dict:insert(Ctx, Node_var, {ref, N}) end
            );

        none ->
            []
    end.

-file("src/gleamdb/engine.gleam", 1069).
-spec solve_connected_components(
    gleamdb@shared@types:db_state(),
    binary(),
    binary(),
    binary(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_connected_components(Db_state, Edge, Entity_var, Component_var, Ctx) ->
    Components = gleamdb@algo@graph:connected_components(Db_state, Edge),
    case gleam_stdlib:map_get(Ctx, Entity_var) of
        {ok, {ref, Eid}} ->
            case gleam_stdlib:map_get(Components, Eid) of
                {ok, Cid} ->
                    [gleam@dict:insert(Ctx, Component_var, {int, Cid})];

                {error, _} ->
                    []
            end;

        {ok, {int, Eid_int}} ->
            Eid@1 = {entity_id, Eid_int},
            case gleam_stdlib:map_get(Components, Eid@1) of
                {ok, Cid@1} ->
                    [gleam@dict:insert(Ctx, Component_var, {int, Cid@1})];

                {error, _} ->
                    []
            end;

        {error, _} ->
            gleam@dict:fold(
                Components,
                [],
                fun(Acc, Eid@2, Cid@2) ->
                    New_ctx = gleam@dict:insert(Ctx, Entity_var, {ref, Eid@2}),
                    New_ctx@1 = gleam@dict:insert(
                        New_ctx,
                        Component_var,
                        {int, Cid@2}
                    ),
                    [New_ctx@1 | Acc]
                end
            );

        _ ->
            []
    end.

-file("src/gleamdb/engine.gleam", 1103).
-spec solve_neighbors(
    gleamdb@shared@types:db_state(),
    gleamdb@shared@types:part(),
    binary(),
    integer(),
    binary(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_neighbors(Db_state, From, Edge, Depth, Node_var, Ctx) ->
    From_eid = resolve_entity_id_from_part(From, Ctx),
    case From_eid of
        {some, Eid} ->
            Nodes = gleamdb@algo@graph:neighbors_khop(
                Db_state,
                Eid,
                Edge,
                Depth
            ),
            gleam@list:map(
                Nodes,
                fun(N) -> gleam@dict:insert(Ctx, Node_var, {ref, N}) end
            );

        none ->
            []
    end.

-file("src/gleamdb/engine.gleam", 1123).
-spec solve_strongly_connected(
    gleamdb@shared@types:db_state(),
    binary(),
    binary(),
    binary(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_strongly_connected(Db_state, Edge, Entity_var, Component_var, Ctx) ->
    Components = gleamdb@algo@graph:strongly_connected_components(
        Db_state,
        Edge
    ),
    case gleam_stdlib:map_get(Ctx, Entity_var) of
        {ok, {ref, Eid}} ->
            case gleam_stdlib:map_get(Components, Eid) of
                {ok, Cid} ->
                    [gleam@dict:insert(Ctx, Component_var, {int, Cid})];

                {error, _} ->
                    []
            end;

        {ok, {int, Eid_int}} ->
            Eid@1 = {entity_id, Eid_int},
            case gleam_stdlib:map_get(Components, Eid@1) of
                {ok, Cid@1} ->
                    [gleam@dict:insert(Ctx, Component_var, {int, Cid@1})];

                {error, _} ->
                    []
            end;

        {error, _} ->
            gleam@dict:fold(
                Components,
                [],
                fun(Acc, Eid@2, Cid@2) ->
                    New_ctx = gleam@dict:insert(Ctx, Entity_var, {ref, Eid@2}),
                    New_ctx@1 = gleam@dict:insert(
                        New_ctx,
                        Component_var,
                        {int, Cid@2}
                    ),
                    [New_ctx@1 | Acc]
                end
            );

        _ ->
            []
    end.

-file("src/gleamdb/engine.gleam", 1156).
-spec solve_cycle_detect(
    gleamdb@shared@types:db_state(),
    binary(),
    binary(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_cycle_detect(Db_state, Edge, Cycle_var, Ctx) ->
    Cycles = gleamdb@algo@graph:cycle_detect(Db_state, Edge),
    gleam@list:map(
        Cycles,
        fun(Cycle) ->
            Cycle_val = {list,
                gleam@list:map(Cycle, fun(Field@0) -> {ref, Field@0} end)},
            gleam@dict:insert(Ctx, Cycle_var, Cycle_val)
        end
    ).

-file("src/gleamdb/engine.gleam", 1169).
-spec solve_betweenness(
    gleamdb@shared@types:db_state(),
    binary(),
    binary(),
    binary(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_betweenness(Db_state, Edge, Entity_var, Score_var, Ctx) ->
    Scores = gleamdb@algo@graph:betweenness_centrality(Db_state, Edge),
    case gleam_stdlib:map_get(Ctx, Entity_var) of
        {ok, {ref, Eid}} ->
            case gleam_stdlib:map_get(Scores, Eid) of
                {ok, Score} ->
                    [gleam@dict:insert(Ctx, Score_var, {float, Score})];

                {error, _} ->
                    []
            end;

        {ok, {int, Eid_int}} ->
            Eid@1 = {entity_id, Eid_int},
            case gleam_stdlib:map_get(Scores, Eid@1) of
                {ok, Score@1} ->
                    [gleam@dict:insert(Ctx, Score_var, {float, Score@1})];

                {error, _} ->
                    []
            end;

        {error, _} ->
            gleam@dict:fold(
                Scores,
                [],
                fun(Acc, Eid@2, Score@2) ->
                    New_ctx = gleam@dict:insert(Ctx, Entity_var, {ref, Eid@2}),
                    New_ctx@1 = gleam@dict:insert(
                        New_ctx,
                        Score_var,
                        {float, Score@2}
                    ),
                    [New_ctx@1 | Acc]
                end
            );

        _ ->
            []
    end.

-file("src/gleamdb/engine.gleam", 1203).
-spec solve_topological_sort(
    gleamdb@shared@types:db_state(),
    binary(),
    binary(),
    binary(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_topological_sort(Db_state, Edge, Entity_var, Order_var, Ctx) ->
    case gleamdb@algo@graph:topological_sort(Db_state, Edge) of
        {ok, Ordered} ->
            gleam@list:index_map(
                Ordered,
                fun(Node, Idx) ->
                    New_ctx = gleam@dict:insert(Ctx, Entity_var, {ref, Node}),
                    gleam@dict:insert(New_ctx, Order_var, {int, Idx})
                end
            );

        {error, _} ->
            []
    end.

-file("src/gleamdb/engine.gleam", 1252).
-spec bind_virtual_outputs(
    gleam@dict:dict(binary(), gleamdb@fact:value()),
    list(binary()),
    list(gleamdb@fact:value())
) -> {ok, gleam@dict:dict(binary(), gleamdb@fact:value())} | {error, nil}.
bind_virtual_outputs(Ctx, Outputs, Row) ->
    case erlang:length(Outputs) =:= erlang:length(Row) of
        true ->
            _pipe = gleam@list:zip(Outputs, Row),
            gleam@list:try_fold(
                _pipe,
                Ctx,
                fun(Acc, Pair) ->
                    {Var, Val} = Pair,
                    case gleam_stdlib:map_get(Acc, Var) of
                        {ok, Existing} ->
                            case Existing =:= Val of
                                true ->
                                    {ok, Acc};

                                false ->
                                    {error, nil}
                            end;

                        {error, _} ->
                            {ok, gleam@dict:insert(Acc, Var, Val)}
                    end
                end
            );

        false ->
            {error, nil}
    end.

-file("src/gleamdb/engine.gleam", 1224).
-spec solve_virtual(
    gleamdb@shared@types:db_state(),
    binary(),
    list(gleamdb@shared@types:part()),
    list(binary()),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_virtual(Db_state, Predicate, Args, Outputs, Ctx) ->
    Resolved_args = gleam@list:try_map(
        Args,
        fun(Arg) -> _pipe = resolve_part_optional(Arg, Ctx),
            gleam@option:to_result(_pipe, nil) end
    ),
    case Resolved_args of
        {ok, Vals} ->
            case gleam_stdlib:map_get(erlang:element(23, Db_state), Predicate) of
                {ok, Adapter} ->
                    Rows = Adapter(Vals),
                    gleam@list:filter_map(
                        Rows,
                        fun(Row) -> bind_virtual_outputs(Ctx, Outputs, Row) end
                    );

                {error, _} ->
                    []
            end;

        {error, _} ->
            []
    end.

-file("src/gleamdb/engine.gleam", 1275).
-spec diff(gleamdb@shared@types:db_state(), integer(), integer()) -> list(gleamdb@fact:datom()).
diff(Db_state, From_tx, To_tx) ->
    _pipe = gleamdb@index:get_all_datoms(erlang:element(3, Db_state)),
    gleam@list:filter(
        _pipe,
        fun(D) ->
            (erlang:element(5, D) > From_tx) andalso (erlang:element(5, D) =< To_tx)
        end
    ).

-file("src/gleamdb/engine.gleam", 1280).
-spec explain(list(gleamdb@shared@types:body_clause())) -> binary().
explain(Clauses) ->
    gleamdb@engine@navigator:explain(Clauses).

-file("src/gleamdb/engine.gleam", 1284).
-spec filter_by_time(
    list(gleamdb@fact:datom()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> list(gleamdb@fact:datom()).
filter_by_time(Datoms, Tx_limit, Valid_limit) ->
    _pipe = Datoms,
    gleam@list:filter(
        _pipe,
        fun(D) ->
            Tx_ok = case Tx_limit of
                {some, Tx} when Tx >= 0 ->
                    erlang:element(5, D) =< Tx;

                {some, Tx@1} ->
                    erlang:element(5, D) >= gleam@int:absolute_value(Tx@1);

                none ->
                    true
            end,
            Valid_ok = case Valid_limit of
                {some, Vt} when Vt >= 0 ->
                    erlang:element(6, D) =< Vt;

                {some, Vt@1} ->
                    erlang:element(6, D) >= gleam@int:absolute_value(Vt@1);

                none ->
                    true
            end,
            Tx_ok andalso Valid_ok
        end
    ).

-file("src/gleamdb/engine.gleam", 276).
-spec solve_positive(
    gleamdb@shared@types:db_state(),
    {gleamdb@shared@types:part(), binary(), gleamdb@shared@types:part()},
    gleam@dict:dict(binary(), gleamdb@fact:value()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_positive(Db_state, Triple, Ctx, As_of_tx, As_of_valid) ->
    {E_p, Attr, V_p} = Triple,
    E_val = resolve_part(E_p, Ctx),
    V_val = resolve_part(V_p, Ctx),
    Base_datoms = case {E_val, V_val} of
        {{some, {ref, {entity_id, E}}}, {some, V}} ->
            gleamdb@index:get_datoms_by_entity_attr_val(
                erlang:element(3, Db_state),
                {entity_id, E},
                Attr,
                V
            );

        {{some, {ref, {entity_id, E@1}}}, none} ->
            gleamdb@index:get_datoms_by_entity_attr(
                erlang:element(3, Db_state),
                {entity_id, E@1},
                Attr
            );

        {{some, {int, E@2}}, {some, V@1}} ->
            gleamdb@index:get_datoms_by_entity_attr_val(
                erlang:element(3, Db_state),
                {entity_id, E@2},
                Attr,
                V@1
            );

        {{some, {int, E@3}}, none} ->
            gleamdb@index:get_datoms_by_entity_attr(
                erlang:element(3, Db_state),
                {entity_id, E@3},
                Attr
            );

        {none, {some, V@2}} ->
            gleamdb@index:get_datoms_by_val(
                erlang:element(4, Db_state),
                Attr,
                V@2
            );

        {none, none} ->
            gleamdb@index:get_all_datoms_for_attr(
                erlang:element(3, Db_state),
                Attr
            );

        {{some, _}, _} ->
            []
    end,
    Active = begin
        _pipe = Base_datoms,
        _pipe@1 = filter_by_time(_pipe, As_of_tx, As_of_valid),
        filter_active(_pipe@1)
    end,
    gleam@list:map(
        Active,
        fun(D) ->
            B = Ctx,
            B@1 = case E_p of
                {var, N} ->
                    Id_val = {ref, erlang:element(2, D)},
                    gleam@dict:insert(B, N, Id_val);

                _ ->
                    B
            end,
            B@2 = case V_p of
                {var, N@1} ->
                    gleam@dict:insert(B@1, N@1, erlang:element(4, D));

                _ ->
                    B@1
            end,
            B@2
        end
    ).

-file("src/gleamdb/engine.gleam", 318).
-spec solve_negative(
    gleamdb@shared@types:db_state(),
    {gleamdb@shared@types:part(), binary(), gleamdb@shared@types:part()},
    gleam@dict:dict(binary(), gleamdb@fact:value()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_negative(Db_state, Triple, Ctx, As_of_tx, As_of_valid) ->
    case solve_positive(Db_state, Triple, Ctx, As_of_tx, As_of_valid) of
        [] ->
            [Ctx];

        _ ->
            []
    end.

-file("src/gleamdb/engine.gleam", 472).
-spec solve_triple_with_derived(
    gleamdb@shared@types:db_state(),
    {gleamdb@shared@types:part(), binary(), gleamdb@shared@types:part()},
    gleam@dict:dict(binary(), gleamdb@fact:value()),
    gleam@set:set(gleamdb@fact:datom()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_triple_with_derived(Db_state, Triple, Ctx, Derived, As_of_tx, As_of_valid) ->
    {E_p, Attr, V_p} = Triple,
    E_val = resolve_part(E_p, Ctx),
    V_val = resolve_part(V_p, Ctx),
    Base_datoms = case {E_val, V_val} of
        {{some, {ref, {entity_id, E}}}, {some, V}} ->
            gleamdb@index:get_datoms_by_entity_attr_val(
                erlang:element(3, Db_state),
                {entity_id, E},
                Attr,
                V
            );

        {{some, {ref, {entity_id, E@1}}}, none} ->
            gleamdb@index:get_datoms_by_entity_attr(
                erlang:element(3, Db_state),
                {entity_id, E@1},
                Attr
            );

        {{some, {int, E@2}}, {some, V@1}} ->
            gleamdb@index:get_datoms_by_entity_attr_val(
                erlang:element(3, Db_state),
                {entity_id, E@2},
                Attr,
                V@1
            );

        {{some, {int, E@3}}, none} ->
            gleamdb@index:get_datoms_by_entity_attr(
                erlang:element(3, Db_state),
                {entity_id, E@3},
                Attr
            );

        {none, {some, V@2}} ->
            gleamdb@index:get_datoms_by_val(
                erlang:element(4, Db_state),
                Attr,
                V@2
            );

        {none, none} ->
            gleamdb@index:get_all_datoms_for_attr(
                erlang:element(3, Db_state),
                Attr
            );

        {{some, _}, _} ->
            []
    end,
    Derived_datoms = begin
        _pipe = gleam@set:to_list(Derived),
        gleam@list:filter(
            _pipe,
            fun(D) ->
                Attr_match = erlang:element(3, D) =:= Attr,
                E_match = case E_val of
                    {some, {ref, {entity_id, E@4}}} ->
                        {entity_id, Eid_int} = erlang:element(2, D),
                        Eid_int =:= E@4;

                    {some, {int, E@5}} ->
                        {entity_id, Eid_int@1} = erlang:element(2, D),
                        Eid_int@1 =:= E@5;

                    _ ->
                        true
                end,
                V_match = case V_val of
                    {some, V@3} ->
                        erlang:element(4, D) =:= V@3;

                    _ ->
                        true
                end,
                (Attr_match andalso E_match) andalso V_match
            end
        )
    end,
    All = lists:append(Base_datoms, Derived_datoms),
    Active = begin
        _pipe@1 = All,
        _pipe@2 = filter_by_time(_pipe@1, As_of_tx, As_of_valid),
        filter_active(_pipe@2)
    end,
    gleam@list:map(
        Active,
        fun(D@1) ->
            B = Ctx,
            B@1 = case E_p of
                {var, N} ->
                    Id_val = {ref, erlang:element(2, D@1)},
                    gleam@dict:insert(B, N, Id_val);

                _ ->
                    B
            end,
            B@2 = case V_p of
                {var, N@1} ->
                    gleam@dict:insert(B@1, N@1, erlang:element(4, D@1));

                _ ->
                    B@1
            end,
            B@2
        end
    ).

-file("src/gleamdb/engine.gleam", 675).
-spec solve_similarity(
    gleamdb@shared@types:db_state(),
    binary(),
    list(float()),
    float(),
    gleam@dict:dict(binary(), gleamdb@fact:value()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_similarity(Db_state, Var, Vec, Threshold, Ctx, As_of_tx, As_of_valid) ->
    case gleam_stdlib:map_get(Ctx, Var) of
        {ok, {vec, V}} ->
            Dist = gleamdb@vector:cosine_similarity(Vec, V),
            case Dist >= Threshold of
                true ->
                    [Ctx];

                false ->
                    []
            end;

        {ok, _} ->
            [];

        {error, nil} ->
            case gleamdb@vec_index:size(erlang:element(16, Db_state)) > 0 of
                true ->
                    Norm_vec = gleamdb@vector:normalize(Vec),
                    Results = gleamdb@vec_index:search(
                        erlang:element(16, Db_state),
                        Norm_vec,
                        Threshold,
                        100
                    ),
                    gleam@list:filter_map(
                        Results,
                        fun(R) ->
                            case gleam_stdlib:map_get(
                                erlang:element(2, erlang:element(16, Db_state)),
                                erlang:element(2, R)
                            ) of
                                {ok, V@1} ->
                                    {ok,
                                        gleam@dict:insert(Ctx, Var, {vec, V@1})};

                                {error, _} ->
                                    {error, nil}
                            end
                        end
                    );

                false ->
                    Matching_datoms = begin
                        _pipe = gleamdb@index:get_all_datoms_avet(
                            erlang:element(5, Db_state)
                        ),
                        _pipe@1 = filter_by_time(_pipe, As_of_tx, As_of_valid),
                        _pipe@2 = filter_active(_pipe@1),
                        gleam@list:filter_map(
                            _pipe@2,
                            fun(D) -> case erlang:element(4, D) of
                                    {vec, V@2} ->
                                        Dist@1 = gleamdb@vector:cosine_similarity(
                                            Vec,
                                            V@2
                                        ),
                                        case Dist@1 >= Threshold of
                                            true ->
                                                {ok, D};

                                            false ->
                                                {error, nil}
                                        end;

                                    _ ->
                                        {error, nil}
                                end end
                        )
                    end,
                    gleam@list:map(
                        Matching_datoms,
                        fun(D@1) ->
                            gleam@dict:insert(
                                Ctx,
                                Var,
                                {ref, erlang:element(2, D@1)}
                            )
                        end
                    )
            end
    end.

-file("src/gleamdb/engine.gleam", 1304).
-spec solve_custom_index(
    gleamdb@shared@types:db_state(),
    binary(),
    binary(),
    gleamdb@shared@types:index_query(),
    float(),
    gleam@dict:dict(binary(), gleamdb@fact:value())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_custom_index(Db_state, Var, Index_name, Query, Threshold, Ctx) ->
    case gleam_stdlib:map_get(erlang:element(20, Db_state), Index_name) of
        {ok, Instance} ->
            case gleam_stdlib:map_get(
                erlang:element(19, Db_state),
                erlang:element(2, Instance)
            ) of
                {ok, Adapter} ->
                    Results = (erlang:element(5, Adapter))(
                        erlang:element(4, Instance),
                        Query,
                        Threshold
                    ),
                    gleam@list:filter_map(
                        Results,
                        fun(Eid) ->
                            Val = {ref, Eid},
                            case gleam_stdlib:map_get(Ctx, Var) of
                                {ok, Existing} when Existing =:= Val ->
                                    {ok, Ctx};

                                {ok, _} ->
                                    {error, nil};

                                {error, nil} ->
                                    {ok, gleam@dict:insert(Ctx, Var, Val)}
                            end
                        end
                    );

                {error, _} ->
                    []
            end;

        {error, _} ->
            []
    end.

-file("src/gleamdb/engine.gleam", 1333).
-spec solve_similarity_entity(
    gleamdb@shared@types:db_state(),
    binary(),
    list(float()),
    float(),
    gleam@dict:dict(binary(), gleamdb@fact:value()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_similarity_entity(Db_state, Var, Vec, Threshold, Ctx, _, _) ->
    case gleamdb@vec_index:size(erlang:element(16, Db_state)) > 0 of
        true ->
            Norm_vec = gleamdb@vector:normalize(Vec),
            Results = gleamdb@vec_index:search(
                erlang:element(16, Db_state),
                Norm_vec,
                Threshold,
                100
            ),
            gleam@list:filter_map(
                Results,
                fun(R) ->
                    Val = {ref, erlang:element(2, R)},
                    case gleam_stdlib:map_get(Ctx, Var) of
                        {ok, Existing} when Existing =:= Val ->
                            {ok, Ctx};

                        {ok, _} ->
                            {error, nil};

                        {error, nil} ->
                            {ok, gleam@dict:insert(Ctx, Var, Val)}
                    end
                end
            );

        false ->
            []
    end.

-file("src/gleamdb/engine.gleam", 233).
-spec solve_clause(
    gleamdb@shared@types:db_state(),
    gleamdb@shared@types:body_clause(),
    gleam@dict:dict(binary(), gleamdb@fact:value()),
    list(gleamdb@shared@types:rule()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_clause(Db_state, Clause, Ctx, Rules, As_of_tx, As_of_valid) ->
    case Clause of
        {positive, C} ->
            solve_positive(Db_state, C, Ctx, As_of_tx, As_of_valid);

        {negative, C@1} ->
            solve_negative(Db_state, C@1, Ctx, As_of_tx, As_of_valid);

        {aggregate, Var, Func, Target, Filter_clauses} ->
            solve_aggregate(
                Ctx,
                Var,
                Func,
                Target,
                Db_state,
                Filter_clauses,
                Rules,
                As_of_tx,
                As_of_valid
            );

        {similarity, Var@1, Vec, Threshold} ->
            solve_similarity(
                Db_state,
                Var@1,
                Vec,
                Threshold,
                Ctx,
                As_of_tx,
                As_of_valid
            );

        {filter, Expr} ->
            case eval_expression(Expr, Ctx) of
                true ->
                    [Ctx];

                false ->
                    []
            end;

        {bind, Var@2, F} ->
            Val = F(Ctx),
            [gleam@dict:insert(Ctx, Var@2, Val)];

        {temporal, Var@3, Entity, Attr, Start, End, Basis} ->
            solve_temporal(
                Db_state,
                Var@3,
                Entity,
                Attr,
                Start,
                End,
                Basis,
                Ctx
            );

        {shortest_path, From, To, Edge, Path_var, Cost_var} ->
            solve_shortest_path(
                Db_state,
                From,
                To,
                Edge,
                Path_var,
                Cost_var,
                Ctx
            );

        {page_rank, Entity_var, Edge@1, Rank_var, D, Iter} ->
            solve_pagerank(Db_state, Entity_var, Edge@1, Rank_var, D, Iter, Ctx);

        {virtual, Pred, Args, Outputs} ->
            solve_virtual(Db_state, Pred, Args, Outputs, Ctx);

        {reachable, From@1, Edge@2, Node_var} ->
            solve_reachable(Db_state, From@1, Edge@2, Node_var, Ctx);

        {connected_components, Edge@3, Entity_var@1, Component_var} ->
            solve_connected_components(
                Db_state,
                Edge@3,
                Entity_var@1,
                Component_var,
                Ctx
            );

        {neighbors, From@2, Edge@4, Depth, Node_var@1} ->
            solve_neighbors(Db_state, From@2, Edge@4, Depth, Node_var@1, Ctx);

        {cycle_detect, Edge@5, Cycle_var} ->
            solve_cycle_detect(Db_state, Edge@5, Cycle_var, Ctx);

        {betweenness_centrality, Edge@6, Entity_var@2, Score_var} ->
            solve_betweenness(Db_state, Edge@6, Entity_var@2, Score_var, Ctx);

        {topological_sort, Edge@7, Entity_var@3, Order_var} ->
            solve_topological_sort(
                Db_state,
                Edge@7,
                Entity_var@3,
                Order_var,
                Ctx
            );

        {strongly_connected_components, Edge@8, Entity_var@4, Component_var@1} ->
            solve_strongly_connected(
                Db_state,
                Edge@8,
                Entity_var@4,
                Component_var@1,
                Ctx
            );

        {starts_with, Var@4, Prefix} ->
            solve_starts_with(Db_state, Var@4, Prefix, Ctx);

        _ ->
            [Ctx]
    end.

-file("src/gleamdb/engine.gleam", 637).
-spec solve_aggregate(
    gleam@dict:dict(binary(), gleamdb@fact:value()),
    binary(),
    gleamdb@shared@types:agg_func(),
    binary(),
    gleamdb@shared@types:db_state(),
    list(gleamdb@shared@types:body_clause()),
    list(gleamdb@shared@types:rule()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_aggregate(
    Ctx,
    Var,
    Func,
    Target_var,
    Db_state,
    Clauses,
    Rules,
    As_of_tx,
    As_of_valid
) ->
    Sub_results = case Clauses of
        [] ->
            [Ctx];

        _ ->
            do_solve_clauses(
                Db_state,
                Clauses,
                Rules,
                As_of_tx,
                As_of_valid,
                [Ctx]
            )
    end,
    Target_values = gleam@list:filter_map(
        Sub_results,
        fun(Res) -> gleam_stdlib:map_get(Res, Target_var) end
    ),
    case gleamdb@algo@aggregate:aggregate(Target_values, Func) of
        {ok, Val} ->
            [gleam@dict:insert(Ctx, Var, Val)];

        {error, _} ->
            []
    end.

-file("src/gleamdb/engine.gleam", 571).
-spec do_solve_clauses(
    gleamdb@shared@types:db_state(),
    list(gleamdb@shared@types:body_clause()),
    list(gleamdb@shared@types:rule()),
    gleam@option:option(integer()),
    gleam@option:option(integer()),
    list(gleam@dict:dict(binary(), gleamdb@fact:value()))
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
do_solve_clauses(Db_state, Clauses, Rules, As_of_tx, As_of_valid, Contexts) ->
    case Clauses of
        [] ->
            Contexts;

        [First | Rest] ->
            Next_contexts = case {erlang:length(Contexts) > 1000, First} of
                {true, {positive, {{var, V}, _, _}}} ->
                    _ = gleam@list:fold(
                        Contexts,
                        gleamdb@index@art:new(),
                        fun(Acc, Ctx) -> case gleam_stdlib:map_get(Ctx, V) of
                                {ok, Val} ->
                                    gleamdb@index@art:insert(
                                        Acc,
                                        Val,
                                        {entity_id, 0}
                                    );

                                {error, nil} ->
                                    Acc
                            end end
                    ),
                    gleam@list:flat_map(
                        Contexts,
                        fun(Ctx@1) ->
                            solve_clause(
                                Db_state,
                                First,
                                Ctx@1,
                                Rules,
                                As_of_tx,
                                As_of_valid
                            )
                        end
                    );

                {true, {positive, {_, _, {var, V}}}} ->
                    _ = gleam@list:fold(
                        Contexts,
                        gleamdb@index@art:new(),
                        fun(Acc, Ctx) -> case gleam_stdlib:map_get(Ctx, V) of
                                {ok, Val} ->
                                    gleamdb@index@art:insert(
                                        Acc,
                                        Val,
                                        {entity_id, 0}
                                    );

                                {error, nil} ->
                                    Acc
                            end end
                    ),
                    gleam@list:flat_map(
                        Contexts,
                        fun(Ctx@1) ->
                            solve_clause(
                                Db_state,
                                First,
                                Ctx@1,
                                Rules,
                                As_of_tx,
                                As_of_valid
                            )
                        end
                    );

                {_, _} ->
                    Is_parallel = erlang:length(Contexts) > erlang:element(
                        2,
                        erlang:element(24, Db_state)
                    ),
                    case Is_parallel of
                        true ->
                            _pipe = Contexts,
                            _pipe@1 = gleam@list:sized_chunk(
                                _pipe,
                                erlang:element(3, erlang:element(24, Db_state))
                            ),
                            _pipe@2 = gleam@list:map(
                                _pipe@1,
                                fun(Chunk) ->
                                    Subject = gleam@erlang@process:new_subject(),
                                    proc_lib:spawn_link(
                                        fun() ->
                                            Result = gleam@list:flat_map(
                                                Chunk,
                                                fun(Ctx@2) ->
                                                    solve_clause(
                                                        Db_state,
                                                        First,
                                                        Ctx@2,
                                                        Rules,
                                                        As_of_tx,
                                                        As_of_valid
                                                    )
                                                end
                                            ),
                                            gleam@erlang@process:send(
                                                Subject,
                                                Result
                                            )
                                        end
                                    ),
                                    Subject
                                end
                            ),
                            gleam@list:flat_map(
                                _pipe@2,
                                fun(Subj) ->
                                    Res@1 = case gleam@erlang@process:'receive'(
                                        Subj,
                                        60000
                                    ) of
                                        {ok, Res} -> Res;
                                        _assert_fail ->
                                            erlang:error(
                                                    #{gleam_error => let_assert,
                                                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                                        file => <<?FILEPATH/utf8>>,
                                                        module => <<"gleamdb/engine"/utf8>>,
                                                        function => <<"do_solve_clauses"/utf8>>,
                                                        line => 620,
                                                        value => _assert_fail,
                                                        start => 22552,
                                                        'end' => 22601,
                                                        pattern_start => 22563,
                                                        pattern_end => 22570}
                                                )
                                    end,
                                    Res@1
                                end
                            );

                        false ->
                            gleam@list:flat_map(
                                Contexts,
                                fun(Ctx@3) ->
                                    solve_clause(
                                        Db_state,
                                        First,
                                        Ctx@3,
                                        Rules,
                                        As_of_tx,
                                        As_of_valid
                                    )
                                end
                            )
                    end
            end,
            do_solve_clauses(
                Db_state,
                Rest,
                Rules,
                As_of_tx,
                As_of_valid,
                Next_contexts
            )
    end.

-file("src/gleamdb/engine.gleam", 331).
-spec solve_clause_with_derived(
    gleamdb@shared@types:db_state(),
    gleamdb@shared@types:body_clause(),
    gleam@dict:dict(binary(), gleamdb@fact:value()),
    gleam@set:set(gleamdb@fact:datom()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_clause_with_derived(Db_state, Clause, Ctx, Derived, As_of_tx, As_of_valid) ->
    case Clause of
        {positive, Trip} ->
            {E_p, Attr, V_p} = Trip,
            E_val = resolve_part(E_p, Ctx),
            V_val = resolve_part(V_p, Ctx),
            Base_datoms = case erlang:element(14, Db_state) of
                {some, Name} ->
                    case {E_val, V_val} of
                        {{some, {ref, {entity_id, E}}}, {some, V}} ->
                            _pipe = gleamdb@index@ets:lookup_datoms(
                                <<Name/binary, "_eavt"/utf8>>,
                                {entity_id, E}
                            ),
                            gleam@list:filter(
                                _pipe,
                                fun(D) ->
                                    (erlang:element(3, D) =:= Attr) andalso (erlang:element(
                                        4,
                                        D
                                    )
                                    =:= V)
                                end
                            );

                        {{some, {ref, {entity_id, E@1}}}, none} ->
                            _pipe@1 = gleamdb@index@ets:lookup_datoms(
                                <<Name/binary, "_eavt"/utf8>>,
                                {entity_id, E@1}
                            ),
                            gleam@list:filter(
                                _pipe@1,
                                fun(D@1) -> erlang:element(3, D@1) =:= Attr end
                            );

                        {{some, {int, E@2}}, {some, V@1}} ->
                            _pipe@2 = gleamdb@index@ets:lookup_datoms(
                                <<Name/binary, "_eavt"/utf8>>,
                                {entity_id, E@2}
                            ),
                            gleam@list:filter(
                                _pipe@2,
                                fun(D@2) ->
                                    (erlang:element(3, D@2) =:= Attr) andalso (erlang:element(
                                        4,
                                        D@2
                                    )
                                    =:= V@1)
                                end
                            );

                        {{some, {int, E@3}}, none} ->
                            _pipe@3 = gleamdb@index@ets:lookup_datoms(
                                <<Name/binary, "_eavt"/utf8>>,
                                {entity_id, E@3}
                            ),
                            gleam@list:filter(
                                _pipe@3,
                                fun(D@3) -> erlang:element(3, D@3) =:= Attr end
                            );

                        {none, {some, V@2}} ->
                            _pipe@4 = gleamdb@index@ets:lookup_datoms(
                                <<Name/binary, "_aevt"/utf8>>,
                                Attr
                            ),
                            gleam@list:filter(
                                _pipe@4,
                                fun(D@4) -> erlang:element(4, D@4) =:= V@2 end
                            );

                        {none, none} ->
                            gleamdb@index@ets:lookup_datoms(
                                <<Name/binary, "_aevt"/utf8>>,
                                Attr
                            );

                        {{some, _}, _} ->
                            []
                    end;

                none ->
                    case {E_val, V_val} of
                        {{some, {ref, {entity_id, E@4}}}, {some, V@3}} ->
                            gleamdb@index:get_datoms_by_entity_attr_val(
                                erlang:element(3, Db_state),
                                {entity_id, E@4},
                                Attr,
                                V@3
                            );

                        {{some, {ref, {entity_id, E@5}}}, none} ->
                            gleamdb@index:get_datoms_by_entity_attr(
                                erlang:element(3, Db_state),
                                {entity_id, E@5},
                                Attr
                            );

                        {{some, {int, E@6}}, {some, V@4}} ->
                            gleamdb@index:get_datoms_by_entity_attr_val(
                                erlang:element(3, Db_state),
                                {entity_id, E@6},
                                Attr,
                                V@4
                            );

                        {{some, {int, E@7}}, none} ->
                            gleamdb@index:get_datoms_by_entity_attr(
                                erlang:element(3, Db_state),
                                {entity_id, E@7},
                                Attr
                            );

                        {none, {some, V@5}} ->
                            gleamdb@index:get_datoms_by_val(
                                erlang:element(4, Db_state),
                                Attr,
                                V@5
                            );

                        {none, none} ->
                            gleamdb@index:get_all_datoms_for_attr(
                                erlang:element(3, Db_state),
                                Attr
                            );

                        {{some, _}, _} ->
                            []
                    end
            end,
            Derived_datoms = begin
                _pipe@5 = gleam@set:to_list(Derived),
                gleam@list:filter(
                    _pipe@5,
                    fun(D@5) ->
                        Attr_match = erlang:element(3, D@5) =:= Attr,
                        E_match = case E_val of
                            {some, {ref, {entity_id, E@8}}} ->
                                {entity_id, Eid_int} = erlang:element(2, D@5),
                                Eid_int =:= E@8;

                            {some, {int, E@9}} ->
                                {entity_id, Eid_int@1} = erlang:element(2, D@5),
                                Eid_int@1 =:= E@9;

                            _ ->
                                true
                        end,
                        V_match = case V_val of
                            {some, V@6} ->
                                erlang:element(4, D@5) =:= V@6;

                            _ ->
                                true
                        end,
                        (Attr_match andalso E_match) andalso V_match
                    end
                )
            end,
            All = lists:append(Base_datoms, Derived_datoms),
            Active = begin
                _pipe@6 = All,
                _pipe@7 = filter_by_time(_pipe@6, As_of_tx, As_of_valid),
                filter_active(_pipe@7)
            end,
            gleam@list:map(
                Active,
                fun(D@6) ->
                    B = Ctx,
                    B@1 = case E_p of
                        {var, N} ->
                            Id_val = {ref, erlang:element(2, D@6)},
                            gleam@dict:insert(B, N, Id_val);

                        _ ->
                            B
                    end,
                    B@2 = case V_p of
                        {var, N@1} ->
                            gleam@dict:insert(B@1, N@1, erlang:element(4, D@6));

                        _ ->
                            B@1
                    end,
                    B@2
                end
            );

        {negative, Trip@1} ->
            case solve_triple_with_derived(
                Db_state,
                Trip@1,
                Ctx,
                Derived,
                As_of_tx,
                As_of_valid
            ) of
                [] ->
                    [Ctx];

                _ ->
                    []
            end;

        {aggregate, Var, Func, Target, Filter_clauses} ->
            solve_aggregate(
                Ctx,
                Var,
                Func,
                Target,
                Db_state,
                Filter_clauses,
                [],
                As_of_tx,
                As_of_valid
            );

        {similarity, Var@1, Vec, Threshold} ->
            solve_similarity(
                Db_state,
                Var@1,
                Vec,
                Threshold,
                Ctx,
                As_of_tx,
                As_of_valid
            );

        {similarity_entity, Var@2, Vec@1, Threshold@1} ->
            solve_similarity_entity(
                Db_state,
                Var@2,
                Vec@1,
                Threshold@1,
                Ctx,
                As_of_tx,
                As_of_valid
            );

        {custom_index, Var@3, Name@1, Q, T} ->
            solve_custom_index(Db_state, Var@3, Name@1, Q, T, Ctx);

        {filter, Expr} ->
            case eval_expression(Expr, Ctx) of
                true ->
                    [Ctx];

                false ->
                    []
            end;

        {bind, Var@4, F} ->
            Val = F(Ctx),
            [gleam@dict:insert(Ctx, Var@4, Val)];

        {temporal, Var@5, Entity, Attr@1, Start, End, Basis} ->
            solve_temporal(
                Db_state,
                Var@5,
                Entity,
                Attr@1,
                Start,
                End,
                Basis,
                Ctx
            );

        {shortest_path, From, To, Edge, Path_var, Cost_var} ->
            solve_shortest_path(
                Db_state,
                From,
                To,
                Edge,
                Path_var,
                Cost_var,
                Ctx
            );

        {page_rank, Entity_var, Edge@1, Rank_var, D@7, Iter} ->
            solve_pagerank(
                Db_state,
                Entity_var,
                Edge@1,
                Rank_var,
                D@7,
                Iter,
                Ctx
            );

        {virtual, Pred, Args, Outputs} ->
            solve_virtual(Db_state, Pred, Args, Outputs, Ctx);

        {reachable, From@1, Edge@2, Node_var} ->
            solve_reachable(Db_state, From@1, Edge@2, Node_var, Ctx);

        {connected_components, Edge@3, Entity_var@1, Component_var} ->
            solve_connected_components(
                Db_state,
                Edge@3,
                Entity_var@1,
                Component_var,
                Ctx
            );

        {neighbors, From@2, Edge@4, Depth, Node_var@1} ->
            solve_neighbors(Db_state, From@2, Edge@4, Depth, Node_var@1, Ctx);

        {cycle_detect, Edge@5, Cycle_var} ->
            solve_cycle_detect(Db_state, Edge@5, Cycle_var, Ctx);

        {betweenness_centrality, Edge@6, Entity_var@2, Score_var} ->
            solve_betweenness(Db_state, Edge@6, Entity_var@2, Score_var, Ctx);

        {topological_sort, Edge@7, Entity_var@3, Order_var} ->
            solve_topological_sort(
                Db_state,
                Edge@7,
                Entity_var@3,
                Order_var,
                Ctx
            );

        {strongly_connected_components, Edge@8, Entity_var@4, Component_var@1} ->
            solve_strongly_connected(
                Db_state,
                Edge@8,
                Entity_var@4,
                Component_var@1,
                Ctx
            );

        {starts_with, Var@6, Prefix} ->
            solve_starts_with(Db_state, Var@6, Prefix, Ctx);

        _ ->
            [Ctx]
    end.

-file("src/gleamdb/engine.gleam", 190).
-spec solve_rule_body_semi_naive(
    gleamdb@shared@types:db_state(),
    list(gleamdb@shared@types:body_clause()),
    gleam@set:set(gleamdb@fact:datom()),
    gleam@set:set(gleamdb@fact:datom()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> list(gleam@dict:dict(binary(), gleamdb@fact:value())).
solve_rule_body_semi_naive(
    Db_state,
    Body,
    All_derived,
    Delta,
    As_of_tx,
    As_of_valid
) ->
    Results = gleam@list:index_map(
        Body,
        fun(Clause_i, I) ->
            Prefix = gleam@list:take(Body, I),
            Suffix = gleam@list:drop(Body, I + 1),
            Ctxs = [maps:new()],
            Ctxs@1 = gleam@list:fold(
                Prefix,
                Ctxs,
                fun(Acc, C) ->
                    gleam@list:flat_map(
                        Acc,
                        fun(Ctx) ->
                            solve_clause_with_derived(
                                Db_state,
                                C,
                                Ctx,
                                All_derived,
                                As_of_tx,
                                As_of_valid
                            )
                        end
                    )
                end
            ),
            Ctxs@2 = gleam@list:flat_map(
                Ctxs@1,
                fun(Ctx@1) ->
                    solve_clause_with_derived(
                        Db_state,
                        Clause_i,
                        Ctx@1,
                        Delta,
                        As_of_tx,
                        As_of_valid
                    )
                end
            ),
            Ctxs@3 = gleam@list:fold(
                Suffix,
                Ctxs@2,
                fun(Acc@1, C@1) ->
                    gleam@list:flat_map(
                        Acc@1,
                        fun(Ctx@2) ->
                            solve_clause_with_derived(
                                Db_state,
                                C@1,
                                Ctx@2,
                                All_derived,
                                As_of_tx,
                                As_of_valid
                            )
                        end
                    )
                end
            ),
            Ctxs@3
        end
    ),
    _pipe = lists:append(Results),
    gleam@list:unique(_pipe).

-file("src/gleamdb/engine.gleam", 138).
-spec do_derive_recursive(
    gleamdb@shared@types:db_state(),
    list(gleamdb@shared@types:rule()),
    gleam@option:option(integer()),
    gleam@option:option(integer()),
    gleam@set:set(gleamdb@fact:datom()),
    gleam@set:set(gleamdb@fact:datom()),
    boolean()
) -> gleam@set:set(gleamdb@fact:datom()).
do_derive_recursive(
    Db_state,
    Rules,
    As_of_tx,
    As_of_valid,
    All_derived,
    Last_new_derived,
    First_run
) ->
    case not First_run andalso (gleam@set:size(Last_new_derived) =:= 0) of
        true ->
            All_derived;

        false ->
            Next_new = gleam@list:fold(
                Rules,
                gleam@set:new(),
                fun(Acc, R) ->
                    Results = solve_rule_body_semi_naive(
                        Db_state,
                        erlang:element(3, R),
                        All_derived,
                        Last_new_derived,
                        As_of_tx,
                        As_of_valid
                    ),
                    gleam@list:fold(
                        Results,
                        Acc,
                        fun(Inner_acc, Ctx) ->
                            E = resolve_part_optional(
                                erlang:element(1, erlang:element(2, R)),
                                Ctx
                            ),
                            V = resolve_part_optional(
                                erlang:element(3, erlang:element(2, R)),
                                Ctx
                            ),
                            case {E, V} of
                                {{some, {ref, {entity_id, Eid_val}}},
                                    {some, Val}} ->
                                    D = {datom,
                                        {entity_id, Eid_val},
                                        erlang:element(2, erlang:element(2, R)),
                                        Val,
                                        0,
                                        0,
                                        assert},
                                    case gleam@set:contains(All_derived, D) of
                                        true ->
                                            Inner_acc;

                                        false ->
                                            gleam@set:insert(Inner_acc, D)
                                    end;

                                {{some, {int, Eid_val@1}}, {some, Val@1}} ->
                                    D@1 = {datom,
                                        {entity_id, Eid_val@1},
                                        erlang:element(2, erlang:element(2, R)),
                                        Val@1,
                                        0,
                                        0,
                                        assert},
                                    case gleam@set:contains(All_derived, D@1) of
                                        true ->
                                            Inner_acc;

                                        false ->
                                            gleam@set:insert(Inner_acc, D@1)
                                    end;

                                {_, _} ->
                                    Inner_acc
                            end
                        end
                    )
                end
            ),
            case gleam@set:size(Next_new) =:= 0 of
                true ->
                    All_derived;

                false ->
                    Next_all = gleam@set:union(All_derived, Next_new),
                    do_derive_recursive(
                        Db_state,
                        Rules,
                        As_of_tx,
                        As_of_valid,
                        Next_all,
                        Next_new,
                        false
                    )
            end
    end.

-file("src/gleamdb/engine.gleam", 127).
-spec do_derive(
    gleamdb@shared@types:db_state(),
    list(gleamdb@shared@types:rule()),
    gleam@option:option(integer()),
    gleam@option:option(integer()),
    gleam@set:set(gleamdb@fact:datom())
) -> gleam@set:set(gleamdb@fact:datom()).
do_derive(Db_state, Rules, As_of_tx, As_of_valid, Derived) ->
    Initial_new = Derived,
    do_derive_recursive(
        Db_state,
        Rules,
        As_of_tx,
        As_of_valid,
        Derived,
        Initial_new,
        true
    ).

-file("src/gleamdb/engine.gleam", 123).
-spec derive_all_facts(
    gleamdb@shared@types:db_state(),
    list(gleamdb@shared@types:rule()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> gleam@set:set(gleamdb@fact:datom()).
derive_all_facts(Db_state, Rules, As_of_tx, As_of_valid) ->
    do_derive(Db_state, Rules, As_of_tx, As_of_valid, gleam@set:new()).

-file("src/gleamdb/engine.gleam", 43).
-spec run(
    gleamdb@shared@types:db_state(),
    list(gleamdb@shared@types:body_clause()),
    list(gleamdb@shared@types:rule()),
    gleam@option:option(integer()),
    gleam@option:option(integer())
) -> gleamdb@shared@types:query_result().
run(Db_state, Clauses, Rules, As_of_tx, As_of_valid) ->
    As_of_v = case As_of_valid of
        {some, Vt} ->
            {some, Vt};

        none ->
            {some, 2147483647}
    end,
    All_rules = lists:append(Rules, erlang:element(22, Db_state)),
    All_derived = derive_all_facts(Db_state, All_rules, As_of_tx, As_of_v),
    Initial_context = [maps:new()],
    Planned_clauses = gleamdb@engine@navigator:plan(Clauses),
    gleam@list:each(Planned_clauses, fun(C) -> case C of
                {page_rank, _, Edge, _, _, _} ->
                    Config = gleam_stdlib:map_get(
                        erlang:element(8, Db_state),
                        Edge
                    ),
                    case Config of
                        {ok, Conf} when erlang:element(5, Conf) =/= many ->
                            _ = io:format(
                                <<<<"⚠️ Warning: Graph edge '"/utf8,
                                        Edge/binary>>/binary,
                                    "' should be Ref(EntityId) for optimal performance."/utf8>>
                            );

                        _ ->
                            nil
                    end;

                {cycle_detect, Edge, _} ->
                    Config = gleam_stdlib:map_get(
                        erlang:element(8, Db_state),
                        Edge
                    ),
                    case Config of
                        {ok, Conf} when erlang:element(5, Conf) =/= many ->
                            _ = io:format(
                                <<<<"⚠️ Warning: Graph edge '"/utf8,
                                        Edge/binary>>/binary,
                                    "' should be Ref(EntityId) for optimal performance."/utf8>>
                            );

                        _ ->
                            nil
                    end;

                {strongly_connected_components, Edge, _, _} ->
                    Config = gleam_stdlib:map_get(
                        erlang:element(8, Db_state),
                        Edge
                    ),
                    case Config of
                        {ok, Conf} when erlang:element(5, Conf) =/= many ->
                            _ = io:format(
                                <<<<"⚠️ Warning: Graph edge '"/utf8,
                                        Edge/binary>>/binary,
                                    "' should be Ref(EntityId) for optimal performance."/utf8>>
                            );

                        _ ->
                            nil
                    end;

                {topological_sort, Edge, _, _} ->
                    Config = gleam_stdlib:map_get(
                        erlang:element(8, Db_state),
                        Edge
                    ),
                    case Config of
                        {ok, Conf} when erlang:element(5, Conf) =/= many ->
                            _ = io:format(
                                <<<<"⚠️ Warning: Graph edge '"/utf8,
                                        Edge/binary>>/binary,
                                    "' should be Ref(EntityId) for optimal performance."/utf8>>
                            );

                        _ ->
                            nil
                    end;

                _ ->
                    nil
            end end),
    Rows = begin
        _pipe@2 = gleam@list:fold(
            Planned_clauses,
            Initial_context,
            fun(Contexts, Clause) -> case Clause of
                    {limit, N} ->
                        gleam@list:take(Contexts, N);

                    {offset, N@1} ->
                        gleam@list:drop(Contexts, N@1);

                    {order_by, Var, Dir} ->
                        gleam@list:sort(
                            Contexts,
                            fun(A, B) ->
                                Val_a = begin
                                    _pipe = gleam_stdlib:map_get(A, Var),
                                    gleam@result:unwrap(_pipe, {int, 0})
                                end,
                                Val_b = begin
                                    _pipe@1 = gleam_stdlib:map_get(B, Var),
                                    gleam@result:unwrap(_pipe@1, {int, 0})
                                end,
                                Ord = compare_values(Val_a, Val_b),
                                case Dir of
                                    asc ->
                                        Ord;

                                    desc ->
                                        case Ord of
                                            lt ->
                                                gt;

                                            gt ->
                                                lt;

                                            eq ->
                                                eq
                                        end
                                end
                            end
                        );

                    {group_by, _} ->
                        Contexts;

                    Normal_clause ->
                        gleam@list:flat_map(
                            Contexts,
                            fun(Ctx) ->
                                solve_clause_with_derived(
                                    Db_state,
                                    Normal_clause,
                                    Ctx,
                                    All_derived,
                                    As_of_tx,
                                    As_of_v
                                )
                            end
                        )
                end end
        ),
        gleam@list:unique(_pipe@2)
    end,
    {query_result, Rows, {query_metadata, As_of_tx, As_of_valid, 0, none}}.
