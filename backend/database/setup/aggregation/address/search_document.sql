/**
 * @file: ./database/setup/aggregation/address/search_document.sql
 * @author: Adrián Cardona Candil
 * @brief: Creates and stores the unified plain-text field ‘search_document’
 *         in the address table. Consolidates the linear address information
 *         with its resolved administrative divisions to populate the full-text
 *         search indexes.
 *
 * @adds search_document {text} - A standardized textual representation of geographic
 *       information associated with an address, covering both its inherent characteristics
 *       and its administrative hierarchy.
 *
 * @execution psql overture_es -f search_document.sql
 */

-- Adds column to the address table
alter table addresses.address add column if not exists search_document text;

-- Launches the normalization and search_document creation process
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

-- Updates statistics and updates the index for better performance
vacuum full analyze addresses.address;
