/*
* GERS_ID = a1848d2c-d37f-4009-9410-e13a97d9e6ae
* Instalación de extensiones básicas necesarias para procesar
* remotamente datos geoespaciales.
**/

install spatial;
install httpfs;
load spatial;
load httpfs;

/*
* Declaramos una tabla de configuración que contenga variables necesarias para
* el acceso a los datos de la plataforma de Overture Maps Foundation, como son
* la fecha de última versión, la dirección base o el país objetivo.
**/

create or replace table config as (
    select
        last_release,
        's3://overturemaps-us-west-2/release/' || last_release AS base_url,
        'ES' AS country_code
    from (select '2026-06-17.0/' as last_release)
);

/*
* Accedemos a la información de la tabla de configuración declarando variables
* que serán utilizadas más adelante para la conexión remota, además de en otros
* archivos.
**/

set variable last_release = (select last_release from config);
set variable base_url = (select base_url from config);
set variable country_code = (select country_code from config);

/*
* Buscamos el id de la división oficial de un país objetivo dentro
* de la plataforma de Overture Maps Foundation.
**/

set variable division_id = (
    select id
    from read_parquet(
        getvariable('base_url') || 'theme=divisions/type=division/*.parquet'
    )
    where country = getvariable('country_code') and subtype = 'country'
    limit 1
);

/*
* Creamos una tabla que contenga los límites geográficos (en coordenadas), del espacio
* deseado a través de una consulta. Podemos acceder a estos límites usando una variable
* de tipo geométrica.
**/

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

-- Para ejecutar: duckdb temp.db < get_bounds.sql