/*
 * @file ./database/config/model.sql
 * @author Adrián Cardona Candil
 * @brief Database model definition.
 * @execute psql overture_es -f ./database/config/model.sql
 **/

/*
 * @table places.place
 * @brief stores points of interest (POIs) such as businesses, services, or landmarks,
 *        based on the Overture Maps open data standard.
 *
 * @column {text} id - Unique identifier (UUID) for the place
 * @column {geometry(Point, 4326)} - POI's spatial location (EPSG:4326)
 * @column {text} name - POI's name
 * @column {jsonb} bbox - Limitrophe area representation (box) of the place
 * @column {text} description - General description / notes about the place
 * @column {jsonb} images - Paths, metadata or references to images of the place
 * @column {text} operating_status - Current operating status (open, closed, etc.)
 * @column {float} condifence - Level of certainty regarding the actual existence of the location (value between 0 and 1).
 * @column {jsonb} websites - Official website addresses (URLs) for the establishment.
 * @column {jsonb} socials - Links to social media profiles (Facebook, Instagram, etc.).
 * @column {jsonb} emails - Contact email addresses.
 * @column {jsonb} phones - Contact phone numbers (in international format).
 * @column {jsonb} taxonomy - A detailed, hierarchical categorization of the site.
 * @column {text} brand - Brand or retail chain with which the entity is affiliated.
 * @column {jsonb} address - Dirección estructurada asociada (país, región, calle, etc.).
 **/ 

create table if not exists places.place (
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
    address jsonb,
    search_document text,
    search_tsv tsvector
);

/*
 * @table addresses.address
 * @brief Stores georeferenced postal address information, standardizing its
 *        components and associated geometry
 *
 * @column {text} id - Unique identifier (UUID) for the address
 * @column {geometry(Point, 4326)} geometry - Point (EPSG:4326) representing the address's geometric location
 * @column {jsonb} bbox - Limitrophe area representation (box) of the address
 * @column {text} country - Name of the country where the address is located
 * @column {text} number - Street number (e.g., "123", "45A")
 * @column {text} postcode - Postal or ZIP code
 * @column {text} street - Name of the street 
 * @column {text} unit - Additional address unit specifier, such as an apartment or suite number
 **/

create table addresses.address (
    id text primary key,
    geometry geometry(Point, 4326) not null,
    bbox jsonb not null,
    street text,
    number text,
    unit text,
    country text,
    postcode text,
    hierarchy jsonb,
    resolved_type text,
    search_document text,
    search_tsv tsvector
);

/*
 * @table infrastructures.infrastructure
 * @brief Stores physical infrastructure elements based on the Overture Maps standard.
 *        The data extraction for this table has focused exclusively on transportation
 *        infrastructure (airport infrastructure, bus stations, train stations).
 *
 * @column {text} id - Unique identifier (UUID) for the infrastructure
 * @column {geometry(Geometry, 4326)} geomtry - Geometry representing the infrastructure's geometric location
 * @column {text} name - Name of the infrastructure
 * @column {jsonb} bbox - Limitrophe area representation (box) of the infrastructure
 * @column {text} type - Primary infrastructure subtype (mapped to “subtype” in Overture, e.g., “bridge,” “tunnel,” “airport”).
 * @column {text} class - A specific classification or category that defines the purpose or use of the structure.
 * @column {float} height - Height of the infrastructure.
 * @column {text} surface - Type of material used for the infrastructure surface.
 * @column {jsonb} tags - Additional tags and raw attributes imported directly from OpenStreetMap.
 **/

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

/*
 * @table divisions.division
 * @brief Stores the political and administrative divisions of territories (countries, regions, states, municipalities, etc.)
 *        according to the Overture Maps standard.
 *
 * @column {text} id - Unique identifier (UUID) for the division
 * @column {geometry(Point, 4326)} geometry - Geographic reference point or centroid of the division (EPSG:4326).
 * @column {text} name - Oficial or common name of the division.
 * @column {jsonb} bbox - Limitrophe area representation (box) of the division.
 * @column {jsonb} images - Links and image metadata associated with the division.
 * @column {text} description - Description or informational notes about the division. 
 * @column {text} type - Division subtype (mapping of ‘subtype’, e.g., ‘country’, ‘region’, ‘county’).
 * @column {text} country - The two-letter country code (ISO 3166-1 alpha-2) to which it belongs.
 * @column {text} region - Region or subdivision code (ISO 3166-2), if applicable.
 * @column {text} class - Classification of the level of government or status of the division.
 * @column {jsonb} hierarchy - Hierarchical relationships and a top-down administrative structure.
 * @column {text} parent_id - ID of the immediate higher-level territorial division (hierarchical parent).
 * @column {integer} population - Estimated population of the division.
 * @column {jsonb} capitals - IDs of the divisions that serve as its capitals (mapped to ‘capital_division_ids’).
 * @column {jsonb} capital_of - IDs de las divisiones de las cuales esta división es capital (mapeado de 'capital_of_divisions').
 * @column {jsonb} cartography - Reglas, etiquetas e información específica para el renderizado cartográfico.
 * @column {text} wikidata - Identificador de la entidad correspondiente en Wikidata (p. ej., Q2807).
 **/

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

/*
 * @table divisions.division_area
 * @brief Stores the polygons representing the land or maritime area associated with a political-administrative
 *        division (linked by ID).
 *
 * *column {text} id - Unique identifier (UUID) for the division area
 * *column {geometry(Geometry, 4326)} geometry - Surface geometry defining the boundary of the area (Polygon or Multipolygon in EPSG:4326).
 * *column {text} name - Official or common name of the administrative area.
 * *column {jsonb} bbox - Limitrophe area representation (box) of the surface of the area
 * *column {text} type - Division subtype (mapping of ‘subtype’, e.g., ‘country’, ‘region’, ‘county’).
 * *column {text} class - Classification of the type of boundary (e.g., “land” or “maritime”).
 * *column {boolean} land_clipped - Determines whether the geometry represents only the land boundary, excluding maritime areas (mapped as ‘is_land’).
 * *column {text} division_id - ID of the higher-level political-administrative division to which this area belongs (Foreign Key).
 * *column {text} country - Two-letter country code (ISO 3166-1 alpha-2) associated with the division.
 * *column {text} region - Region or province code (ISO 3166-2) associated with the division.
 **/

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
 * @table search.abbreviation
 * @brief Configuration table for storing regular expression (Regex) patterns used in text normalization.
 *        It is used to standardize addresses, streets, points of interest, etc, (both in user searches and
 *        when preparing ts_vector text vectors and ts_query queries).
 *
 * @column {serial} id - Unique identifier (UUID) for the abbreviation.
 * @column {text} expansion - Standardized or full term (e.g., “avenida”).
 * @column {text} pattern - A regular expression pattern that identifies the abbreviation in the input text.
 * @column {integer} priority - Priority level for applying the pattern (default 100). The lower the value, the higher the priority. Prevents matching collisions by sorting the replacements by this field (order by priority).
 **/

create table if not exists search.abbreviation (
    id serial primary key,
    expansion text not null,
    pattern text not null,
    priority integer not null default 100
);