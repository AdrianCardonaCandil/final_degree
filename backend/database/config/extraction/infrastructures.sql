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
* Creamos el archivo local en formato geoparquet con los datos de todas las infrestructuras
* que se almacenen en la base de datos geográfica de Overture Maps Foundation
* de acuerdo al modelado de datos especificado en la documentación del proyecto.
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
) to '../parquet/infrastructures.parquet';

/*
* La extracción funciona completamente. Se han filtrado además aquellas entradas
* de la tabla que no pertenezcan a las categorías deseadas para el funcionamiento
* de la aplicación a través de la propiedad 'class' de cada registro.
**/

-- Para ejecutar: duckdb temp.db < get_infrastructures.sql