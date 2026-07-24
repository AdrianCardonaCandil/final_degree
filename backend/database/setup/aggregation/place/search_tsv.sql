/*
 * @file ./database/setup/aggregation/place/search_tsv.sql
 * @author Adrián Cardona Candil
 * @brief Creates the materialized column ‘search_tsv’ on places.place. This is a weighted vector
 *        (setweight with weights A–D) that combines the point of interest name and freeform address
 *        with the hierarchical levels extracted from the ‘address.hierarchy’ attribute. The following
 *        group table is used:
 *        A: name, freeform
 *        B: postcode, microhood, neighborhood, macrohood
 *        C: locality, county
 *        D: region
 *
 * @updates search_tsv {tsvector} - A weighted representation of geographic information associated with a
 *       point of interest, covering both its inherent characteristics and its administrative hierarchy.
 *
 * @execution psql overture_es -f search_tsv.sql
 */
 
-- Launches the search_tsv update process
update places.place p
set search_tsv =
    setweight(to_tsvector('simple', search.normalize_text(concat_ws(' ', p.name, p.address ->> 'freeform'))), 'A') ||
    setweight(to_tsvector('simple', search.normalize_text(concat_ws(' ', p.address ->> 'postcode', h.microhood, h.neighborhood, h.macrohood))), 'B') ||
    setweight(to_tsvector('simple', search.normalize_text(concat_ws(' ', h.locality, h.county))), 'C') ||
    setweight(to_tsvector('simple', search.normalize_text(h.region)), 'D')
from (
    select
        plc.id,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'microhood') as microhood,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'neighborhood') as neighborhood,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'macrohood') as macrohood,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'locality') as locality,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'county') as county,
        string_agg(distinct entry ->> 'name', ' ') filter (where entry ->> 'type' = 'region') as region
    from places.place plc
    cross join lateral jsonb_array_elements(plc.address -> 'hierarchy') as entry
    group by plc.id
) as h
where p.id = h.id;
 
-- Updates statistics and updates the index for better performance
vacuum full analyze places.place;