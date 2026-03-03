-record(hybrid_index, {
    hot :: gleam@dict:dict(gleamdb@fact:entity_id(), list(gleamdb@fact:datom())),
    cold :: list(bitstring()),
    capacity :: integer()
}).
