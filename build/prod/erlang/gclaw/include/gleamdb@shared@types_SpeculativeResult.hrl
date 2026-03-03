-record(speculative_result, {
    state :: gleamdb@shared@types:db_state(),
    datoms :: list(gleamdb@fact:datom())
}).
