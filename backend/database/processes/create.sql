/*
* Archivo encargado de los pasos necesarios para la creación de una base de datos geoespacial en PosgreSQL
* + PostGIS. Los pasos comprenden la creación de la base de datos, la activación de las extensiones que se
* necesitan, la creación de los esquemas (schema) para separar las estructuras en la base de datos, y las
* definiciones de las tablas básicas donde posteriormente se volcarán los datos.
**/

-- Creación de la base de datos.
create database overture_es
    with encoding = 'UTF8'
    lc_collate = 'es_ES.UTF-8'
    lc_ctype = 'es_ES.UTF-8'
    template = template0;

-- Conexión con la base de datos y activación de las extensiones geoespaciales.
\c overture_es
create extension if not exists postgis;
create extension if not exists postgis_topology;

-- Creación de los esquemas para ubicar las diferentes tablas de forma independiente.
create schema if not exists places;
create schema if not exists infrastructures;
create schema if not exists addresses;
create schema if not exists divisions;

/*
* Definición de la estructura de las diferentes tablas que van a formar parte de la
* base de datos. Cada una de las entradas de cada tabla registra el nombre del atributo,
* el tipo y las restricciones aplicadas al mismo.
**/

-- Place (Punto de interés)
create table places.place (
    id text primary key,
    geometry geometry(Point, 4326) not null,
    name text not null,
    bbox jsonb not null,
    description text,
    images jsonb,
    operating_status text,
    confidence float not null,
    websites jsonb,
    socials jsonb,
    emails jsonb,
    phones jsonb,
    taxonomy jsonb,
    brand text,
    addresses jsonb
);

-- Address (Diracción)
create table addresses.address (
    id text primary key,
    geometry geometry(Point, 4326) not null,
    bbox jsonb not null,
    country text,
    number text,
    postcode text,
    street text,
    unit text,
    address_levels jsonb
);

-- Infrastructure (Infraestructura)
create table infrastructures.infrastructure (
    id text primary key,
    geometry geometry(Geometry, 4326) not null,
    name text not null,
    bbox jsonb not null,
    type text not null,
    class text not null,
    height float,
    surface text,
    tags jsonb,
    constraint chk_geometry_type check (
        ST_GeometryType(geometry) in (
            'ST_Point',
            'ST_LineString',
            'ST_Polygon',
            'ST_MultiPolygon'
        )
    )
);

-- Division (División)
create table divisions.division (
    id text primary key,
    geometry geometry(Point, 4326) not null,
    name text not null,
    bbox jsonb not null,
    images jsonb,
    description text,
    type text not null,
    country text,
    region text,
    class text,
    hierarchy jsonb,
    parent_id text,
    population integer,
    capitals jsonb,
    capital_of jsonb,
    cartography jsonb,
    wikidata text
);

-- DivisionArea (Área de División)
create table divisions.division_area (
    id text primary key,
    geometry geometry(Geometry, 4326) not null,
    name text not null,
    bbox jsonb not null,
    type text not null,
    class text not null,
    land_clipped boolean,
    division_id text not null references divisions.division (id),
    country text,
    region text,
    constraint chk_geometry_type check (
        ST_GeometryType(geometry) in (
            'ST_Polygon',
            'ST_MultiPolygon'
        )
    )
);

/*
* Esta sección se utilizará para añadir los índices que sean necesarios para la
* ejecución de las diferentes funcionalidades que se esperan de la base de datos.
**/

-- Índice para la realización de operaciones espaciales en la tabla 'division_area'.
create index if not exists idx_division_area_geometry
    on divisions.division_area
    using gist (geometry); 

-- Para ejecutar: psql postgres -f create.sql