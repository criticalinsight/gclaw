-record(temporal, {
    variable :: binary(),
    entity :: gleamdb@shared@types:part(),
    attribute :: binary(),
    start :: integer(),
    'end' :: integer(),
    basis :: gleamdb@shared@types:temporal_type()
}).
