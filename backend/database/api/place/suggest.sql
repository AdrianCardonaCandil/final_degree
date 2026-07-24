/*
 * @file    ./database/api/place/suggest.sql
 * @author  Adrián Cardona Candil
 * @brief   Autocomplete (Suggest) endpoint for the place table. Implements the "Suggest" phase of a
 *          Suggest/Retrieve-type search engine on the "places.place" table. Given free-text input from
 *          the user, it returns a shortlist of candidate points of interest sorted by relevance, with
 *          response times of ~100-200 ms. The list of final candidates is calculated using a strategy
 *          that includes indexed filtering (@@) with an intermediate threshold and reordering of the
 *          filtered set based on a hybrid score (lexical + fuzzy).
 *
 * @params
 *   query [text]: Free-text input from the user.
 *   limit_results [integer]: Maximum number of candidate places to return.
 *
 * @return [table]
 *   Returns a table with the following columns:
 *     • id [text]: Unique identifier of the place.
 *     • name [text]: Name of the point of interest.
 *     • images [jsonb]: Images associated with the point of interest.
 *     • taxonomy [jsonb]: Category/taxonomy classification of the point of interest.
 *     • address [jsonb]: Address structure of the place (freeform, postcode, hierarchy, resolved_type).
 *     • score [double precision]: Hybrid score (lexical + fuzzy) indicating relevance.
 *
 * @execute psql overture_es -f ./database/api/place/suggest.sql
 **/
 
create or replace function places.suggest(
    query text,
    limit_results integer default 10
) returns table (
    id text,
    name text,
    taxonomy jsonb,
    address jsonb,
    score double precision
) language plpgsql stable as
$$
declare
    lexeme text;
    signal boolean;
    lexemes text[];
    normalized text;
    candidates text;
    valid_typo text;
    query_ts tsquery;
begin
    -- Normalizing the query.
    normalized := search.normalize_text(query);
    if normalized is null or length(normalized) = 0 then
        return;
    end if;

    -- Builing a tsquery while correcting typos.
    valid_typo := '';
    lexemes := regexp_split_to_array(normalized, '\s+');
    signal := exists (select 1 from unnest(lexemes) l where length(l) > 2);
    for lexeme in select unnest(lexemes)
    loop
        if length(lexeme) <= 2 and signal then
            continue;
        elsif (select count(*) from places.word_dictionary where word = lexeme) > 0 then
            candidates := lexeme;
        else
            select '(' || string_agg(word, ' | ') || ')' into candidates
            from (
                select word
                from places.word_dictionary
                order by word <-> lexeme
                limit 10
            ) sub;
            if candidates is null then candidates := lexeme;
            end if;
        end if;
        valid_typo := valid_typo || candidates || ' & ';
    end loop;
 
    valid_typo := substring(valid_typo, 1, length(valid_typo) - 3);
    valid_typo := regexp_replace(valid_typo, '(\w+)(?=[^&]*$)', '\1:*', 'g');
    query_ts := to_tsquery('simple', valid_typo);
 
    -- Returning a shortlist of candidate places sorted by relevance.
    return query
    with filtered_places as materialized (
        select
            pl.id,
            pl.name,
            pl.taxonomy,
            pl.address,
            pl.search_document,
            pl.search_tsv
        from places.place pl
        where pl.search_tsv @@ query_ts
        limit 250
    )
    select
        fp.id,
        fp.name,
        fp.taxonomy,
        fp.address,
        (
            ts_rank(fp.search_tsv, query_ts) * 0.7 +
            similarity(normalized, fp.search_document) * 0.3
        ) as score
    from filtered_places fp
    order by score desc
    limit limit_results;
end;
$$;