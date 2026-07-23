/*
 * @file ./database/api/address/get_by_id.sql
 * @author Adrián Cardona Candil
 * @brief Retrieve an address by its unique identifier.
 *
 * @params
 *  id (text) - The unique identifier of the address.
 *
 * @return {table}
 *  Returns a table with the following columns:
 *   • id [text] - The unique identifier of the address.
 *   • geometry [geometry] - The geometry of the address.
 *   • bbox [bbox] - The bounding box of the address.
 *   • street [text] - The street name.
 *   • number [text] - The street number.
 *   • unit [text] - The unit number.
 *   • country [text] - The country where the address is located.
 *   • postcode [text] - The postal code.
 *   • hierarchy [jsonb] - The hierarchical structure of the address (microhood, neighordhood, macrohood, locality, etc).
 *
 * @execute psql overture_es -f ./database/api/address/get_by_id.sql
 **/

create or replace function addresses.get_by_id(
    _id text
) returns table (
    id text,
    geometry jsonb,
    bbox jsonb,
    street text,
    number text,
    unit text,
    country text,
    postcode text,
    hierarchy jsonb
) language sql stable as
$$
    select
        id,
        st_asgeojson(geometry)::jsonb as geometry,
        bbox,
        street,
        number,
        unit,
        country,
        postcode,
        hierarchy
    from addresses.address
    where id = _id;
$$;