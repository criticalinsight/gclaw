-record(sharded_db, {
    shards :: gleam@dict:dict(integer(), gleam@erlang@process:subject(gleamdb@transactor:message())),
    shard_count :: integer(),
    cluster_id :: binary()
}).
