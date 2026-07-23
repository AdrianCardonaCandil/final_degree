/*
 * @file    ./database/api/address/suggest.sql
 * @author  Adrián Cardona Candil
 * @brief   Autocomplete (Suggest) endpoint for the address table. Implement the “Suggest” phase of a
 *          Suggest/Retrieve-type address search engine on the “addresses.address” table. Given free-text
 *          input from the user, it returns a shortlist of candidate addresses sorted by relevance, with
 *          response times of ~100–200 ms. The list of final candidates is calculated using a strategy
 *          that includes indexed filtering (@@) with an intermediate threshold and reordering of the filtered
 *          set based on a hybrid score (lexical + fuzzy).
 *
 * @params
 *   query [text]: Free-text input from the user.
 *   limit_results [integer]: Maximum number of candidate addresses to return.
 *
 * @return [table]
 *   Returns a table with the following columns:
 *     • id [text]: Unique identifier of the address.
 *     • street [text]: Street name.
 *     • number [text]: Street number.
 *     • unit [text]: Unit number.
 *     • postcode [text]: Postal code.
 *     • hierarchy [jsonb]: Hierarchical structure of the address (microhood, neighordhood, macrohood, locality, etc).
 *     • score [double precision]: Hybrid score (lexical + fuzzy) indicating relevance.
 *
 * @execute psql overture_es -f ./database/api/address/suggest.sql
 **/

create or replace function addresses.suggest(
    query text,
    limit_results integer default 10
) returns table (
    id text,
    street text,
    number text,
    unit text,
    postcode text,
    hierarchy jsonb,
    score double precision
) language plpgsql stable as
$$
declare
    lexeme text;
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
    for lexeme in select unnest(regexp_split_to_array(normalized, '\s+'))
    loop
        if length(lexeme) <= 2 then
            continue;
        elsif (select count(*) from addresses.word_dictionary where word = lexeme) > 0 then
            candidates := lexeme;
        else
            select '(' || string_agg(word, ' | ') || ')' into candidates
            from (
                select word
                from addresses.word_dictionary
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
    
    -- Returning a shortlist of candidate addresses sorted by relevance.
    return query
    with filtered_addresses as materialized (
        select
            ad.id,
            ad.street,
            ad.number,
            ad.unit,
            ad.postcode,
            ad.country,
            ad.hierarchy,
            ad.search_document,
            ad.search_tsv
        from addresses.address ad
        where ad.search_tsv @@ query_ts
        limit 250
    )
    select 
        fa.id,
        fa.street,
        fa.number,
        fa.unit,
        fa.country,
        fa.postcode,
        fa.hierarchy,
        (
            ts_rank(fa.search_tsv, query_ts) * 0.7 +
            similarity(normalized, fa.search_document) * 0.3
        ) as score
    from filtered_addresses fa
    order by score desc
    limit limit_results;
end;
$$;