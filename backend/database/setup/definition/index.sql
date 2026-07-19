/*
 * @file ./database/index.sql
 * @author Adrián Cardona Candil
 * @brief Creates indexes to optimize database operations.
 * @execute psql overture_es -f ./database/index.sql
 **/

/*
 * @table divisions.division_area
 * @brief Indexes for the places table.
 *
 * @index idx_division_area_geom - GIST index for geoespatial queries on division_area table.
 **/

create index if not exists idx_division_area_geometry on divisions.division_area using gist (geometry);

/*
 * @table addresses.address
 * @brief Indexes for the address table.
 *
 * @index idx_address_search_document - Support for autocomplete and spelling error tolerance.
 * @index idx_address_search_tsv - Support for quick language inquiries and result ranking
 **/

create index if not exists idx_address_search_document on addresses.address using gin (search_document gin_trgm_ops);
create index if not exists idx_address_search_tsv on addresses.address using gin (search_tsv);