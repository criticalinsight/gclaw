-record(node, {
    prefix :: bitstring(),
    children :: gleam@dict:dict(integer(), gleamdb@index@art:node_()),
    values :: list(gleamdb@fact:entity_id())
}).
