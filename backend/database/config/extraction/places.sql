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
* Accedemos a la información de la tabla de configuración declarando variables
* que serán utilizadas más adelante para la conexión remota, además de en otros
* archivos.
**/

set variable last_release = (select last_release from config);
set variable base_url = (select base_url from config);
set variable country_code = (select country_code from config);

/*
* Extraemos los bordes y la geometría de la región objetivo en un conjunto de variables
* independientes, colaborando a una mejora en la velocidad de los escaneados en tablas.
**/

set variable x_min = (select bbox.xmin from bounds);
set variable x_max = (select bbox.xmax from bounds);
set variable y_min = (select bbox.ymin from bounds);
set variable y_max = (select bbox.ymax from bounds);
set variable boundary = (select geometry from bounds);

/*
* Creamos el archivo local en formato geoparquet con los datos de todos los puntos de
* interés que se almacenen en la base de datos geográfica de Overture Maps Foundation
* de acuerdo al modelado de datos especificado en la documentación del proyecto.
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
        addresses -> 0 as address
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
) to '../parquet/places.parquet';

/*
* La extracción funciona completamente. Se han filtrado además aquellas entradas
* de la tabla que no pertenezcan al país objetivo por proximidad con la frontera
* filtrando a través de las direcciones asociadas a cada punto de interés.
**/

-- Para ejecutar: duckdb temp.db < get_places.sql