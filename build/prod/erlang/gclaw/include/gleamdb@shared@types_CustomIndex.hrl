-record(custom_index, {
    variable :: binary(),
    index_name :: binary(),
    'query' :: gleamdb@shared@types:index_query(),
    threshold :: float()
}).
