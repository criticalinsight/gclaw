-record(query_metadata, {
    tx_id :: gleam@option:option(integer()),
    valid_time :: gleam@option:option(integer()),
    execution_time_ms :: integer(),
    shard_id :: gleam@option:option(integer())
}).
