/*
 * @file ./database/index.sql
 * @author Adrián Cardona Candil
 * @brief Creates indexes to optimize database operations.
 * @execute psql overture_es -f ./database/index.sql
 **/

/*
 * @table places.places
 * @brief Indexes for the place table.
 *
 * @index idx_place_search_document - Support for autocomplete and spelling error tolerance.
 * @index idx_place_search_tsv - Support for quick language inquiries and result ranking.
 **/

create index if not exists idx_place_search_document on places.place using gin (search_document gin_trgm_ops) with (fastupdate = off);
create index if not exists idx_place_search_tsv on places.place using gin (search_tsv) with (fastupdate = off);

/*
 * @table addresses.address
 * @brief Indexes for the address table.
 *
 * @index idx_address_search_document - Support for autocomplete and spelling error tolerance.
 * @index idx_address_search_tsv - Support for quick language inquiries and result ranking.
 **/

create index if not exists idx_address_search_document on addresses.address using gin (search_document gin_trgm_ops) with (fastupdate = off);
create index if not exists idx_address_search_tsv on addresses.address using gin (search_tsv) with (fastupdate = off);

/*
 * @table divisions.division_area
 * @brief Indexes for the places table.
 *
 * @index idx_division_area_geom - GIST index for geoespatial queries on division_area table.
 **/

create index if not exists idx_division_area_geometry on divisions.division_area using gist (geometry);

/*
 * @materialized_view addresses.word_dictionary
 * @brief Indexes for the addresses word_dictionary table.
 * 
 * @index idx_address_word_dictionary - GIST index for fast typo error tolerant queries.
 **/

create index if not exists idx_address_word_dictionary on addresses.word_dictionary using gist (word gist_trgm_ops);

/*
 * @materialized_view places.word_dictionary
 * @brief Indexes for the place word_dictionary table.
 * 
 * @index idx_place_word_dictionary - GIST index for fast typo error tolerant queries.
 **/

create index if not exists idx_place_word_dictionary on places.word_dictionary using gist (word gist_trgm_ops);
