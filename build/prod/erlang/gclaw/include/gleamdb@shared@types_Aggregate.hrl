-record(aggregate, {
    variable :: binary(),
    function :: gleamdb@shared@types:agg_func(),
    target :: binary(),
    filter :: list(gleamdb@shared@types:body_clause())
}).
