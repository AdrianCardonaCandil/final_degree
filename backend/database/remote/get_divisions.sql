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
* Creamos el archivo local en formato geoparquet con los datos de todas las divisiones
* administrativas de terreno que se almacenen en la base de datos geográfica de Overture
* Maps Foundation de acuerdo al modelado de datos especificado en la documentación del
* proyecto.
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
            hierarchies,
            lambda hierarchy: list_transform (
                hierarchy,
                lambda entry: struct_pack (
                    division_id := entry.division_id,
                    type := entry.subtype,
                    name := entry.name
                )
            )
        ) as hierarchies,
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
) to '../parquet/divisions.parquet';

/*
* La extracción funciona completamente. Se han filtrado además aquellas entradas
* de la tabla que no pertenezcan al país objetivo por proximidad con la frontera
* filtrando a través de la propiedad 'country'.
* Se han agregado las entradas que tengan también una entidad de area en la tabla de
* areas de divisiones administrativas por lo que, para que este archivo se ejecute
* correctamente debe de habarse creado anteriormente el archivo 'parquet' con los
* datos de la entidad 'DivisionArea'.
**/

-- Para ejecutar: duckdb temp.db < get_divisions.sql