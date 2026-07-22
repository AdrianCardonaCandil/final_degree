/*
 * @file ./database/setup/function/search/normalize.sql
 * @author Adrián Cardona Candil
 * @brief Normalizes a plain text string to ensure consistency in “Suggest/Retrieve” search processes
 *        (addresses, POIs, and administrative divisions).
 *        By applying it identically during both indexing and querying, it ensures that terms match.
 *
 *        1. Normalize Unicode to NFC.
 *        2. Convert to lowercase.
 *        3. Remove diacritics (accents, umlauts, etc.).
 *        4. Expand abbreviations.
 *        5. Replace residual punctuation with spaces.
 *        6. Collapse multiple spaces into a single space and trim the edges.
 *
 * @param {text} input_text - The string to normalize. If it is null, the function returns null.
 * @returns {text} normalized - A fully normalized and standardized string.
 **/
 
create or replace function search.normalize_text(input_text text)
returns text
language plpgsql
stable
as $$
declare
    normalized text;
    fila record;
begin
    if input_text is null then
        return null;
    end if;
    normalized := normalize(input_text);

    normalized := lower(normalized);
    
    normalized := replace(normalized, 'º', chr(1));
    normalized := replace(normalized, 'ª', chr(2)); 
    normalized := unaccent(normalized); 
    normalized := replace(normalized, chr(1), 'º');
    normalized := replace(normalized, chr(2), 'ª');
    normalized := normalized || ' ';

    for fila in
        select expansion, pattern
        from search.abbreviation
        order by priority asc, id asc
    loop
        normalized := regexp_replace(normalized, fila.pattern, fila.expansion, 'g');
    end loop;

    normalized := regexp_replace(normalized, '[^\w\s]', ' ', 'g');
    
    normalized := trim(regexp_replace(normalized, '\s+', ' ', 'g'));
    return normalized;
end;
$$;