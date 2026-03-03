-module(gleamdb@event).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/event.gleam").
-export([record/4, on_event/3]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/gleamdb/event.gleam", 12).
?DOC(
    " Records a new event into the database.\n"
    " An event is modeled as an entity with a type, timestamp, and optional payload attributes.\n"
).
-spec record(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    binary(),
    integer(),
    list({binary(), gleamdb@fact:value()})
) -> {ok, gleamdb@shared@types:db_state()} | {error, binary()}.
record(Db, Event_type, Timestamp, Payload) ->
    Eid = gleamdb@fact:event_uid(Event_type, Timestamp),
    Event_facts = [{Eid, <<"event/type"/utf8>>, {str, Event_type}},
        {Eid, <<"event/timestamp"/utf8>>, {int, Timestamp}} |
        gleam@list:map(
            Payload,
            fun(P) -> {Eid, erlang:element(1, P), erlang:element(2, P)} end
        )],
    gleamdb@transactor:transact(Db, Event_facts).

-file("src/gleamdb/event.gleam", 76).
-spec process_results(
    gleamdb@shared@types:query_result(),
    gleamdb@shared@types:db_state(),
    fun((gleamdb@shared@types:db_state(), gleamdb@fact:eid()) -> nil)
) -> nil.
process_results(Results, State, Callback) ->
    gleam@list:each(
        erlang:element(2, Results),
        fun(Binding) -> case gleam_stdlib:map_get(Binding, <<"e"/utf8>>) of
                {ok, {ref, Eid}} ->
                    Callback(State, {uid, Eid});

                _ ->
                    nil
            end end
    ).

-file("src/gleamdb/event.gleam", 54).
-spec event_loop(
    gleam@erlang@process:subject(gleamdb@shared@types:reactive_delta()),
    fun((gleamdb@shared@types:db_state(), gleamdb@fact:eid()) -> nil),
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    gleam@erlang@process:subject(gleamdb@shared@types:reactive_delta())
) -> any().
event_loop(Sub, Callback, Db, Proxy) ->
    case gleam_erlang_ffi:'receive'(Sub) of
        {initial, Results} ->
            State = gleamdb@transactor:get_state(Db),
            process_results(Results, State, Callback),
            gleam@erlang@process:send(Proxy, {initial, Results}),
            event_loop(Sub, Callback, Db, Proxy);

        {delta, Added, Removed} ->
            State@1 = gleamdb@transactor:get_state(Db),
            process_results(Added, State@1, Callback),
            gleam@erlang@process:send(Proxy, {delta, Added, Removed}),
            event_loop(Sub, Callback, Db, Proxy)
    end.

-file("src/gleamdb/event.gleam", 31).
?DOC(
    " Convenience function to create an event listener.\n"
    " This subscribes to the database's reactive system for assertions of the specified event type.\n"
).
-spec on_event(
    gleam@erlang@process:subject(gleamdb@transactor:message()),
    binary(),
    fun((gleamdb@shared@types:db_state(), gleamdb@fact:eid()) -> nil)
) -> gleam@erlang@process:subject(gleamdb@shared@types:reactive_delta()).
on_event(Db, Event_type, Callback) ->
    Proxy = gleam@erlang@process:new_subject(),
    proc_lib:spawn_link(
        fun() ->
            Sub = gleam@erlang@process:new_subject(),
            Query = begin
                _pipe = gleamdb@q:new(),
                _pipe@1 = gleamdb@q:where(
                    _pipe,
                    gleamdb@q:v(<<"e"/utf8>>),
                    <<"event/type"/utf8>>,
                    gleamdb@q:s(Event_type)
                ),
                gleamdb@q:to_clauses(_pipe@1)
            end,
            gleamdb:subscribe(Db, Query, Sub),
            event_loop(Sub, Callback, Db, Proxy)
        end
    ),
    Proxy.
