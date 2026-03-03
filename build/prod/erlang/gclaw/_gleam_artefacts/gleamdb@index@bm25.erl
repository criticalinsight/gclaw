-module(gleamdb@index@bm25).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleamdb/index/bm25.gleam").
-export([empty/1, add/3, build/2, remove/3, score/5]).
-export_type([b_m25_index/0]).

-type b_m25_index() :: {b_m25_index,
        gleam@dict:dict(binary(), gleam@dict:dict(gleamdb@fact:entity_id(), integer())),
        gleam@dict:dict(binary(), integer()),
        gleam@dict:dict(gleamdb@fact:entity_id(), integer()),
        float(),
        integer(),
        binary()}.

-file("src/gleamdb/index/bm25.gleam", 26).
-spec empty(binary()) -> b_m25_index().
empty(Attribute) ->
    {b_m25_index, maps:new(), maps:new(), maps:new(), +0.0, 0, Attribute}.

-file("src/gleamdb/index/bm25.gleam", 226).
-spec is_alphanumeric(binary()) -> boolean().
is_alphanumeric(Char) ->
    Code = case gleam@string:to_utf_codepoints(Char) of
        [Cp] ->
            gleam_stdlib:identity(Cp);

        _ ->
            0
    end,
    (((Code >= 48) andalso (Code =< 57)) orelse ((Code >= 65) andalso (Code =< 90)))
    orelse ((Code >= 97) andalso (Code =< 122)).

-file("src/gleamdb/index/bm25.gleam", 209).
-spec tokenize(binary()) -> list(binary()).
tokenize(Text) ->
    _pipe = Text,
    _pipe@1 = string:lowercase(_pipe),
    _pipe@2 = gleam@string:to_graphemes(_pipe@1),
    _pipe@3 = gleam@list:map(_pipe@2, fun(Char) -> case is_alphanumeric(Char) of
                true ->
                    Char;

                false ->
                    <<" "/utf8>>
            end end),
    _pipe@4 = erlang:list_to_binary(_pipe@3),
    _pipe@5 = gleam@string:split(_pipe@4, <<" "/utf8>>),
    gleam@list:filter(_pipe@5, fun(S) -> string:length(S) > 0 end).

-file("src/gleamdb/index/bm25.gleam", 59).
-spec add(b_m25_index(), gleamdb@fact:entity_id(), binary()) -> b_m25_index().
add(Index, Entity, Text) ->
    Terms = tokenize(Text),
    Doc_length = erlang:length(Terms),
    Term_counts = gleam@list:fold(
        Terms,
        maps:new(),
        fun(Acc, Term) -> case gleam_stdlib:map_get(Acc, Term) of
                {ok, Count} ->
                    gleam@dict:insert(Acc, Term, Count + 1);

                {error, _} ->
                    gleam@dict:insert(Acc, Term, 1)
            end end
    ),
    {New_tf, New_df} = gleam@dict:fold(
        Term_counts,
        {erlang:element(2, Index), erlang:element(3, Index)},
        fun(Acc@1, Term@1, Count@1) ->
            {Tf_acc, Df_acc} = Acc@1,
            Term_entry = case gleam_stdlib:map_get(Tf_acc, Term@1) of
                {ok, Entry} ->
                    gleam@dict:insert(Entry, Entity, Count@1);

                {error, _} ->
                    maps:from_list([{Entity, Count@1}])
            end,
            New_tf_acc = gleam@dict:insert(Tf_acc, Term@1, Term_entry),
            New_df_acc = case gleam_stdlib:map_get(Df_acc, Term@1) of
                {ok, Df} ->
                    gleam@dict:insert(Df_acc, Term@1, Df + 1);

                {error, _} ->
                    gleam@dict:insert(Df_acc, Term@1, 1)
            end,
            {New_tf_acc, New_df_acc}
        end
    ),
    Old_total_len = erlang:element(5, Index) * erlang:float(
        erlang:element(6, Index)
    ),
    New_count = erlang:element(6, Index) + 1,
    New_avg_len = case erlang:float(New_count) of
        +0.0 -> +0.0;
        -0.0 -> -0.0;
        Gleam@denominator -> (Old_total_len + erlang:float(Doc_length)) / Gleam@denominator
    end,
    {b_m25_index,
        New_tf,
        New_df,
        gleam@dict:insert(erlang:element(4, Index), Entity, Doc_length),
        New_avg_len,
        New_count,
        erlang:element(7, Index)}.

-file("src/gleamdb/index/bm25.gleam", 37).
-spec build(list(gleamdb@fact:datom()), binary()) -> b_m25_index().
build(Datoms, Attribute) ->
    Relevant_datoms = gleam@list:filter(
        Datoms,
        fun(D) -> erlang:element(3, D) =:= Attribute end
    ),
    Index_acc = gleam@list:fold(
        Relevant_datoms,
        empty(Attribute),
        fun(Idx, Datom) -> case erlang:element(4, Datom) of
                {str, Text} ->
                    add(Idx, erlang:element(2, Datom), Text);

                _ ->
                    Idx
            end end
    ),
    Total_len = gleam@dict:fold(
        erlang:element(4, Index_acc),
        0,
        fun(Acc, _, Len) -> Acc + Len end
    ),
    Count = erlang:element(6, Index_acc),
    Avg_len = case Count of
        0 ->
            +0.0;

        _ ->
            case erlang:float(Count) of
                +0.0 -> +0.0;
                -0.0 -> -0.0;
                Gleam@denominator -> erlang:float(Total_len) / Gleam@denominator
            end
    end,
    {b_m25_index,
        erlang:element(2, Index_acc),
        erlang:element(3, Index_acc),
        erlang:element(4, Index_acc),
        Avg_len,
        erlang:element(6, Index_acc),
        erlang:element(7, Index_acc)}.

-file("src/gleamdb/index/bm25.gleam", 112).
-spec remove(b_m25_index(), gleamdb@fact:entity_id(), binary()) -> b_m25_index().
remove(Index, Entity, Text) ->
    Terms = tokenize(Text),
    Doc_length = erlang:length(Terms),
    Term_counts = gleam@list:fold(
        Terms,
        maps:new(),
        fun(Acc, Term) -> case gleam_stdlib:map_get(Acc, Term) of
                {ok, Count} ->
                    gleam@dict:insert(Acc, Term, Count + 1);

                {error, _} ->
                    gleam@dict:insert(Acc, Term, 1)
            end end
    ),
    {New_tf, New_df} = gleam@dict:fold(
        Term_counts,
        {erlang:element(2, Index), erlang:element(3, Index)},
        fun(Acc@1, Term@1, _) ->
            {Tf_acc, Df_acc} = Acc@1,
            New_tf_acc = case gleam_stdlib:map_get(Tf_acc, Term@1) of
                {ok, Entry} ->
                    New_entry = gleam@dict:delete(Entry, Entity),
                    case maps:size(New_entry) of
                        0 ->
                            gleam@dict:delete(Tf_acc, Term@1);

                        _ ->
                            gleam@dict:insert(Tf_acc, Term@1, New_entry)
                    end;

                {error, _} ->
                    Tf_acc
            end,
            New_df_acc = case gleam_stdlib:map_get(Df_acc, Term@1) of
                {ok, Df} when Df > 1 ->
                    gleam@dict:insert(Df_acc, Term@1, Df - 1);

                {ok, _} ->
                    gleam@dict:delete(Df_acc, Term@1);

                {error, _} ->
                    Df_acc
            end,
            {New_tf_acc, New_df_acc}
        end
    ),
    Old_total_len = erlang:element(5, Index) * erlang:float(
        erlang:element(6, Index)
    ),
    New_count = gleam@int:max(0, erlang:element(6, Index) - 1),
    New_avg_len = case New_count of
        0 ->
            +0.0;

        _ ->
            case erlang:float(New_count) of
                +0.0 -> +0.0;
                -0.0 -> -0.0;
                Gleam@denominator -> (Old_total_len - erlang:float(Doc_length))
                / Gleam@denominator
            end
    end,
    {b_m25_index,
        New_tf,
        New_df,
        gleam@dict:delete(erlang:element(4, Index), Entity),
        New_avg_len,
        New_count,
        erlang:element(7, Index)}.

-file("src/gleamdb/index/bm25.gleam", 235).
-spec get_term_freq(b_m25_index(), gleamdb@fact:entity_id(), binary()) -> integer().
get_term_freq(Index, Entity, Term) ->
    case gleam_stdlib:map_get(erlang:element(2, Index), Term) of
        {ok, Entity_map} ->
            case gleam_stdlib:map_get(Entity_map, Entity) of
                {ok, Count} ->
                    Count;

                {error, _} ->
                    0
            end;

        {error, _} ->
            0
    end.

-file("src/gleamdb/index/bm25.gleam", 245).
-spec get_doc_freq(b_m25_index(), binary()) -> integer().
get_doc_freq(Index, Term) ->
    case gleam_stdlib:map_get(erlang:element(3, Index), Term) of
        {ok, Count} ->
            Count;

        {error, _} ->
            0
    end.

-file("src/gleamdb/index/bm25.gleam", 252).
-spec get_doc_len(b_m25_index(), gleamdb@fact:entity_id()) -> integer().
get_doc_len(Index, Entity) ->
    case gleam_stdlib:map_get(erlang:element(4, Index), Entity) of
        {ok, Len} ->
            Len;

        {error, _} ->
            0
    end.

-file("src/gleamdb/index/bm25.gleam", 167).
-spec score(b_m25_index(), gleamdb@fact:entity_id(), binary(), float(), float()) -> float().
score(Index, Entity, Query, K1, B) ->
    Terms = tokenize(Query),
    gleam@list:fold(
        Terms,
        +0.0,
        fun(Acc, Term) ->
            Tf = get_term_freq(Index, Entity, Term),
            Df = get_doc_freq(Index, Term),
            Doc_len = get_doc_len(Index, Entity),
            Idf_numerator = (erlang:float(erlang:element(6, Index)) - erlang:float(
                Df
            ))
            + 0.5,
            Idf_denominator = erlang:float(Df) + 0.5,
            Idf = begin
                _pipe = gleam@float:logarithm(1.0 + (case Idf_denominator of
                        +0.0 -> +0.0;
                        -0.0 -> -0.0;
                        Gleam@denominator -> Idf_numerator / Gleam@denominator
                    end)),
                gleam@result:unwrap(_pipe, +0.0)
            end,
            Safe_idf = gleam@float:max(+0.0, Idf),
            Tf_float = erlang:float(Tf),
            Numerator = Tf_float * (K1 + 1.0),
            Avg_dl_safe = case erlang:element(5, Index) of
                +0.0 ->
                    1.0;

                Val ->
                    Val
            end,
            Denominator = Tf_float + (K1 * ((1.0 - B) + (B * (case Avg_dl_safe of
                +0.0 -> +0.0;
                -0.0 -> -0.0;
                Gleam@denominator@1 -> erlang:float(Doc_len) / Gleam@denominator@1
            end)))),
            case Denominator of
                +0.0 ->
                    Acc;

                _ ->
                    Acc + (Safe_idf * (case Denominator of
                        +0.0 -> +0.0;
                        -0.0 -> -0.0;
                        Gleam@denominator@2 -> Numerator / Gleam@denominator@2
                    end))
            end
        end
    ).
