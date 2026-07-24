
/*
 * @file ./database/api/place/get_by_id.sql
 * @author Adrián Cardona Candil
 * @brief Retrieve a point of interest by its unique identifier.
 *
 * @params
 *  id (text) - The unique identifier of the place.
 *
 * @return {table}
 *  Returns a table with the following columns:
 *   • id [text] - The unique identifier of the place.
 *   • geometry [jsonb] - The geometry of the place.
 *   • name [text] - The name of the point of interest.
 *   • bbox [jsonb] - The bounding box of the place.
 *   • description [text] - The description of the point of interest.
 *   • images [jsonb] - Images associated with the point of interest.
 *   • operating_status [text] - The current operating status of the point of interest.
 *   • confidence [float] - The confidence score of the source data.
 *   • websites [jsonb] - The websites associated with the point of interest.
 *   • socials [jsonb] - The social media profiles associated with the point of interest.
 *   • emails [jsonb] - The email addresses associated with the point of interest.
 *   • phones [jsonb] - The phone numbers associated with the point of interest.
 *   • taxonomy [jsonb] - The category classification of the point of interest.
 *   • brand [text] - The brand associated with the point of interest.
 *   • address [jsonb] - The address structure of the place (freeform, postcode, hierarchy, resolved_type).
 *
 * @execute psql overture_es -f ./database/api/place/get_by_id.sql
 **/
 
create or replace function places.get_by_id(
    _id text
) returns table (
    id text,
    geometry jsonb,
    name text,
    bbox jsonb,
    description text,
    images jsonb,
    operating_status text,
    confidence float,
    websites jsonb,
    socials jsonb,
    emails jsonb,
    phones jsonb,
    taxonomy jsonb,
    brand text,
    address jsonb
) language sql stable as
$$
    select
        id,
        st_asgeojson(geometry)::jsonb as geometry,
        name,
        bbox,
        description,
        images,
        operating_status,
        confidence,
        websites,
        socials,
        emails,
        phones,
        taxonomy,
        brand,
        address
    from places.place
    where id = _id;
$$;