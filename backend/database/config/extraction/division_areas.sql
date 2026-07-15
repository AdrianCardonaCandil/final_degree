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
* Creamos el archivo local en formato geoparquet con los datos de todas las areas de las
* divisiones administrativas de terreno que se almacenen en la base de datos geográfica
* de Overture Maps Foundation de acuerdo al modelado de datos especificado en la
* documentación del proyecto.
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
) to '../parquet/division_areas.parquet';

/*
* La extracción funciona completamente. Se han filtrado además aquellas entradas
* de la tabla que no pertenezcan al país objetivo por proximidad con la frontera
* filtrando a través de la propiedad 'country'.
**/

-- Para ejecutar: duckdb temp.db < get_division_areas.sql