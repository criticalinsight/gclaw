-record(vec_index, {
    nodes :: gleam@dict:dict(gleamdb@fact:entity_id(), list(float())),
    layers :: gleam@dict:dict(integer(), gleamdb@vec_index:layer()),
    max_neighbors :: integer(),
    entry_point :: {ok, gleamdb@fact:entity_id()} | {error, nil},
    max_level :: integer()
}).
