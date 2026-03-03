-record(query_result, {
    rows :: list(gleam@dict:dict(binary(), gleamdb@fact:value())),
    metadata :: gleamdb@shared@types:query_metadata()
}).
