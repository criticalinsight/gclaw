-record(index_adapter, {
    name :: binary(),
    create :: fun((binary()) -> gleam@dynamic:dynamic_()),
    update :: fun((gleam@dynamic:dynamic_(), list(gleamdb@fact:datom())) -> gleam@dynamic:dynamic_()),
    search :: fun((gleam@dynamic:dynamic_(), gleamdb@shared@types:index_query(), float()) -> list(gleamdb@fact:entity_id()))
}).
