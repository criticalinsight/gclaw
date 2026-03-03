-module(gleamdb@storage@disk).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/storage/disk.gleam").
-export([disk/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/gleamdb/storage/disk.gleam", 37).
-spec decode_all(bitstring(), list(gleamdb@fact:datom())) -> {ok,
        list(gleamdb@fact:datom())} |
    {error, binary()}.
decode_all(Bits, Acc) ->
    case erlang:byte_size(Bits) =:= 0 of
        true ->
            {ok, lists:reverse(Acc)};

        false ->
            case gleamdb@fact:decode_datom(Bits) of
                {ok, {Datom, Rest}} ->
                    decode_all(Rest, [Datom | Acc]);

                {error, _} ->
                    {error, <<"Failed to decode datom stream"/utf8>>}
            end
    end.

-file("src/gleamdb/storage/disk.gleam", 9).
?DOC(
    " A simple append-only disk storage adapter for GClaw.\n"
    " Rich Hickey: \"Storage should be a durable record of facts.\"\n"
).
-spec disk(binary()) -> gleamdb@storage:storage_adapter().
disk(Path) ->
    {storage_adapter,
        fun() ->
            _ = simplifile:create_file(Path),
            nil
        end,
        fun(D) ->
            Bits = gleamdb@fact:encode_datom(D),
            _ = simplifile_erl:append_bits(Path, Bits),
            nil
        end,
        fun(Ds) ->
            Bits@1 = gleam@list:fold(
                Ds,
                <<>>,
                fun(Acc, D@1) ->
                    gleam@bit_array:append(Acc, gleamdb@fact:encode_datom(D@1))
                end
            ),
            _ = simplifile_erl:append_bits(Path, Bits@1),
            nil
        end,
        fun() -> case simplifile_erl:read_bits(Path) of
                {ok, Bits@2} ->
                    decode_all(Bits@2, []);

                {error, _} ->
                    {ok, []}
            end end}.
