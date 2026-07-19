/*
 * @file ./database/setup/function/search/normalize.sql
 * @author Adrián Cardona Candil
 * @brief Normalizes a plain text string to ensure consistency in “Suggest/Retrieve” search processes
 *        (addresses, POIs, and administrative divisions).
 *        By applying it identically during both indexing and querying, it ensures that terms match.
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
    -- Paso 1. Normalización Unicode a forma NFC.
    normalized := normalize(input_text);
    -- Paso 2. Conversión a minúsculas.
    normalized := lower(normalized);
    -- Paso 3. Eliminación de diacríticos (tildes, diéresis, etc.).
    -- Sustitución temporal de los indicadores ordinales para evitar su eliminación.
    normalized := replace(normalized, 'º', chr(1));
    normalized := replace(normalized, 'ª', chr(2)); 
    normalized := unaccent(normalized); 
    -- Restauración de los indicadores ordinales.
    normalized := replace(normalized, chr(1), 'º');
    normalized := replace(normalized, chr(2), 'ª');
    -- Inserción de un espacio de cierre para posibilitar la expansión de abreviaturas
    -- presentes al final de la cadena (imposición de lookahead).
    normalized := normalized || ' ';
    -- Paso 4. Expansión de abreviaturas.
    for fila in
        select expansion, pattern
        from search.abbreviation
        order by priority asc, id asc
    loop
        normalized := regexp_replace(normalized, fila.pattern, fila.expansion, 'g');
    end loop;
    -- Paso 5. Sustitución de puntuación residual por espacios.
    normalized := regexp_replace(normalized, '[^\w\s]', ' ', 'g');
    -- Paso 6. Colapso de espacios múltiples en uno solo, y recorte de bordes.
    normalized := trim(regexp_replace(normalized, '\s+', ' ', 'g'));
    return normalized;
end;
$$;