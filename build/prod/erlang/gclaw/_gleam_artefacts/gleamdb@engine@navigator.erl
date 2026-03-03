-module(gleamdb@engine@navigator).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/engine/navigator.gleam").
-export([plan/1, explain/1]).

-file("src/gleamdb/engine/navigator.gleam", 23).
-spec is_control_clause(gleamdb@shared@types:body_clause()) -> boolean().
is_control_clause(Clause) ->
    case Clause of
        {limit, _} ->
            true;

        {offset, _} ->
            true;

        {order_by, _, _} ->
            true;

        {group_by, _} ->
            true;

        _ ->
            false
    end.

-file("src/gleamdb/engine/navigator.gleam", 93).
-spec is_part_bound(gleamdb@shared@types:part(), gleam@set:set(binary())) -> boolean().
is_part_bound(Part, Bound_vars) ->
    case Part of
        {val, _} ->
            true;

        {var, Name} ->
            gleam@set:contains(Bound_vars, Name)
    end.

-file("src/gleamdb/engine/navigator.gleam", 135).
-spec get_var_name(gleamdb@shared@types:part()) -> {ok, binary()} | {error, nil}.
get_var_name(Part) ->
    case Part of
        {var, Name} ->
            {ok, Name};

        _ ->
            {error, nil}
    end.

-file("src/gleamdb/engine/navigator.gleam", 142).
-spec get_expr_vars(gleamdb@shared@types:expression()) -> gleam@set:set(binary()).
get_expr_vars(Expr) ->
    case Expr of
        {eq, A, B} ->
            gleam@set:from_list(
                gleam@list:filter_map([A, B], fun get_var_name/1)
            );

        {neq, A, B} ->
            gleam@set:from_list(
                gleam@list:filter_map([A, B], fun get_var_name/1)
            );

        {gt, A, B} ->
            gleam@set:from_list(
                gleam@list:filter_map([A, B], fun get_var_name/1)
            );

        {lt, A, B} ->
            gleam@set:from_list(
                gleam@list:filter_map([A, B], fun get_var_name/1)
            );

        {'and', L, R} ->
            gleam@set:union(get_expr_vars(L), get_expr_vars(R));

        {'or', L, R} ->
            gleam@set:union(get_expr_vars(L), get_expr_vars(R))
    end.

-file("src/gleamdb/engine/navigator.gleam", 52).
-spec estimate_cost(gleamdb@shared@types:body_clause(), gleam@set:set(binary())) -> integer().
estimate_cost(Clause, Bound_vars) ->
    case Clause of
        {positive, {E, _, V}} ->
            E_bound = is_part_bound(E, Bound_vars),
            V_bound = is_part_bound(V, Bound_vars),
            case {E_bound, V_bound} of
                {true, true} ->
                    1;

                {true, false} ->
                    10;

                {false, true} ->
                    100;

                {false, false} ->
                    1000
            end;

        {negative, _} ->
            5000;

        {filter, Expr} ->
            Expr_vars = get_expr_vars(Expr),
            All_bound = gleam@set:fold(
                Expr_vars,
                true,
                fun(Acc, V@1) ->
                    Acc andalso gleam@set:contains(Bound_vars, V@1)
                end
            ),
            case All_bound of
                true ->
                    2;

                false ->
                    8000
            end;

        {bind, _, _} ->
            2;

        {aggregate, _, _, _, Sub_filter} ->
            2000 + (erlang:length(Sub_filter) * 100);

        {similarity, _, _, _} ->
            50;

        {temporal, _, _, _, _, _, _} ->
            150;

        {shortest_path, _, _, _, _, _} ->
            500;

        {page_rank, _, _, _, _, _} ->
            1000;

        {starts_with, Var, _} ->
            case gleam@set:contains(Bound_vars, Var) of
                true ->
                    10;

                false ->
                    50
            end;

        {virtual, _, Args, _} ->
            Bound_args = gleam@list:filter(
                Args,
                fun(A) -> is_part_bound(A, Bound_vars) end
            ),
            1000 - (erlang:length(Bound_args) * 100);

        _ ->
            9999
    end.

-file("src/gleamdb/engine/navigator.gleam", 42).
-spec find_best_clause(
    list(gleamdb@shared@types:body_clause()),
    gleam@set:set(binary())
) -> {gleamdb@shared@types:body_clause(),
    list(gleamdb@shared@types:body_clause())}.
find_best_clause(Clauses, Bound_vars) ->
    Scored = gleam@list:map(
        Clauses,
        fun(C) -> {C, estimate_cost(C, Bound_vars)} end
    ),
    Sorted = gleam@list:sort(
        Scored,
        fun(A, B) ->
            gleam@int:compare(erlang:element(2, A), erlang:element(2, B))
        end
    ),
    case Sorted of
        [{Best, _} | Rest] ->
            {Best,
                gleam@list:map(Rest, fun(Pair) -> erlang:element(1, Pair) end)};

        _ ->
            erlang:error(#{gleam_error => panic,
                    message => <<"Empty clause list in find_best_clause"/utf8>>,
                    file => <<?FILEPATH/utf8>>,
                    module => <<"gleamdb/engine/navigator"/utf8>>,
                    function => <<"find_best_clause"/utf8>>,
                    line => 48})
    end.

-file("src/gleamdb/engine/navigator.gleam", 100).
-spec get_clause_vars(gleamdb@shared@types:body_clause()) -> gleam@set:set(binary()).
get_clause_vars(Clause) ->
    case Clause of
        {positive, {E, _, V}} ->
            gleam@set:from_list(
                gleam@list:filter_map([E, V], fun get_var_name/1)
            );

        {negative, {E@1, _, V@1}} ->
            gleam@set:from_list(
                gleam@list:filter_map([E@1, V@1], fun get_var_name/1)
            );

        {filter, Expr} ->
            get_expr_vars(Expr);

        {bind, Var, _} ->
            gleam@set:from_list([Var]);

        {aggregate, Var@1, _, Target, Filter} ->
            Sub_vars = begin
                _pipe = gleam@list:map(Filter, fun get_clause_vars/1),
                gleam@list:fold(_pipe, gleam@set:new(), fun gleam@set:union/2)
            end,
            gleam@set:insert(gleam@set:insert(Sub_vars, Var@1), Target);

        {starts_with, Var@2, _} ->
            gleam@set:from_list([Var@2]);

        {similarity, Var@3, _, _} ->
            gleam@set:from_list([Var@3]);

        {temporal, Var@4, Entity, _, _, _, _} ->
            S = gleam@set:from_list([Var@4]),
            case get_var_name(Entity) of
                {ok, Name} ->
                    gleam@set:insert(S, Name);

                {error, _} ->
                    S
            end;

        {shortest_path, From, To, _, Path_var, Cost_var} ->
            S@1 = gleam@set:from_list([Path_var]),
            S@2 = case Cost_var of
                {some, Cv} ->
                    gleam@set:insert(S@1, Cv);

                none ->
                    S@1
            end,
            S@3 = case get_var_name(From) of
                {ok, N} ->
                    gleam@set:insert(S@2, N);

                {error, _} ->
                    S@2
            end,
            case get_var_name(To) of
                {ok, N@1} ->
                    gleam@set:insert(S@3, N@1);

                {error, _} ->
                    S@3
            end;

        {page_rank, Entity_var, _, Rank_var, _, _} ->
            gleam@set:from_list([Entity_var, Rank_var]);

        {virtual, _, Args, Outputs} ->
            Arg_vars = begin
                _pipe@1 = gleam@list:filter_map(Args, fun get_var_name/1),
                gleam@set:from_list(_pipe@1)
            end,
            Output_vars = gleam@set:from_list(Outputs),
            gleam@set:union(Arg_vars, Output_vars);

        _ ->
            gleam@set:new()
    end.

-file("src/gleamdb/engine/navigator.gleam", 30).
-spec greedy_reorder(
    list(gleamdb@shared@types:body_clause()),
    gleam@set:set(binary())
) -> list(gleamdb@shared@types:body_clause()).
greedy_reorder(Remaining, Bound_vars) ->
    case Remaining of
        [] ->
            [];

        _ ->
            {Best, Others} = find_best_clause(Remaining, Bound_vars),
            Clause_vars = get_clause_vars(Best),
            Next_bound = gleam@set:union(Bound_vars, Clause_vars),
            [Best | greedy_reorder(Others, Next_bound)]
    end.

-file("src/gleamdb/engine/navigator.gleam", 9).
-spec plan(list(gleamdb@shared@types:body_clause())) -> list(gleamdb@shared@types:body_clause()).
plan(Clauses) ->
    {Control, Data} = gleam@list:partition(Clauses, fun is_control_clause/1),
    Ordered_data = greedy_reorder(Data, gleam@set:new()),
    lists:append(Ordered_data, Control).

-file("src/gleamdb/engine/navigator.gleam", 168).
-spec part_to_string(gleamdb@shared@types:part()) -> binary().
part_to_string(P) ->
    case P of
        {var, N} ->
            <<"?"/utf8, N/binary>>;

        {val, V} ->
            gleamdb@fact:to_string(V)
    end.

-file("src/gleamdb/engine/navigator.gleam", 151).
-spec clause_to_string(gleamdb@shared@types:body_clause()) -> binary().
clause_to_string(Clause) ->
    case Clause of
        {positive, {E, A, V}} ->
            <<<<<<<<<<<<"Positive("/utf8, (part_to_string(E))/binary>>/binary,
                                ", "/utf8>>/binary,
                            A/binary>>/binary,
                        ", "/utf8>>/binary,
                    (part_to_string(V))/binary>>/binary,
                ")"/utf8>>;

        {negative, {E@1, A@1, V@1}} ->
            <<<<<<<<<<<<"Negative("/utf8, (part_to_string(E@1))/binary>>/binary,
                                ", "/utf8>>/binary,
                            A@1/binary>>/binary,
                        ", "/utf8>>/binary,
                    (part_to_string(V@1))/binary>>/binary,
                ")"/utf8>>;

        {filter, _} ->
            <<"Filter(...)"/utf8>>;

        {similarity, V@2, _, _} ->
            <<<<"Similarity("/utf8, V@2/binary>>/binary, ")"/utf8>>;

        {temporal, V@3, E@2, A@2, _, _, _} ->
            <<<<<<<<<<<<"Temporal("/utf8, V@3/binary>>/binary, ", "/utf8>>/binary,
                            (part_to_string(E@2))/binary>>/binary,
                        ", "/utf8>>/binary,
                    A@2/binary>>/binary,
                ")"/utf8>>;

        {limit, N} ->
            <<<<"Limit("/utf8, (erlang:integer_to_binary(N))/binary>>/binary,
                ")"/utf8>>;

        {order_by, V@4, _} ->
            <<<<"OrderBy("/utf8, V@4/binary>>/binary, ")"/utf8>>;

        {virtual, P, Args, Outputs} ->
            <<<<<<<<<<<<"Virtual("/utf8, P/binary>>/binary, ", count="/utf8>>/binary,
                            (erlang:integer_to_binary(erlang:length(Args)))/binary>>/binary,
                        ", outputs="/utf8>>/binary,
                    (gleam@string:inspect(Outputs))/binary>>/binary,
                ")"/utf8>>;

        {shortest_path, _, _, E@3, V@5, _} ->
            <<<<<<<<"ShortestPath(edge="/utf8, E@3/binary>>/binary,
                        ", var="/utf8>>/binary,
                    V@5/binary>>/binary,
                ")"/utf8>>;

        {page_rank, _, E@4, V@6, _, _} ->
            <<<<<<<<"PageRank(edge="/utf8, E@4/binary>>/binary, ", var="/utf8>>/binary,
                    V@6/binary>>/binary,
                ")"/utf8>>;

        _ ->
            <<"OtherClause"/utf8>>
    end.

-file("src/gleamdb/engine/navigator.gleam", 15).
-spec explain(list(gleamdb@shared@types:body_clause())) -> binary().
explain(Clauses) ->
    Planned = plan(Clauses),
    _pipe = gleam@list:map(
        Planned,
        fun(C) -> <<"  - "/utf8, (clause_to_string(C))/binary>> end
    ),
    _pipe@1 = gleam@list:prepend(_pipe, <<"Query Plan:"/utf8>>),
    _pipe@2 = gleam@list:intersperse(_pipe@1, <<"\n"/utf8>>),
    gleam@list:fold(
        _pipe@2,
        <<""/utf8>>,
        fun(Acc, S) -> <<Acc/binary, S/binary>> end
    ).
