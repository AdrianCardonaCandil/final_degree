/*
* Este archivo permite el volcado de datos desde los archivos locales en formato
* 'parquet' a la base de datos relacional creada con PostgreSQL y PostGIS. Se va a
* proceder a poblar las tablas de los distintos esquemas (POI, Infraestructuras,
* Direcciones y Divisiones Territoriales). Para ello se usará DuckDB como conexión
* entre ambos sistemas gestores de bases de datos.
**/

-- Instalación de extensiones necesarias para el punte entre DuckDB y PostgreSQL.
install postgres;
load postgres;
load spatial;

-- Declaración del destino (base de datos PostgreSQL)
attach 'host=localhost port=5432 dbname=overture_es user=adriancc'
    as overture_es (type postgres);

-- Volcado de los datos extraidos de la capa 'places' a la base de datos (POI).
truncate table overture_es.places.place;
insert into overture_es.places.place
select
    id,
    geometry,
    name,
    to_json(bbox) as bbox,
    description,
    to_json(images) as images,
    operating_status,
    confidence,
    to_json(websites) as websites,
    to_json(socials) as socials,
    to_json(emails) as emails,
    to_json(phones) as phones,
    to_json(taxonomy) as taxonomy,
    brand,
    to_json(addresses) as addresses
from read_parquet('../parquet/places.parquet');

-- Volcado de los datos extraidos de la capa 'addresses' a la base de datos.
truncate table overture_es.addresses.address;
insert into overture_es.addresses.address
select
    id,
    geometry,
    to_json(bbox) as bbox,
    country,
    number,
    postcode,
    street,
    unit,
    to_json(address_levels) as address_levels
from read_parquet('../parquet/addresses.parquet');

-- Volcado de los datos extraidos de la capa 'infrastructures' a la base de datos.
truncate table overture_es.infrastructures.infrastructure;
insert into overture_es.infrastructures.infrastructure
select
    id,
    geometry,
    name,
    to_json(bbox) as bbox,
    type,
    class,
    height,
    surface,
    to_json(tags) as tags
from read_parquet('../parquet/infrastructures.parquet');

-- Volcado de los datos extraidos de la capa 'divisions' a la base de datos.
truncate table overture_es.divisions.division;
insert into overture_es.divisions.division
select
    id,
    geometry,
    name,
    to_json(bbox) as bbox,
    to_json(images) as images,
    description,
    type,
    country,
    region,
    class,
    to_json(hierarchy) as hierarchy,
    parent_id,
    population,
    to_json(capitals) as capitals,
    to_json(capital_of) as capital_of,
    to_json(cartography) as cartography,
    wikidata
from read_parquet('../parquet/divisions.parquet');

-- Volcado de los datos extraidos de la capa 'division_areas' a la base de datos.
truncate table overture_es.divisions.division_area;
insert into overture_es.divisions.division_area
select
    id,
    geometry,
    name,
    to_json(bbox) as bbox,
    type,
    class,
    land_clipped,
    division_id,
    country,
    region
from read_parquet('../parquet/division_areas.parquet');

-- Para ejecutar: duckdb < populate.sql