/*
* Construye la columna materializada 'search_document' sobre addresses.address,
* que concatena y normaliza el texto relevante de cada dirección (columnas planas
* street/number/postcode + niveles jerárquicos extraídos de 'hierarchy') para su
* uso posterior en los índices de búsqueda de tipo tsvector/trigram.
**/

-- Añadimos la columna materializada 'search_document' a la tabla 'addresses.address'.
alter table addresses.address 
    add column if not exists search_document text;

-- Recalculamos el contenido de la columna para todos los registros de la tabla.
update addresses.address a
set search_document = search.normalize_text(
    concat_ws(
        ' ',
        a.street,
        a.number,
        a.postcode,
        h.microhood,
        h.neighborhood,
        h.macrohood,
        h.locality,
        h.county,
        h.region
    )
)
from (
    select
        addr.id,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'microhood') as microhood,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'neighborhood') as neighborhood,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'macrohood') as macrohood,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'locality') as locality,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'county') as county,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'region') as region
    from addresses.address addr
    cross join lateral jsonb_array_elements(addr.hierarchy) as entry
    group by addr.id
) as h
where a.id = h.id;

-- Limpiamos los registros muertos de la tabla de direcciones tras el update
vacuum full analyze addresses.address;

-- Para ejecutar: psql overture_es -f search_document.sql