/*
* Construye la columna materializada 'search_tsv' sobre addresses.address.
* Se trata de un vector ponderado (setweight con pesos A-D) combinando las
* columnas planas (street, number y postcode) con los niveles jersárquicos
* extraídos del atributo 'hierarchy'. Se usa la siguiente tabla de grupos:
*   A: street, number
*   B: postcode, microhood, neighborhood, macrohood
*   C: locality, county
*   D: region
**/

-- Añadimos la columna search_tsv a la tabla addresses.address
alter table addresses.address
    add column if not exists search_tsv tsvector;

-- Recalculamos el vector materializado para todos los registros
update addresses.address a
set search_tsv =
    setweight(to_tsvector('simple', search.normalize_text(concat_ws(' ', a.street, a.number))), 'A') ||
    setweight(to_tsvector('simple', search.normalize_text(concat_ws(' ', a.postcode, h.microhood, h.neighborhood, h.macrohood))), 'B') ||
    setweight(to_tsvector('simple', search.normalize_text(concat_ws(' ', h.locality, h.county))), 'C') ||
    setweight(to_tsvector('simple', search.normalize_text(h.region)), 'D')
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

-- Para ejecutar: psql overture_es -f search_tsv.sql