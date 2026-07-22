/*
 * @file ./database/setup/aggregation/address/search_tsv.sql
 * @author Adrián Cardona Candil
 * @brief Creates the materialized column ‘search_tsv’ on addresses.address. This is a weighted vector
 *        (setweight with weights A–D) that combines the flat columns (street, number, and postcode)
 *        with the hierarchical levels extracted from the ‘hierarchy’ attribute. The following group
 *        table is used:
 *        A: street, number, unit
 *        B: postcode, microhood, neighborhood, macrohood
 *        C: locality, county
 *        D: region
 *
 * @updates search_tsv {tsvector} - A weighted representation of geographic information associated with an address, 
 *       coverign both its inherent characteristics and its administrative hierarchy.
 *
 * @execution psql overture_es -f search_tsv.sql
 */

-- Launches the search_tsv update process
update addresses.address a
set search_tsv =
    setweight(to_tsvector('simple', search.normalize_text(concat_ws(' ', a.street, a.number, a.unit))), 'A') ||
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

-- Updates statistics and updates the index for better performance
vacuum full analyze addresses.address;

