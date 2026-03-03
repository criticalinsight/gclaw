-record(datom, {
    entity :: gleamdb@fact:entity_id(),
    attribute :: binary(),
    value :: gleamdb@fact:value(),
    tx :: integer(),
    valid_time :: integer(),
    operation :: gleamdb@fact:operation()
}).
