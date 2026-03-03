-module(gleamdb@algo@graph).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/algo/graph.gleam").
-export([shortest_path/4, pagerank/4, reachable/3, connected_components/2, neighbors_khop/4, cycle_detect/2, betweenness_centrality/2, topological_sort/2, strongly_connected_components/2]).
-export_type([queue/1, tarjan_state/0]).

-type queue(IYR) :: {queue, list(IYR), list(IYR)}.

-type tarjan_state() :: {tarjan_state,
        integer(),
        gleam@dict:dict(gleamdb@fact:entity_id(), integer()),
        gleam@dict:dict(gleamdb@fact:entity_id(), integer()),
        gleam@set:set(gleamdb@fact:entity_id()),
        list(gleamdb@fact:entity_id()),
        gleam@dict:dict(gleamdb@fact:entity_id(), integer()),
        integer()}.

-file("src/gleamdb/algo/graph.gleam", 16).
-spec new_queue() -> queue(any()).
new_queue() ->
    {queue, [], []}.

-file("src/gleamdb/algo/graph.gleam", 20).
-spec push_queue(queue(IYX), IYX) -> queue(IYX).
push_queue(Q, Item) ->
    {queue, [Item | erlang:element(2, Q)], erlang:element(3, Q)}.

-file("src/gleamdb/algo/graph.gleam", 24).
-spec pop_queue(queue(IZA)) -> {ok, {IZA, queue(IZA)}} | {error, nil}.
pop_queue(Q) ->
    case erlang:element(3, Q) of
        [Head | Tail] ->
            {ok, {Head, {queue, erlang:element(2, Q), Tail}}};

        [] ->
            case lists:reverse(erlang:element(2, Q)) of
                [] ->
                    {error, nil};

                [Head@1 | Tail@1] ->
                    {ok, {Head@1, {queue, [], Tail@1}}}
            end
    end.

-file("src/gleamdb/algo/graph.gleam", 77).
-spec get_neighbors(
    gleamdb@shared@types:db_state(),
    gleamdb@fact:entity_id(),
    binary()
) -> list(gleamdb@fact:entity_id()).
get_neighbors(State, Entity, Attr) ->
    _pipe = gleamdb@index:get_datoms_by_entity_attr(
        erlang:element(3, State),
        Entity,
        Attr
    ),
    gleam@list:filter_map(_pipe, fun(D) -> case erlang:element(4, D) of
                {ref, Id} ->
                    {ok, Id};

                _ ->
                    {error, nil}
            end end).

-file("src/gleamdb/algo/graph.gleam", 88).
-spec reconstruct_path(
    gleamdb@fact:entity_id(),
    gleam@dict:dict(gleamdb@fact:entity_id(), gleamdb@fact:entity_id()),
    list(gleamdb@fact:entity_id())
) -> list(gleamdb@fact:entity_id()).
reconstruct_path(Current, Parents, Acc) ->
    New_acc = [Current | Acc],
    case gleam_stdlib:map_get(Parents, Current) of
        {ok, Parent} ->
            reconstruct_path(Parent, Parents, New_acc);

        {error, _} ->
            New_acc
    end.

-file("src/gleamdb/algo/graph.gleam", 43).
-spec bfs(
    gleamdb@shared@types:db_state(),
    binary(),
    gleamdb@fact:entity_id(),
    queue(gleamdb@fact:entity_id()),
    gleam@set:set(gleamdb@fact:entity_id()),
    gleam@dict:dict(gleamdb@fact:entity_id(), gleamdb@fact:entity_id())
) -> gleam@option:option(list(gleamdb@fact:entity_id())).
bfs(State, Attr, Target, Q, Visited, Parents) ->
    case pop_queue(Q) of
        {error, _} ->
            none;

        {ok, {Current, New_q}} ->
            case Current =:= Target of
                true ->
                    {some, reconstruct_path(Target, Parents, [])};

                false ->
                    Neighbors = get_neighbors(State, Current, Attr),
                    New_neighbors = gleam@list:filter(
                        Neighbors,
                        fun(N) -> not gleam@set:contains(Visited, N) end
                    ),
                    New_visited = gleam@list:fold(
                        New_neighbors,
                        Visited,
                        fun(S, N@1) -> gleam@set:insert(S, N@1) end
                    ),
                    New_parents = gleam@list:fold(
                        New_neighbors,
                        Parents,
                        fun(P, N@2) -> gleam@dict:insert(P, N@2, Current) end
                    ),
                    Next_q = gleam@list:fold(
                        New_neighbors,
                        New_q,
                        fun(Q_acc, N@3) -> push_queue(Q_acc, N@3) end
                    ),
                    bfs(State, Attr, Target, Next_q, New_visited, New_parents)
            end
    end.

-file("src/gleamdb/algo/graph.gleam", 34).
-spec shortest_path(
    gleamdb@shared@types:db_state(),
    gleamdb@fact:entity_id(),
    gleamdb@fact:entity_id(),
    binary()
) -> gleam@option:option(list(gleamdb@fact:entity_id())).
shortest_path(State, From, To, Edge_attr) ->
    bfs(
        State,
        Edge_attr,
        To,
        begin
            _pipe = new_queue(),
            push_queue(_pipe, From)
        end,
        gleam@set:new(),
        maps:new()
    ).

-file("src/gleamdb/algo/graph.gleam", 133).
-spec build_graph(gleamdb@shared@types:db_state(), binary()) -> gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())).
build_graph(State, Attr) ->
    _pipe = gleamdb@index:filter_by_attribute(erlang:element(4, State), Attr),
    gleam@list:fold(
        _pipe,
        maps:new(),
        fun(Graph, D) -> case erlang:element(4, D) of
                {ref, Target} ->
                    Source = erlang:element(2, D),
                    Current_outgoing = begin
                        _pipe@1 = gleam_stdlib:map_get(Graph, Source),
                        gleam@result:unwrap(_pipe@1, [])
                    end,
                    gleam@dict:insert(
                        Graph,
                        Source,
                        [Target | Current_outgoing]
                    );

                _ ->
                    Graph
            end end
    ).

-file("src/gleamdb/algo/graph.gleam", 147).
-spec get_all_nodes(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id()))
) -> gleam@set:set(gleamdb@fact:entity_id()).
get_all_nodes(Graph) ->
    gleam@dict:fold(
        Graph,
        gleam@set:new(),
        fun(Nodes, Source, Targets) ->
            Nodes@1 = gleam@set:insert(Nodes, Source),
            gleam@list:fold(Targets, Nodes@1, fun gleam@set:insert/2)
        end
    ).

-file("src/gleamdb/algo/graph.gleam", 154).
-spec pagerank_iter(
    gleam@set:set(gleamdb@fact:entity_id()),
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    gleam@dict:dict(gleamdb@fact:entity_id(), integer()),
    gleam@dict:dict(gleamdb@fact:entity_id(), float()),
    float(),
    integer(),
    float()
) -> gleam@dict:dict(gleamdb@fact:entity_id(), float()).
pagerank_iter(Nodes, Incoming, Out_degree, Ranks, D, Iter, N) ->
    case Iter of
        0 ->
            Ranks;

        _ ->
            Node_list = gleam@set:to_list(Nodes),
            Next_ranks = gleam@list:fold(
                Node_list,
                maps:new(),
                fun(Acc, U) ->
                    Incoming_nodes = begin
                        _pipe = gleam_stdlib:map_get(Incoming, U),
                        gleam@result:unwrap(_pipe, [])
                    end,
                    Sum = gleam@list:fold(
                        Incoming_nodes,
                        +0.0,
                        fun(S, V) ->
                            Rank_v = begin
                                _pipe@1 = gleam_stdlib:map_get(Ranks, V),
                                gleam@result:unwrap(_pipe@1, +0.0)
                            end,
                            Degree_v = begin
                                _pipe@2 = gleam_stdlib:map_get(Out_degree, V),
                                _pipe@3 = gleam@result:unwrap(_pipe@2, 1),
                                erlang:float(_pipe@3)
                            end,
                            S + (case Degree_v of
                                +0.0 -> +0.0;
                                -0.0 -> -0.0;
                                Gleam@denominator -> Rank_v / Gleam@denominator
                            end)
                        end
                    ),
                    New_rank = (case N of
                        +0.0 -> +0.0;
                        -0.0 -> -0.0;
                        Gleam@denominator@1 -> (1.0 - D) / Gleam@denominator@1
                    end) + (D * Sum),
                    gleam@dict:insert(Acc, U, New_rank)
                end
            ),
            pagerank_iter(
                Nodes,
                Incoming,
                Out_degree,
                Next_ranks,
                D,
                Iter - 1,
                N
            )
    end.

-file("src/gleamdb/algo/graph.gleam", 184).
-spec preprocess_graph(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    gleam@set:set(gleamdb@fact:entity_id())
) -> {gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    gleam@dict:dict(gleamdb@fact:entity_id(), integer())}.
preprocess_graph(Edges, _) ->
    Out_degree = gleam@dict:map_values(
        Edges,
        fun(_, Targets) -> erlang:length(Targets) end
    ),
    Incoming = gleam@dict:fold(
        Edges,
        maps:new(),
        fun(Acc, Source, Targets@1) ->
            gleam@list:fold(
                Targets@1,
                Acc,
                fun(Inner_acc, Target) ->
                    Current = begin
                        _pipe = gleam_stdlib:map_get(Inner_acc, Target),
                        gleam@result:unwrap(_pipe, [])
                    end,
                    gleam@dict:insert(Inner_acc, Target, [Source | Current])
                end
            )
        end
    ),
    {Incoming, Out_degree}.

-file("src/gleamdb/algo/graph.gleam", 100).
-spec pagerank(gleamdb@shared@types:db_state(), binary(), float(), integer()) -> gleam@dict:dict(gleamdb@fact:entity_id(), float()).
pagerank(State, Attr, Damping, Iterations) ->
    Edges = build_graph(State, Attr),
    Nodes = get_all_nodes(Edges),
    N = erlang:float(gleam@set:size(Nodes)),
    Initial_rank = case N of
        +0.0 -> +0.0;
        -0.0 -> -0.0;
        Gleam@denominator -> 1.0 / Gleam@denominator
    end,
    Ranks = gleam@list:fold(
        gleam@set:to_list(Nodes),
        maps:new(),
        fun(Acc, Node) -> gleam@dict:insert(Acc, Node, Initial_rank) end
    ),
    {Incoming, Out_degree} = preprocess_graph(Edges, Nodes),
    pagerank_iter(Nodes, Incoming, Out_degree, Ranks, Damping, Iterations, N).

-file("src/gleamdb/algo/graph.gleam", 206).
-spec reachable_bfs(
    gleamdb@shared@types:db_state(),
    binary(),
    queue(gleamdb@fact:entity_id()),
    gleam@set:set(gleamdb@fact:entity_id())
) -> gleam@set:set(gleamdb@fact:entity_id()).
reachable_bfs(State, Attr, Q, Visited) ->
    case pop_queue(Q) of
        {error, _} ->
            Visited;

        {ok, {Current, New_q}} ->
            Neighbors = get_neighbors(State, Current, Attr),
            New_neighbors = gleam@list:filter(
                Neighbors,
                fun(N) -> not gleam@set:contains(Visited, N) end
            ),
            New_visited = gleam@list:fold(
                New_neighbors,
                Visited,
                fun gleam@set:insert/2
            ),
            Next_q = gleam@list:fold(New_neighbors, New_q, fun push_queue/2),
            reachable_bfs(State, Attr, Next_q, New_visited)
    end.

-file("src/gleamdb/algo/graph.gleam", 197).
-spec reachable(
    gleamdb@shared@types:db_state(),
    gleamdb@fact:entity_id(),
    binary()
) -> list(gleamdb@fact:entity_id()).
reachable(State, From, Edge_attr) ->
    _pipe@1 = reachable_bfs(
        State,
        Edge_attr,
        begin
            _pipe = new_queue(),
            push_queue(_pipe, From)
        end,
        gleam@set:from_list([From])
    ),
    gleam@set:to_list(_pipe@1).

-file("src/gleamdb/algo/graph.gleam", 235).
-spec cc_flood(
    gleamdb@shared@types:db_state(),
    binary(),
    list(gleamdb@fact:entity_id()),
    gleam@set:set(gleamdb@fact:entity_id()),
    gleam@dict:dict(gleamdb@fact:entity_id(), integer()),
    integer()
) -> gleam@dict:dict(gleamdb@fact:entity_id(), integer()).
cc_flood(State, Attr, Remaining, Visited, Labels, Component_id) ->
    case Remaining of
        [] ->
            Labels;

        [Node | Rest] ->
            case gleam@set:contains(Visited, Node) of
                true ->
                    cc_flood(State, Attr, Rest, Visited, Labels, Component_id);

                false ->
                    Component_nodes = reachable(State, Node, Attr),
                    New_visited = gleam@list:fold(
                        Component_nodes,
                        Visited,
                        fun gleam@set:insert/2
                    ),
                    New_labels = gleam@list:fold(
                        Component_nodes,
                        Labels,
                        fun(Acc, N) ->
                            gleam@dict:insert(Acc, N, Component_id)
                        end
                    ),
                    cc_flood(
                        State,
                        Attr,
                        Rest,
                        New_visited,
                        New_labels,
                        Component_id + 1
                    )
            end
    end.

-file("src/gleamdb/algo/graph.gleam", 226).
-spec connected_components(gleamdb@shared@types:db_state(), binary()) -> gleam@dict:dict(gleamdb@fact:entity_id(), integer()).
connected_components(State, Edge_attr) ->
    Graph = build_graph(State, Edge_attr),
    All_nodes = get_all_nodes(Graph),
    cc_flood(
        State,
        Edge_attr,
        gleam@set:to_list(All_nodes),
        gleam@set:new(),
        maps:new(),
        0
    ).

-file("src/gleamdb/algo/graph.gleam", 275).
-spec khop_bfs(
    gleamdb@shared@types:db_state(),
    binary(),
    list({gleamdb@fact:entity_id(), integer()}),
    gleam@set:set(gleamdb@fact:entity_id()),
    integer()
) -> gleam@set:set(gleamdb@fact:entity_id()).
khop_bfs(State, Attr, Frontier, Visited, Max_depth) ->
    case Frontier of
        [] ->
            Visited;

        [{Current, Depth} | Rest] ->
            case Depth >= Max_depth of
                true ->
                    khop_bfs(State, Attr, Rest, Visited, Max_depth);

                false ->
                    Neighbors = get_neighbors(State, Current, Attr),
                    New_neighbors = gleam@list:filter(
                        Neighbors,
                        fun(N) -> not gleam@set:contains(Visited, N) end
                    ),
                    New_visited = gleam@list:fold(
                        New_neighbors,
                        Visited,
                        fun gleam@set:insert/2
                    ),
                    New_frontier = gleam@list:fold(
                        New_neighbors,
                        Rest,
                        fun(Acc, N@1) ->
                            lists:append(Acc, [{N@1, Depth + 1}])
                        end
                    ),
                    khop_bfs(State, Attr, New_frontier, New_visited, Max_depth)
            end
    end.

-file("src/gleamdb/algo/graph.gleam", 264).
-spec neighbors_khop(
    gleamdb@shared@types:db_state(),
    gleamdb@fact:entity_id(),
    binary(),
    integer()
) -> list(gleamdb@fact:entity_id()).
neighbors_khop(State, From, Edge_attr, Max_depth) ->
    _pipe = khop_bfs(
        State,
        Edge_attr,
        [{From, 0}],
        gleam@set:from_list([From]),
        Max_depth
    ),
    _pipe@1 = gleam@set:delete(_pipe, From),
    gleam@set:to_list(_pipe@1).

-file("src/gleamdb/algo/graph.gleam", 377).
-spec extract_cycle_loop(
    list(gleamdb@fact:entity_id()),
    gleamdb@fact:entity_id(),
    list(gleamdb@fact:entity_id())
) -> list(gleamdb@fact:entity_id()).
extract_cycle_loop(Stack, Target, Acc) ->
    case Stack of
        [] ->
            Acc;

        [Head | Tail] ->
            New_acc = [Head | Acc],
            case Head =:= Target of
                true ->
                    New_acc;

                false ->
                    extract_cycle_loop(Tail, Target, New_acc)
            end
    end.

-file("src/gleamdb/algo/graph.gleam", 370).
-spec extract_cycle(list(gleamdb@fact:entity_id()), gleamdb@fact:entity_id()) -> list(gleamdb@fact:entity_id()).
extract_cycle(Stack, Target) ->
    extract_cycle_loop(Stack, Target, []).

-file("src/gleamdb/algo/graph.gleam", 336).
-spec cd_dfs(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    gleamdb@fact:entity_id(),
    gleam@set:set(gleamdb@fact:entity_id()),
    gleam@set:set(gleamdb@fact:entity_id()),
    list(gleamdb@fact:entity_id()),
    list(list(gleamdb@fact:entity_id()))
) -> {gleam@set:set(gleamdb@fact:entity_id()),
    gleam@set:set(gleamdb@fact:entity_id()),
    list(gleamdb@fact:entity_id()),
    list(list(gleamdb@fact:entity_id()))}.
cd_dfs(Graph, Node, Visited, In_stack, Stack, Cycles) ->
    Visited@1 = gleam@set:insert(Visited, Node),
    In_stack@1 = gleam@set:insert(In_stack, Node),
    Neighbors = begin
        _pipe = gleam_stdlib:map_get(Graph, Node),
        gleam@result:unwrap(_pipe, [])
    end,
    {Final_visited, Final_in_stack, Final_stack, Final_cycles} = gleam@list:fold(
        Neighbors,
        {Visited@1, In_stack@1, Stack, Cycles},
        fun(Acc, Neighbor) ->
            {V, Is, S, C} = Acc,
            case gleam@set:contains(Is, Neighbor) of
                true ->
                    Cycle = extract_cycle(S, Neighbor),
                    {V, Is, S, [Cycle | C]};

                false ->
                    case gleam@set:contains(V, Neighbor) of
                        true ->
                            Acc;

                        false ->
                            cd_dfs(Graph, Neighbor, V, Is, [Neighbor | S], C)
                    end
            end
        end
    ),
    Final_in_stack@1 = gleam@set:delete(Final_in_stack, Node),
    {Final_visited, Final_in_stack@1, Final_stack, Final_cycles}.

-file("src/gleamdb/algo/graph.gleam", 313).
-spec cd_search(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    list(gleamdb@fact:entity_id()),
    gleam@set:set(gleamdb@fact:entity_id()),
    gleam@set:set(gleamdb@fact:entity_id()),
    list(gleamdb@fact:entity_id()),
    list(list(gleamdb@fact:entity_id()))
) -> list(list(gleamdb@fact:entity_id())).
cd_search(Graph, Remaining, Visited, In_stack, Stack, Cycles) ->
    case Remaining of
        [] ->
            Cycles;

        [Node | Rest] ->
            case gleam@set:contains(Visited, Node) of
                true ->
                    cd_search(Graph, Rest, Visited, In_stack, Stack, Cycles);

                false ->
                    {New_visited, New_in_stack, _, New_cycles} = cd_dfs(
                        Graph,
                        Node,
                        Visited,
                        In_stack,
                        [Node | Stack],
                        Cycles
                    ),
                    cd_search(
                        Graph,
                        Rest,
                        New_visited,
                        New_in_stack,
                        Stack,
                        New_cycles
                    )
            end
    end.

-file("src/gleamdb/algo/graph.gleam", 303).
-spec cycle_detect(gleamdb@shared@types:db_state(), binary()) -> list(list(gleamdb@fact:entity_id())).
cycle_detect(State, Edge_attr) ->
    Graph = build_graph(State, Edge_attr),
    All_nodes = get_all_nodes(Graph),
    Node_list = gleam@set:to_list(All_nodes),
    cd_search(Graph, Node_list, gleam@set:new(), gleam@set:new(), [], []).

-file("src/gleamdb/algo/graph.gleam", 470).
-spec bc_bfs_loop(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    queue(gleamdb@fact:entity_id()),
    gleam@dict:dict(gleamdb@fact:entity_id(), float()),
    gleam@dict:dict(gleamdb@fact:entity_id(), integer()),
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    list(gleamdb@fact:entity_id())
) -> {list(gleamdb@fact:entity_id()),
    gleam@dict:dict(gleamdb@fact:entity_id(), float()),
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id()))}.
bc_bfs_loop(Graph, Q, Sigma, Dist, Pred, Order) ->
    case pop_queue(Q) of
        {error, _} ->
            {Order, Sigma, Pred};

        {ok, {V, New_q}} ->
            New_order = lists:append(Order, [V]),
            V_dist = begin
                _pipe = gleam_stdlib:map_get(Dist, V),
                gleam@result:unwrap(_pipe, 0)
            end,
            Neighbors = begin
                _pipe@1 = gleam_stdlib:map_get(Graph, V),
                gleam@result:unwrap(_pipe@1, [])
            end,
            {New_q2, New_sigma, New_dist, New_pred} = gleam@list:fold(
                Neighbors,
                {New_q, Sigma, Dist, Pred},
                fun(Acc, W) ->
                    {Q_acc, S_acc, D_acc, P_acc} = Acc,
                    case gleam_stdlib:map_get(D_acc, W) of
                        {error, _} ->
                            D_acc@1 = gleam@dict:insert(D_acc, W, V_dist + 1),
                            Q_acc@1 = push_queue(Q_acc, W),
                            Sv = begin
                                _pipe@2 = gleam_stdlib:map_get(S_acc, V),
                                gleam@result:unwrap(_pipe@2, 1.0)
                            end,
                            S_acc@1 = gleam@dict:insert(S_acc, W, Sv),
                            P_acc@1 = gleam@dict:insert(P_acc, W, [V]),
                            {Q_acc@1, S_acc@1, D_acc@1, P_acc@1};

                        {ok, W_dist} ->
                            case W_dist =:= (V_dist + 1) of
                                true ->
                                    Sw = begin
                                        _pipe@3 = gleam_stdlib:map_get(S_acc, W),
                                        gleam@result:unwrap(_pipe@3, +0.0)
                                    end,
                                    Sv@1 = begin
                                        _pipe@4 = gleam_stdlib:map_get(S_acc, V),
                                        gleam@result:unwrap(_pipe@4, 1.0)
                                    end,
                                    S_acc@2 = gleam@dict:insert(
                                        S_acc,
                                        W,
                                        Sw + Sv@1
                                    ),
                                    Wp = begin
                                        _pipe@5 = gleam_stdlib:map_get(P_acc, W),
                                        gleam@result:unwrap(_pipe@5, [])
                                    end,
                                    P_acc@2 = gleam@dict:insert(
                                        P_acc,
                                        W,
                                        [V | Wp]
                                    ),
                                    {Q_acc, S_acc@2, D_acc, P_acc@2};

                                false ->
                                    Acc
                            end
                    end
                end
            ),
            bc_bfs_loop(Graph, New_q2, New_sigma, New_dist, New_pred, New_order)
    end.

-file("src/gleamdb/algo/graph.gleam", 457).
-spec bc_bfs(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    gleamdb@fact:entity_id()
) -> {list(gleamdb@fact:entity_id()),
    gleam@dict:dict(gleamdb@fact:entity_id(), float()),
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id()))}.
bc_bfs(Graph, Source) ->
    Sigma = maps:from_list([{Source, 1.0}]),
    Dist = maps:from_list([{Source, 0}]),
    Pred = maps:new(),
    Order = [],
    Q = begin
        _pipe = new_queue(),
        push_queue(_pipe, Source)
    end,
    bc_bfs_loop(Graph, Q, Sigma, Dist, Pred, Order).

-file("src/gleamdb/algo/graph.gleam", 415).
-spec bc_from_source(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    gleamdb@fact:entity_id(),
    list(gleamdb@fact:entity_id()),
    gleam@dict:dict(gleamdb@fact:entity_id(), float())
) -> gleam@dict:dict(gleamdb@fact:entity_id(), float()).
bc_from_source(Graph, Source, _, Scores) ->
    {Order, Sigma, Pred} = bc_bfs(Graph, Source),
    Delta = gleam@list:fold(
        Order,
        maps:new(),
        fun(Acc, N) -> gleam@dict:insert(Acc, N, +0.0) end
    ),
    Reversed = lists:reverse(Order),
    Delta@1 = gleam@list:fold(
        Reversed,
        Delta,
        fun(D, W) ->
            Predecessors = begin
                _pipe = gleam_stdlib:map_get(Pred, W),
                gleam@result:unwrap(_pipe, [])
            end,
            Sigma_w = begin
                _pipe@1 = gleam_stdlib:map_get(Sigma, W),
                gleam@result:unwrap(_pipe@1, 1.0)
            end,
            Delta_w = begin
                _pipe@2 = gleam_stdlib:map_get(D, W),
                gleam@result:unwrap(_pipe@2, +0.0)
            end,
            gleam@list:fold(
                Predecessors,
                D,
                fun(D_acc, V) ->
                    Sigma_v = begin
                        _pipe@3 = gleam_stdlib:map_get(Sigma, V),
                        gleam@result:unwrap(_pipe@3, 1.0)
                    end,
                    Delta_v = begin
                        _pipe@4 = gleam_stdlib:map_get(D_acc, V),
                        gleam@result:unwrap(_pipe@4, +0.0)
                    end,
                    Contribution = (case Sigma_w of
                        +0.0 -> +0.0;
                        -0.0 -> -0.0;
                        Gleam@denominator -> Sigma_v / Gleam@denominator
                    end) * (1.0 + Delta_w),
                    gleam@dict:insert(D_acc, V, Delta_v + Contribution)
                end
            )
        end
    ),
    gleam@list:fold(Order, Scores, fun(S, V@1) -> case V@1 =:= Source of
                true ->
                    S;

                false ->
                    Current = begin
                        _pipe@5 = gleam_stdlib:map_get(S, V@1),
                        gleam@result:unwrap(_pipe@5, +0.0)
                    end,
                    D@1 = begin
                        _pipe@6 = gleam_stdlib:map_get(Delta@1, V@1),
                        gleam@result:unwrap(_pipe@6, +0.0)
                    end,
                    gleam@dict:insert(S, V@1, Current + D@1)
            end end).

-file("src/gleamdb/algo/graph.gleam", 396).
-spec betweenness_centrality(gleamdb@shared@types:db_state(), binary()) -> gleam@dict:dict(gleamdb@fact:entity_id(), float()).
betweenness_centrality(State, Edge_attr) ->
    Graph = build_graph(State, Edge_attr),
    All_nodes = get_all_nodes(Graph),
    Node_list = gleam@set:to_list(All_nodes),
    Scores = gleam@list:fold(
        Node_list,
        maps:new(),
        fun(Acc, N) -> gleam@dict:insert(Acc, N, +0.0) end
    ),
    gleam@list:fold(
        Node_list,
        Scores,
        fun(Acc@1, Source) ->
            bc_from_source(Graph, Source, Node_list, Acc@1)
        end
    ).

-file("src/gleamdb/algo/graph.gleam", 553).
-spec topo_kahn(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    queue(gleamdb@fact:entity_id()),
    gleam@dict:dict(gleamdb@fact:entity_id(), integer()),
    list(gleamdb@fact:entity_id()),
    integer()
) -> {ok, list(gleamdb@fact:entity_id())} |
    {error, list(gleamdb@fact:entity_id())}.
topo_kahn(Graph, Q, In_degree, Order, Total) ->
    case pop_queue(Q) of
        {error, _} ->
            case erlang:length(Order) =:= Total of
                true ->
                    {ok, lists:reverse(Order)};

                false ->
                    Cycle_nodes = gleam@dict:fold(
                        In_degree,
                        [],
                        fun(Acc, Node, Deg) -> case Deg > 0 of
                                true ->
                                    [Node | Acc];

                                false ->
                                    Acc
                            end end
                    ),
                    {error, Cycle_nodes}
            end;

        {ok, {Node@1, New_q}} ->
            New_order = [Node@1 | Order],
            Neighbors = begin
                _pipe = gleam_stdlib:map_get(Graph, Node@1),
                gleam@result:unwrap(_pipe, [])
            end,
            {Next_q, Next_in} = gleam@list:fold(
                Neighbors,
                {New_q, In_degree},
                fun(Acc@1, Neighbor) ->
                    {Q_acc, Id_acc} = Acc@1,
                    New_deg = begin
                        _pipe@1 = gleam_stdlib:map_get(Id_acc, Neighbor),
                        gleam@result:unwrap(_pipe@1, 1)
                    end
                    - 1,
                    Id_acc@1 = gleam@dict:insert(Id_acc, Neighbor, New_deg),
                    case New_deg of
                        0 ->
                            {push_queue(Q_acc, Neighbor), Id_acc@1};

                        _ ->
                            {Q_acc, Id_acc@1}
                    end
                end
            ),
            topo_kahn(Graph, Next_q, Next_in, New_order, Total)
    end.

-file("src/gleamdb/algo/graph.gleam", 522).
-spec topological_sort(gleamdb@shared@types:db_state(), binary()) -> {ok,
        list(gleamdb@fact:entity_id())} |
    {error, list(gleamdb@fact:entity_id())}.
topological_sort(State, Edge_attr) ->
    Graph = build_graph(State, Edge_attr),
    All_nodes = get_all_nodes(Graph),
    In_degree = gleam@dict:fold(
        Graph,
        gleam@list:fold(
            gleam@set:to_list(All_nodes),
            maps:new(),
            fun(Acc, N) -> gleam@dict:insert(Acc, N, 0) end
        ),
        fun(Acc@1, _, Targets) ->
            gleam@list:fold(
                Targets,
                Acc@1,
                fun(Inner, Target) ->
                    Current = begin
                        _pipe = gleam_stdlib:map_get(Inner, Target),
                        gleam@result:unwrap(_pipe, 0)
                    end,
                    gleam@dict:insert(Inner, Target, Current + 1)
                end
            )
        end
    ),
    Zero_in = gleam@dict:fold(
        In_degree,
        [],
        fun(Acc@2, Node, Deg) -> case Deg of
                0 ->
                    [Node | Acc@2];

                _ ->
                    Acc@2
            end end
    ),
    Q = gleam@list:fold(Zero_in, new_queue(), fun push_queue/2),
    topo_kahn(Graph, Q, In_degree, [], gleam@set:size(All_nodes)).

-file("src/gleamdb/algo/graph.gleam", 684).
-spec pop_scc(tarjan_state(), gleamdb@fact:entity_id()) -> tarjan_state().
pop_scc(Ts, Root) ->
    case erlang:element(6, Ts) of
        [] ->
            Ts;

        [Top | Rest] ->
            Ts@1 = {tarjan_state,
                erlang:element(2, Ts),
                erlang:element(3, Ts),
                erlang:element(4, Ts),
                gleam@set:delete(erlang:element(5, Ts), Top),
                Rest,
                gleam@dict:insert(
                    erlang:element(7, Ts),
                    Top,
                    erlang:element(8, Ts)
                ),
                erlang:element(8, Ts)},
            case Top =:= Root of
                true ->
                    {tarjan_state,
                        erlang:element(2, Ts@1),
                        erlang:element(3, Ts@1),
                        erlang:element(4, Ts@1),
                        erlang:element(5, Ts@1),
                        erlang:element(6, Ts@1),
                        erlang:element(7, Ts@1),
                        erlang:element(8, Ts@1) + 1};

                false ->
                    pop_scc(Ts@1, Root)
            end
    end.

-file("src/gleamdb/algo/graph.gleam", 636).
-spec tarjan_dfs(
    gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:entity_id())),
    gleamdb@fact:entity_id(),
    tarjan_state()
) -> tarjan_state().
tarjan_dfs(Graph, Node, Ts) ->
    Ts@1 = {tarjan_state,
        erlang:element(2, Ts) + 1,
        gleam@dict:insert(erlang:element(3, Ts), Node, erlang:element(2, Ts)),
        gleam@dict:insert(erlang:element(4, Ts), Node, erlang:element(2, Ts)),
        gleam@set:insert(erlang:element(5, Ts), Node),
        [Node | erlang:element(6, Ts)],
        erlang:element(7, Ts),
        erlang:element(8, Ts)},
    Neighbors = begin
        _pipe = gleam_stdlib:map_get(Graph, Node),
        gleam@result:unwrap(_pipe, [])
    end,
    Ts@4 = gleam@list:fold(
        Neighbors,
        Ts@1,
        fun(Ts@2, W) -> case gleam@dict:has_key(erlang:element(3, Ts@2), W) of
                false ->
                    Ts@3 = tarjan_dfs(Graph, W, Ts@2),
                    Node_low = begin
                        _pipe@1 = gleam_stdlib:map_get(
                            erlang:element(4, Ts@3),
                            Node
                        ),
                        gleam@result:unwrap(_pipe@1, 0)
                    end,
                    W_low = begin
                        _pipe@2 = gleam_stdlib:map_get(
                            erlang:element(4, Ts@3),
                            W
                        ),
                        gleam@result:unwrap(_pipe@2, 0)
                    end,
                    {tarjan_state,
                        erlang:element(2, Ts@3),
                        erlang:element(3, Ts@3),
                        gleam@dict:insert(
                            erlang:element(4, Ts@3),
                            Node,
                            gleam@int:min(Node_low, W_low)
                        ),
                        erlang:element(5, Ts@3),
                        erlang:element(6, Ts@3),
                        erlang:element(7, Ts@3),
                        erlang:element(8, Ts@3)};

                true ->
                    case gleam@set:contains(erlang:element(5, Ts@2), W) of
                        true ->
                            Node_low@1 = begin
                                _pipe@3 = gleam_stdlib:map_get(
                                    erlang:element(4, Ts@2),
                                    Node
                                ),
                                gleam@result:unwrap(_pipe@3, 0)
                            end,
                            W_idx = begin
                                _pipe@4 = gleam_stdlib:map_get(
                                    erlang:element(3, Ts@2),
                                    W
                                ),
                                gleam@result:unwrap(_pipe@4, 0)
                            end,
                            {tarjan_state,
                                erlang:element(2, Ts@2),
                                erlang:element(3, Ts@2),
                                gleam@dict:insert(
                                    erlang:element(4, Ts@2),
                                    Node,
                                    gleam@int:min(Node_low@1, W_idx)
                                ),
                                erlang:element(5, Ts@2),
                                erlang:element(6, Ts@2),
                                erlang:element(7, Ts@2),
                                erlang:element(8, Ts@2)};

                        false ->
                            Ts@2
                    end
            end end
    ),
    Node_low@2 = begin
        _pipe@5 = gleam_stdlib:map_get(erlang:element(4, Ts@4), Node),
        gleam@result:unwrap(_pipe@5, 0)
    end,
    Node_idx = begin
        _pipe@6 = gleam_stdlib:map_get(erlang:element(3, Ts@4), Node),
        gleam@result:unwrap(_pipe@6, -1)
    end,
    case Node_low@2 =:= Node_idx of
        true ->
            pop_scc(Ts@4, Node);

        false ->
            Ts@4
    end.

-file("src/gleamdb/algo/graph.gleam", 609).
-spec strongly_connected_components(gleamdb@shared@types:db_state(), binary()) -> gleam@dict:dict(gleamdb@fact:entity_id(), integer()).
strongly_connected_components(State, Edge_attr) ->
    Graph = build_graph(State, Edge_attr),
    All_nodes = get_all_nodes(Graph),
    Ts = {tarjan_state,
        0,
        maps:new(),
        maps:new(),
        gleam@set:new(),
        [],
        maps:new(),
        0},
    Final_ts = gleam@set:fold(
        All_nodes,
        Ts,
        fun(Ts@1, Node) ->
            case gleam@dict:has_key(erlang:element(3, Ts@1), Node) of
                true ->
                    Ts@1;

                false ->
                    tarjan_dfs(Graph, Node, Ts@1)
            end
        end
    ),
    erlang:element(7, Final_ts).
