-record(shortest_path, {
    from :: gleamdb@shared@types:part(),
    to :: gleamdb@shared@types:part(),
    edge :: binary(),
    path_var :: binary(),
    cost_var :: gleam@option:option(binary())
}).
