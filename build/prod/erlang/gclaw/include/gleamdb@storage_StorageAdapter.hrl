-record(storage_adapter, {
    init :: fun(() -> nil),
    persist :: fun((gleamdb@fact:datom()) -> nil),
    persist_batch :: fun((list(gleamdb@fact:datom())) -> nil),
    recover :: fun(() -> {ok, list(gleamdb@fact:datom())} | {error, binary()})
}).
