-record(attribute_config, {
    unique :: boolean(),
    component :: boolean(),
    retention :: gleamdb@fact:retention(),
    cardinality :: gleamdb@fact:cardinality(),
    check :: gleam@option:option(binary())
}).
