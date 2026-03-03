-record(notify, {
    changed_attributes :: list(binary()),
    current_state :: gleamdb@shared@types:db_state()
}).
