/*
 * @file ./database/setup/definition/view.sql
 * @author Adrián Cardona Candil
 * @brief Views or materialized views from the database tables.
 * @execute psql overture_es -f ./database/setup/definition/view.sql
 **/

/*
 * @view addresses.word_dictionary
 * @brief Materialized view created from every posible normalized lexical unit extracted
 *        from the search_document column of the addresses.address table. This view is
 *        essential for providing typo error tolerant queries and suggestions.
 *     
 * @column {text} word - The lexical unit.
 * 
 * @source addresses.address
 **/

create materialized view if not exists addresses.word_dictionary as
select word
from ts_stat('select search_tsv from addresses.address');

/*
 * @view places.word_dictionary
 * @brief Materialized view created from everypossible normalized lexical unit extracted
 *        from the search_document column of the places.place table. This view is
 *        essential for providing typo error tolerant queries and suggestions.
 *     
 * @column {text} word - The lexical unit.
 * 
 * @source places.place
 **/

create materialized view if not exists places.word_dictionary as
select word
from ts_stat('select search_tsv from places.place');
