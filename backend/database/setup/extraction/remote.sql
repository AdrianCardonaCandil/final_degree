/*
 * @file ./etl/download_overture.sql
 * @author Adrián Cardona Candil
 * @brief Downloads, filters, and extracts geographical data from the Overture Maps Foundation S3 bucket.
 *        It slices the global datasets by country bounding boxes, spatial intersections, or attributes, 
 *        saving them locally as partitioned GeoParquet files.
 * @execute duckdb < remote.sql
 **/

-- Install and load necessary extensions for remote HTTP/S3 file access and spatial analysis
install spatial;
install httpfs;
load spatial;
load httpfs;

-- Global configuration variables for data release versioning and country boundary filtering
set variable last_release = '2026-06-17.0/';
set variable base_url = 's3://overturemaps-us-west-2/release/' || getvariable('last_release');
set variable country_code = 'ES';

-- Retrieve the specific unique division ID corresponding to the target country
set variable division_id = (
    select id
    from read_parquet(
        getvariable('base_url') || 'theme=divisions/type=division/*.parquet'
    )
    where country = getvariable('country_code') and subtype = 'country'
    limit 1
);

-- Materialize a temporal boundary box and unified geometry envelope for the target country
create or replace table bounds as (
    select
        division_id,
        names.primary,
        ST_Union_Agg(geometry) as geometry,
        struct_pack(
            xmin := min(bbox.xmin),
            xmax := max(bbox.xmax),
            ymin := min(bbox.ymin),
            ymax := max(bbox.ymax)
        ) as bbox
    from read_parquet (
        getvariable('base_url') || 'theme=divisions/type=division_area/*.parquet'
    )
    where division_id = getvariable('division_id')
    group by division_id, names.primary
);

-- Store bounding coordinates and geometric boundary constraints into operational variables
set variable x_min = (select bbox.xmin from bounds);
set variable x_max = (select bbox.xmax from bounds);
set variable y_min = (select bbox.ymin from bounds);
set variable y_max = (select bbox.ymax from bounds);
set variable boundary = (select geometry from bounds);

/*
 * @entity places
 * @engine duckdb
 * @source S3: theme=places/type=place/\*.parquet
 * @target Parquet: parquet/place.parquet
 **/

copy (
    select
        id,
        geometry,
        names.primary as name,
        bbox,
        null as description,
        null as images,
        operating_status,
        confidence,
        websites,
        socials,
        emails,
        phones,
        struct_pack (
            "primary" := taxonomy.primary,
            hierarchy := taxonomy.hierarchy
        ) as taxonomy,
        brand.names.primary as brand,
        struct_pack (
            "freeform" := addresses -> 0 ->> 'freeform',
            "postcode" := addresses -> 0 ->> 'postcode'
        ) as address
    from read_parquet (
        getvariable('base_url') || 'theme=places/type=place/*.parquet'
    )
    where
        bbox.xmin > getvariable('x_min')
        and bbox.xmax < getvariable('x_max')
        and bbox.ymin > getvariable('y_min')
        and bbox.ymax < getvariable('y_max')
        and ST_INTERSECTS (
            getvariable('boundary'), geometry
        )
        and not len (
            list_filter (
                list_transform(addresses, lambda x: x.country),
                lambda x: x is not null and x != getvariable('country_code')
            )
        ) > 0
) to 'parquet/place.parquet';

/*
 * @entity addresses
 * @engine duckdb
 * @source S3: theme=addresses/type=address/\*.parquet
 * @target Parquet: parquet/address.parquet
 **/

copy (
    select
        id,
        geometry,
        bbox,
        country,
        number,
        postcode,
        street,
        unit
    from read_parquet (
        getvariable('base_url') || 'theme=addresses/type=address/*.parquet'
    )
    where
        country = getvariable('country_code')
) to 'parquet/address.parquet';

/*
 * @entity infrastructures
 * @engine duckdb
 * @source S3: theme=base/type=infrastructure/\*.parquet
 * @target Parquet: parquet/infrastructure.parquet
 **/

copy (
    select
        id,
        geometry,
        names.primary as name,
        bbox,
        subtype as type,
        class,
        height,
        surface,
        source_tags as tags
    from read_parquet (
        getvariable('base_url') || 'theme=base/type=infrastructure/*.parquet'
    )
    where
        bbox.xmin > getvariable('x_min')
        and bbox.xmax < getvariable('x_max')
        and bbox.ymin > getvariable('y_min')
        and bbox.ymax < getvariable('y_max')
        and ST_INTERSECTS (
            getvariable('boundary'), geometry
        )
        and names.primary is not null
        and class in (
            'airport',
            'municipal_airport',
            'regional_airport',
            'international_airport',
            'military_airport',
            'private_airport',
            'seaplane_airport',
            'railway_station',
            'bus_station',
            'subway_station',
            'ferry_terminal',
        )
) to 'parquet/infrastructure.parquet';

/*
 * @entity divisions
 * @engine duckdb
 * @source S3: theme=divisions/type=division/\*.parquet
 * @target Parquet: parquet/division.parquet
 **/

copy (
    select
        id,
        geometry,
        names.primary as name,
        bbox,
        null as description,
        null as images,
        subtype as type,
        country,
        class,
        region,
        list_transform (
            hierarchies[1],
            lambda entry: struct_pack (
                division_id := entry.division_id,
                type := entry.subtype,
                name := entry.name
            )
        ) as hierarchy,
        parent_division_id as parent_id,
        population,
        capital_division_ids as capitals,
        list_transform (
            capital_of_divisions,
            lambda capital: struct_pack (
                division_id := capital.division_id,
                type := capital.subtype
            )
        ) as capital_of,
        cartography,
        wikidata
    from read_parquet(
        getvariable('base_url') || 'theme=divisions/type=division/*.parquet'
    )
    where
        country = getvariable('country_code')
) to 'parquet/division.parquet';

/*
 * @entity division_areas
 * @engine duckdb
 * @source S3: theme=divisions/type=division_area/\*.parquet
 * @target Parquet: parquet/division_area.parquet
 **/

copy (
    select
        id,
        geometry,
        names.primary as name,
        bbox,
        subtype as type,
        class,
        is_land as land_clipped,
        division_id,
        country,
        region
    from read_parquet(
        getvariable('base_url') || 'theme=divisions/type=division_area/*.parquet'
    )
    where
        country = getvariable('country_code')
) to 'parquet/division_area.parquet';