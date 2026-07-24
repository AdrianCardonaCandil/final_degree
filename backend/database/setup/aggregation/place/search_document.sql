/**
 * @file: ./database/setup/aggregation/place/search_document.sql
 * @author: Adrián Cardona Candil
 * @brief: Creates and stores the unified plain-text field ‘search_document’
 *         in the place table. Consolidates the point of interest name and its
 *         linear address information with its resolved administrative divisions
 *         to populate the full-text search indexes.
 *
 * @updates search_document {text} - A standardized textual representation of geographic
 *       information associated with a point of interest, covering both its inherent
 *       characteristics and its administrative hierarchy.
 *
 * @execution psql overture_es -f search_document.sql
 */
 
-- Launches the normalization and search_document creation process
update places.place p
set search_document = search.normalize_text(
    concat_ws(
        ' ',
        p.name,
        p.address ->> 'freeform',
        p.address ->> 'postcode',
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