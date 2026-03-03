-module(gleamdb@shared@types).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/shared/types.gleam").
-export([eid_to_integer/1, integer_to_eid/1]).
-export_type([index_adapter/0, extension_instance/0, config/0, db_state/0, index_query/0, part/0, body_clause/0, rule/0, temporal_type/0, order_direction/0, agg_func/0, speculative_result/0, query_metadata/0, query_result/0, reactive_message/0, reactive_delta/0, expression/0]).

-type index_adapter() :: {index_adapter,
        binary(),
        fun((binary()) -> gleam@dynamic:dynamic_()),
        fun((gleam@dynamic:dynamic_(), list(gleamdb@fact:datom())) -> gleam@dynamic:dynamic_()),
        fun((gleam@dynamic:dynamic_(), index_query(), float()) -> list(gleamdb@fact:entity_id()))}.

-type extension_instance() :: {extension_instance,
        binary(),
        binary(),
        gleam@dynamic:dynamic_()}.

-type config() :: {config, integer(), integer()}.

-type db_state() :: {db_state,
        gleamdb@storage:storage_adapter(),
        gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())),
        gleam@dict:dict(binary(), list(gleamdb@fact:datom())),
        gleam@dict:dict(binary(), gleam@dict:dict(gleamdb@fact:value(), gleamdb@fact:entity_id())),
        integer(),
        list(gleam@erlang@process:subject(list(gleamdb@fact:datom()))),
        gleam@dict:dict(binary(), gleamdb@fact:attribute_config()),
        gleam@dict:dict(binary(), fun((db_state(), integer(), integer(), list(gleamdb@fact:value())) -> list({gleamdb@fact:eid(),
            binary(),
            gleamdb@fact:value()}))),
        list(list(binary())),
        gleam@erlang@process:subject(reactive_message()),
        list(gleam@erlang@process:pid_()),
        boolean(),
        gleam@option:option(binary()),
        gleamdb@raft:raft_state(),
        gleamdb@vec_index:vec_index(),
        gleam@dict:dict(binary(), gleamdb@index@bm25:b_m25_index()),
        gleamdb@index@art:art(),
        gleam@dict:dict(binary(), index_adapter()),
        gleam@dict:dict(binary(), extension_instance()),
        gleam@dict:dict(binary(), fun((gleamdb@fact:value()) -> boolean())),
        list(rule()),
        gleam@dict:dict(binary(), fun((list(gleamdb@fact:value())) -> list(list(gleamdb@fact:value())))),
        config()}.

-type index_query() :: {text_query, binary()} |
    {numeric_range, float(), float()} |
    {custom, binary()}.

-type part() :: {var, binary()} | {val, gleamdb@fact:value()}.

-type body_clause() :: {positive, {part(), binary(), part()}} |
    {negative, {part(), binary(), part()}} |
    {filter, expression()} |
    {bind,
        binary(),
        fun((gleam@dict:dict(binary(), gleamdb@fact:value())) -> gleamdb@fact:value())} |
    {aggregate, binary(), agg_func(), binary(), list(body_clause())} |
    {starts_with, binary(), binary()} |
    {similarity, binary(), list(float()), float()} |
    {similarity_entity, binary(), list(float()), float()} |
    {b_m25, binary(), binary(), binary(), float(), float(), float()} |
    {custom_index, binary(), binary(), index_query(), float()} |
    {temporal,
        binary(),
        part(),
        binary(),
        integer(),
        integer(),
        temporal_type()} |
    {limit, integer()} |
    {offset, integer()} |
    {order_by, binary(), order_direction()} |
    {group_by, binary()} |
    {shortest_path,
        part(),
        part(),
        binary(),
        binary(),
        gleam@option:option(binary())} |
    {page_rank, binary(), binary(), binary(), float(), integer()} |
    {virtual, binary(), list(part()), list(binary())} |
    {reachable, part(), binary(), binary()} |
    {connected_components, binary(), binary(), binary()} |
    {neighbors, part(), binary(), integer(), binary()} |
    {cycle_detect, binary(), binary()} |
    {betweenness_centrality, binary(), binary(), binary()} |
    {topological_sort, binary(), binary(), binary()} |
    {strongly_connected_components, binary(), binary(), binary()}.

-type rule() :: {rule, {part(), binary(), part()}, list(body_clause())}.

-type temporal_type() :: tx | valid.

-type order_direction() :: asc | desc.

-type agg_func() :: sum | count | min | max | avg | median.

-type speculative_result() :: {speculative_result,
        db_state(),
        list(gleamdb@fact:datom())}.

-type query_metadata() :: {query_metadata,
        gleam@option:option(integer()),
        gleam@option:option(integer()),
        integer(),
        gleam@option:option(integer())}.

-type query_result() :: {query_result,
        list(gleam@dict:dict(binary(), gleamdb@fact:value())),
        query_metadata()}.

-type reactive_message() :: {subscribe,
        list(body_clause()),
        list(binary()),
        gleam@erlang@process:subject(reactive_delta()),
        query_result()} |
    {notify, list(binary()), db_state()}.

-type reactive_delta() :: {initial, query_result()} |
    {delta, query_result(), query_result()}.

-type expression() :: {eq, part(), part()} |
    {neq, part(), part()} |
    {gt, part(), part()} |
    {lt, part(), part()} |
    {'and', expression(), expression()} |
    {'or', expression(), expression()}.

-file("src/gleamdb/shared/types.gleam", 247).
-spec eid_to_integer(gleamdb@fact:entity_id()) -> integer().
eid_to_integer(Id) ->
    {entity_id, I} = Id,
    I.

-file("src/gleamdb/shared/types.gleam", 252).
-spec integer_to_eid(integer()) -> gleamdb@fact:entity_id().
integer_to_eid(I) ->
    {entity_id, I}.
