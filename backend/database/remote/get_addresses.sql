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
* Creamos el archivo local en formato geoparquet con los datos de todas las direcciones
* que se almacenen en la base de datos geográfica de Overture Maps Foundation
* de acuerdo al modelado de datos especificado en la documentación del proyecto.
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
        unit,
        address_levels
    from read_parquet (
        getvariable('base_url') || 'theme=addresses/type=address/*.parquet'
    )
    where
        country = getvariable('country_code')
) to '../parquet/addresses.parquet';

/*
* La extracción funciona completamente. Se han filtrado además aquellas entradas
* de la tabla que no pertenezcan al país objetivo por proximidad con la frontera
* filtrando a través de la propiedad 'country'.
**/

-- Para ejecutar: duckdb temp.db < get_addresses.sql