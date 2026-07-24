/*
 * @file ./database/seed.sql
 * @author Adrián Cardona Candil
 * @brief Seeds the database with initial data.
 * @execute psql overture_es -f ./database/seed.sql
 **/

-- Installation of extensions required for the bridge between DuckDB and PostgreSQL.
install postgres;
load postgres;
load spatial;

-- Setting the target (PostgreSQL database)
attach 'host=localhost port=5432 dbname=overture_es user=adriancc' as overture_es (type postgres);

/*
 * @table places.place
 * @engine duckdb
 * @source Parquet: ../extraction/parquet/place.parquet
 * @target PostgreSQL: overture_es.places.place
 **/

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
    to_json(address) as address,
    null as search_document,
    null as search_tsv
from read_parquet('../extraction/parquet/place.parquet');

/*
 * @table addresses.address
 * @engine duckdb
 * @source Parquet: ../extraction/parquet/address.parquet
 * @target PostgreSQL: overture_es.addresses.address
 **/

truncate table overture_es.addresses.address;
insert into overture_es.addresses.address
select
    id,
    geometry,
    to_json(bbox) as bbox,
    street,
    number,
    unit,
    country,
    postcode,
    null as hierarchy,
    null as resolved_type,
    null as search_document,
    null as search_tsv
from read_parquet('../extraction/parquet/address.parquet');

/*
 * @table infrastructures.infrastructure
 * @engine duckdb
 * @source Parquet: ../extraction/parquet/infrastructure.parquet
 * @target PostgreSQL: overture_es.infrastructures.infrastructure
 **/

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
from read_parquet('../extraction/parquet/infrastructure.parquet');

/*
 * @table divisions.division
 * @engine duckdb
 * @source Parquet: ../extraction/parquet/division.parquet
 * @target PostgreSQL: overture_es.divisions.division
 **/

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
from read_parquet('../extraction/parquet/division.parquet');

/*
 * @table divisions.division_area
 * @engine duckdb
 * @source Parquet: ../extraction/parquet/division_area.parquet
 * @target PostgreSQL: overture_es.divisions.division_area
 **/

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
from read_parquet('../extraction/parquet/division_area.parquet');

/*
 * @table search.abbreviation
 * @engine PostgreSQL
 * @target PostgreSQL: overture_es.search.abbreviation
 **/

truncate table overture_es.search.abbreviation;
insert into overture_es.search.abbreviation (id, expansion, pattern, priority) values
    (1, 'arroyo', '\marr\.º(?=\s)', 100),
    (2, 'avenida', '\mav\.(?=\s)|\mavd\.(?=\s)|\mavda\.(?=\s)|\mav\.ª(?=\s)', 100),
    (3, 'barrio', '\mbo\.(?=\s)|\mb\.º(?=\s)', 100),
    (4, 'bulevar', '\mblvr\.(?=\s)', 100),
    (5, 'calle', '\mc\.(?=\s)|\mc/(?=\s)|\mcl\.(?=\s)', 100),
    (6, 'camino alto', '\mc\.º\s+a\.(?=\s)', 10),
    (7, 'camino bajo', '\mc\.º\s+b\.(?=\s)', 10),
    (8, 'camino viejo', '\mc\.º\s+v\.(?=\s)', 10),
    (9, 'camino', '\mc\.º(?=\s)', 100),
    (10, 'campillo', '\mcamp\.º(?=\s)', 100),
    (11, 'carrera', '\mcarr\.ª(?=\s)', 100),
    (12, 'carretera', '\mctra\.(?=\s)|\mcarret\.(?=\s)', 100),
    (13, 'cerrillo', '\mcerr\.º(?=\s)', 100),
    (14, 'costanilla', '\mcost\.ª(?=\s)', 100),
    (15, 'cuesta', '\mcta\.(?=\s)', 100),
    (16, 'ensanche', '\mens\.(?=\s)', 100),
    (17, 'extrarradio', '\mextr\.(?=\s)', 100),
    (18, 'glorieta', '\mgta\.(?=\s)|\mg\.ta(?=\s)', 100),
    (19, 'interior', '\mint\.(?=\s)', 100),
    (20, 'pasadizo', '\mp\.zo(?=\s)', 100),
    (21, 'pasaje', '\mpje\.(?=\s)|\mp\.je(?=\s)', 100),
    (22, 'paseo alto', '\mp\.º\s+a\.(?=\s)', 10),
    (23, 'paseo bajo', '\mp\.º\s+b\.(?=\s)', 10),
    (24, 'paseo', '\mp\.º(?=\s)', 100),
    (25, 'plaza', '\mp\.za\.(?=\s)|\mpza\.(?=\s)|\mpl\.(?=\s)|\mplza\.(?=\s)', 100),
    (26, 'pradera', '\mprad\.ª(?=\s)', 100),
    (27, 'pretil', '\mpret\.(?=\s)', 100),
    (28, 'puente', '\mp\.te(?=\s)|\mpte\.(?=\s)', 100),
    (29, 'punto kilométrico', '\mp\.\s+k\.(?=\s)', 100),
    (30, 'rambla', '\mrbla\.(?=\s)', 100),
    (31, 'ribera', '\mrib\.ª(?=\s)', 100),
    (32, 'ronda', '\mr\.da(?=\s)|\mrda\.(?=\s)', 100),
    (33, 'rotonda', '\mrot\.(?=\s)', 100),
    (34, 'travesía', '\mtr\.ª(?=\s)', 100),
    (35, 'vereda', '\mver\.ª(?=\s)|\mvda\.(?=\s)', 100),
    (36, 'urbanización', '\murb\.º(?=\s)|\murb\.(?=\s)', 100),
    (37, 'polígono industrial', '\mpol\.\s+ind\.(?=\s)|\mp\.i\.(?=\s)', 10),
    (38, 'polígono', '\mpol\.(?=\s)', 100),
    (39, 'parque tecnológico', '\mp\.t\.(?=\s)', 100),
    (40, 'parque comercial', '\mp\.c\.(?=\s)', 100),
    (41, 'parque empresarial', '\mp\.e\.(?=\s)', 100),
    (42, 'parque', '\mpq\.(?=\s)', 100),
    (43, 'complejo', '\mcpjo\.(?=\s)', 100),
    (44, 'residencial', '\mres\.(?=\s)|\mresd\.(?=\s)', 100),
    (45, 'sector', '\msect\.(?=\s)|\msec\.(?=\s)', 100),
    (46, 'finca', '\mfca\.(?=\s)', 100),
    (47, 'caserío', '\mcas\.(?=\s)', 100),
    (48, 'poblado', '\mpob\.(?=\s)', 100),
    (49, 'colonia', '\mcol\.(?=\s)', 100);
