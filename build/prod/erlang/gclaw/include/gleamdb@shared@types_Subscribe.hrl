-record(subscribe, {
    'query' :: list(gleamdb@shared@types:body_clause()),
    attributes :: list(binary()),
    subscriber :: gleam@erlang@process:subject(gleamdb@shared@types:reactive_delta()),
    initial_state :: gleamdb@shared@types:query_result()
}).
