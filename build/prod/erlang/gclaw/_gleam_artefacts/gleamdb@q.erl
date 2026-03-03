-module(gleamdb@q).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/q.gleam").
-export([new/0, select/1, s/1, i/1, v/1, vec/1, where/4, negate/4, count/4, sum/4, avg/4, median/4, min/4, max/4, similar/5, temporal/6, valid_temporal/6, since/3, limit/2, offset/2, order_by/3, group_by/2, shortest_path/5, pagerank/4, virtual/4, reachable/4, connected_components/4, neighbors/5, strongly_connected_components/4, cycle_detect/3, betweenness_centrality/4, topological_sort/4, filter/2, to_clauses/1]).
-export_type([query_builder/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type query_builder() :: {query_builder,
        list(gleamdb@shared@types:body_clause())}.

-file("src/gleamdb/q.gleam", 10).
-spec new() -> query_builder().
new() ->
    {query_builder, []}.

-file("src/gleamdb/q.gleam", 14).
-spec select(list(binary())) -> query_builder().
select(_) ->
    new().

-file("src/gleamdb/q.gleam", 19).
?DOC(" Helper for string value\n").
-spec s(binary()) -> gleamdb@shared@types:part().
s(Val) ->
    {val, {str, Val}}.

-file("src/gleamdb/q.gleam", 24).
?DOC(" Helper for int value\n").
-spec i(integer()) -> gleamdb@shared@types:part().
i(Val) ->
    {val, {int, Val}}.

-file("src/gleamdb/q.gleam", 29).
?DOC(" Helper for variable\n").
-spec v(binary()) -> gleamdb@shared@types:part().
v(Name) ->
    {var, Name}.

-file("src/gleamdb/q.gleam", 34).
?DOC(" Helper for vector value\n").
-spec vec(list(float())) -> gleamdb@shared@types:part().
vec(Val) ->
    {val, {vec, Val}}.

-file("src/gleamdb/q.gleam", 39).
?DOC(" Add a where clause (Entity, Attribute, Value).\n").
-spec where(
    query_builder(),
    gleamdb@shared@types:part(),
    binary(),
    gleamdb@shared@types:part()
) -> query_builder().
where(Builder, Entity, Attr, Value) ->
    Clause = {positive, {Entity, Attr, Value}},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 50).
?DOC(" Add a negative where clause (Entity, Attribute, Value).\n").
-spec negate(
    query_builder(),
    gleamdb@shared@types:part(),
    binary(),
    gleamdb@shared@types:part()
) -> query_builder().
negate(Builder, Entity, Attr, Value) ->
    Clause = {negative, {Entity, Attr, Value}},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 61).
?DOC(" Count aggregate\n").
-spec count(
    query_builder(),
    binary(),
    binary(),
    list(gleamdb@shared@types:body_clause())
) -> query_builder().
count(Builder, Into, Target, Filter) ->
    Clause = {aggregate, Into, count, Target, Filter},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 67).
?DOC(" Sum aggregate\n").
-spec sum(
    query_builder(),
    binary(),
    binary(),
    list(gleamdb@shared@types:body_clause())
) -> query_builder().
sum(Builder, Into, Target, Filter) ->
    Clause = {aggregate, Into, sum, Target, Filter},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 73).
?DOC(" Avg aggregate\n").
-spec avg(
    query_builder(),
    binary(),
    binary(),
    list(gleamdb@shared@types:body_clause())
) -> query_builder().
avg(Builder, Into, Target, Filter) ->
    Clause = {aggregate, Into, avg, Target, Filter},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 79).
?DOC(" Median aggregate\n").
-spec median(
    query_builder(),
    binary(),
    binary(),
    list(gleamdb@shared@types:body_clause())
) -> query_builder().
median(Builder, Into, Target, Filter) ->
    Clause = {aggregate, Into, median, Target, Filter},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 85).
?DOC(" Min aggregate\n").
-spec min(
    query_builder(),
    binary(),
    binary(),
    list(gleamdb@shared@types:body_clause())
) -> query_builder().
min(Builder, Into, Target, Filter) ->
    Clause = {aggregate, Into, min, Target, Filter},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 91).
?DOC(" Max aggregate\n").
-spec max(
    query_builder(),
    binary(),
    binary(),
    list(gleamdb@shared@types:body_clause())
) -> query_builder().
max(Builder, Into, Target, Filter) ->
    Clause = {aggregate, Into, max, Target, Filter},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 97).
?DOC(" Placeholder for similarity search\n").
-spec similar(
    query_builder(),
    gleamdb@shared@types:part(),
    binary(),
    list(float()),
    float()
) -> query_builder().
similar(Builder, Entity, Attr, Vector, _) ->
    Clause = {positive, {Entity, Attr, {val, {vec, Vector}}}},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 109).
?DOC(" Temporal range query (on Transaction Time)\n").
-spec temporal(
    query_builder(),
    binary(),
    gleamdb@shared@types:part(),
    binary(),
    integer(),
    integer()
) -> query_builder().
temporal(Builder, Variable, Entity, Attr, Start, End) ->
    Clause = {temporal, Variable, Entity, Attr, Start, End, tx},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 122).
?DOC(" Temporal range query (on Valid Time)\n").
-spec valid_temporal(
    query_builder(),
    binary(),
    gleamdb@shared@types:part(),
    binary(),
    integer(),
    integer()
) -> query_builder().
valid_temporal(Builder, Variable, Entity, Attr, Start, End) ->
    Clause = {temporal, Variable, Entity, Attr, Start, End, valid},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 135).
?DOC(" Filter results since a specific value (exclusive)\n").
-spec since(query_builder(), binary(), gleamdb@shared@types:part()) -> query_builder().
since(Builder, Variable, Val) ->
    Clause = {filter, {gt, {var, Variable}, Val}},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 141).
?DOC(" Limit results\n").
-spec limit(query_builder(), integer()) -> query_builder().
limit(Builder, N) ->
    Clause = {limit, N},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 147).
?DOC(" Offset results\n").
-spec offset(query_builder(), integer()) -> query_builder().
offset(Builder, N) ->
    Clause = {offset, N},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 153).
?DOC(" Order results\n").
-spec order_by(
    query_builder(),
    binary(),
    gleamdb@shared@types:order_direction()
) -> query_builder().
order_by(Builder, Variable, Direction) ->
    Clause = {order_by, Variable, Direction},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 159).
?DOC(" Group By (Placeholder/Future)\n").
-spec group_by(query_builder(), binary()) -> query_builder().
group_by(Builder, Variable) ->
    Clause = {group_by, Variable},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 165).
?DOC(" Find the shortest path between two entities via an edge attribute.\n").
-spec shortest_path(
    query_builder(),
    gleamdb@shared@types:part(),
    gleamdb@shared@types:part(),
    binary(),
    binary()
) -> query_builder().
shortest_path(Builder, From, To, Edge, Path_var) ->
    Clause = {shortest_path, From, To, Edge, Path_var, none},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 177).
?DOC(" Calculate PageRank for nodes connected by an edge.\n").
-spec pagerank(query_builder(), binary(), binary(), binary()) -> query_builder().
pagerank(Builder, Entity_var, Edge, Rank_var) ->
    Clause = {page_rank, Entity_var, Edge, Rank_var, 0.85, 20},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 188).
?DOC(" Query an external data source (Virtual Predicate).\n").
-spec virtual(
    query_builder(),
    binary(),
    list(gleamdb@shared@types:part()),
    list(binary())
) -> query_builder().
virtual(Builder, Predicate, Args, Outputs) ->
    Clause = {virtual, Predicate, Args, Outputs},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 199).
?DOC(" Find all nodes reachable from a starting node via an edge attribute (transitive closure).\n").
-spec reachable(
    query_builder(),
    gleamdb@shared@types:part(),
    binary(),
    binary()
) -> query_builder().
reachable(Builder, From, Edge, Node_var) ->
    Clause = {reachable, From, Edge, Node_var},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 210).
?DOC(" Label each node with a connected component ID.\n").
-spec connected_components(query_builder(), binary(), binary(), binary()) -> query_builder().
connected_components(Builder, Edge, Entity_var, Component_var) ->
    Clause = {connected_components, Edge, Entity_var, Component_var},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 221).
?DOC(" Find all nodes within K hops of a starting node.\n").
-spec neighbors(
    query_builder(),
    gleamdb@shared@types:part(),
    binary(),
    integer(),
    binary()
) -> query_builder().
neighbors(Builder, From, Edge, Depth, Node_var) ->
    Clause = {neighbors, From, Edge, Depth, Node_var},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 233).
?DOC(" Label each node with its strongly connected component ID (Tarjan's algorithm).\n").
-spec strongly_connected_components(
    query_builder(),
    binary(),
    binary(),
    binary()
) -> query_builder().
strongly_connected_components(Builder, Edge, Entity_var, Component_var) ->
    Clause = {strongly_connected_components, Edge, Entity_var, Component_var},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 244).
?DOC(" Detect cycles in directed graph. Each result binds a List of entity refs forming a cycle.\n").
-spec cycle_detect(query_builder(), binary(), binary()) -> query_builder().
cycle_detect(Builder, Edge, Cycle_var) ->
    Clause = {cycle_detect, Edge, Cycle_var},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 254).
?DOC(" Calculate betweenness centrality (Brandes' algorithm) for each node.\n").
-spec betweenness_centrality(query_builder(), binary(), binary(), binary()) -> query_builder().
betweenness_centrality(Builder, Edge, Entity_var, Score_var) ->
    Clause = {betweenness_centrality, Edge, Entity_var, Score_var},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 265).
?DOC(" Topological ordering of a DAG. Returns empty if cycles exist.\n").
-spec topological_sort(query_builder(), binary(), binary(), binary()) -> query_builder().
topological_sort(Builder, Edge, Entity_var, Order_var) ->
    Clause = {topological_sort, Edge, Entity_var, Order_var},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 276).
?DOC(" Generic filter expression.\n").
-spec filter(query_builder(), gleamdb@shared@types:expression()) -> query_builder().
filter(Builder, Expr) ->
    Clause = {filter, Expr},
    {query_builder, lists:append(erlang:element(2, Builder), [Clause])}.

-file("src/gleamdb/q.gleam", 285).
?DOC(" Convert builder to a list of clauses for `gleamdb.query`.\n").
-spec to_clauses(query_builder()) -> list(gleamdb@shared@types:body_clause()).
to_clauses(Builder) ->
    erlang:element(2, Builder).
