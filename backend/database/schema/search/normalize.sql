/*
* Normaliza una cadena de texto plano para su uso en los preocesos de búsqueda de tipo
* 'Suggest / Retrieve' (direcciones, puntos de interés y divisiones administrativas de
* terreno). La función aplica de forma secuencial, los siguientes pasos sobre el texto
* de entreda:
*   1. Normalización Unicode a forma NFC.
*   2. Eliminación de los símbolos especiales de puntuación '"' y "`".
*   3. Eliminación de diacríticos (tildes, diéresis, etcétera) vía unaccent.
*   4. Expansión de abreviaturas conocidas, según los patrones y prioridades
*      definidos en la tabla 'search.abbreviation'.
*   5. Sustitución de puntuación residual (no consumida por la expansión de
*      abreviaturas) por espacios en blanco.
*   6. Colapso de espacios múltiples en uno solo, y recorte de espacios
*      sobrantes al inicio y al final de la cadena.
*
* Al aplicarse de forma identica tanto en tiempo de indexación (construcción de 'search
* _document') como en tiempo de consulta (texto introducido por el usuario), garantiza
* la consistencia del matching entre ambos lados.
*
* Parámetros:
*   - input_text (text): cadena de texto plano a normalizar. Si es null, la función
*   devuelve null sin procesar.
*
* Retorna:
*   - text: la cadena normalizada, o NULL si la entrada era NULL.
**/

-- Creación de la extensión unaccent utilizada en el proceso de normalización.
create extension if not exists unaccent;


-- Creamos un schema para gestionar estructuras auxiliares de los procesos de búsqueda.
create schema if not exists search;

-- Definición de la tabla que almacena el set de abreviaturas utilizadas en el proceso. 
create table if not exists search.abbreviation (
    id serial primary key,
    expansion text not null,
    pattern text not null,
    priority integer not null default 100
);

-- Inserción de abreviaturas. Se recogen abreviaturas típicas de vías públicas españolas
-- y de lugares residenciales e industriales.
truncate table search.abbreviation restart identity;
insert into search.abbreviation (expansion, pattern, priority) values
    ('arroyo', '\marr\.º(?=\s)', default),
    ('avenida', '\mav\.(?=\s)|\mavd\.(?=\s)|\mavda\.(?=\s)|\mav\.ª(?=\s)', default),
    ('barrio', '\mbo\.(?=\s)|\mb\.º(?=\s)', default),
    ('bulevar', '\mblvr\.(?=\s)', default),
    ('calle', '\Ac\.(?=\s)|\Ac/(?=\s)|\mcl\.(?=\s)', default),
    ('camino alto', '\mc\.º\s+a\.(?=\s)', 10),
    ('camino bajo', '\mc\.º\s+b\.(?=\s)', 10),
    ('camino viejo', '\mc\.º\s+v\.(?=\s)', 10),
    ('camino', '\mc\.º(?=\s)', default),
    ('campillo', '\mcamp\.º(?=\s)', default),
    ('carrera', '\mcarr\.ª(?=\s)', default),
    ('carretera', '\mctra\.(?=\s)|\mcarret\.(?=\s)', default),
    ('cerrillo', '\mcerr\.º(?=\s)', default),
    ('costanilla', '\mcost\.ª(?=\s)', default),
    ('cuesta', '\mcta\.(?=\s)', default),
    ('ensanche', '\mens\.(?=\s)', default),
    ('extrarradio', '\mextr\.(?=\s)', default),
    ('glorieta', '\mgta\.(?=\s)|\mg\.ta(?=\s)', default),
    ('interior', '\mint\.(?=\s)', default),
    ('pasadizo', '\mp\.zo(?=\s)', default),
    ('pasaje', '\mpje\.(?=\s)|\mp\.je(?=\s)', default),
    ('paseo alto', '\mp\.º\s+a\.(?=\s)', 10),
    ('paseo bajo', '\mp\.º\s+b\.(?=\s)', 10),
    ('paseo', '\mp\.º(?=\s)', default),
    ('plaza', '\mp\.za\.(?=\s)|\mpza\.(?=\s)|\mpl\.(?=\s)|\mplza\.(?=\s)', default),
    ('pradera', '\mprad\.ª(?=\s)', default),
    ('pretil', '\mpret\.(?=\s)', default),
    ('puente', '\mp\.te(?=\s)|\mpte\.(?=\s)', default),
    ('punto kilométrico', '\mp\.\s+k\.(?=\s)', default),
    ('rambla', '\mrbla\.(?=\s)', default),
    ('ribera', '\mrib\.ª(?=\s)', default),
    ('ronda', '\mr\.da(?=\s)|\mrda\.(?=\s)', default),
    ('rotonda', '\mrot\.(?=\s)', default),
    ('travesía', '\mtr\.ª(?=\s)', default),
    ('vereda', '\mver\.ª(?=\s)|\mvda\.(?=\s)', default),
    ('urbanización', '\murb\.º(?=\s)|\murb\.(?=\s)', default),
    ('polígono industrial', '\mpol\.\s+ind\.(?=\s)|\mp\.i\.(?=\s)', 10),
    ('polígono', '\mpol\.(?=\s)', default),
    ('parque tecnológico', '\mp\.t\.(?=\s)', default),
    ('parque comercial', '\mp\.c\.(?=\s)', default),
    ('parque empresarial', '\mp\.e\.(?=\s)', default),
    ('parque', '\mpq\.(?=\s)', default),
    ('complejo', '\mcpjo\.(?=\s)', default),
    ('residencial', '\mres\.(?=\s)|\mresd\.(?=\s)', default),
    ('sector', '\msect\.(?=\s)|\msec\.(?=\s)', default),
    ('finca', '\mfca\.(?=\s)', default),
    ('caserío', '\mcas\.(?=\s)', default),
    ('poblado', '\mpob\.(?=\s)', default),
    ('colonia', '\mcol\.(?=\s)', default);

-- Definición de la función.
create or replace function search.normalize_text(input_text text)
returns text
language plpgsql
stable
as $$
declare
    normalized text;
    fila record;
begin
    if input_text is null then
        return null;
    end if;
    -- Paso 1. Normalización Unicode a forma NFC.
    normalized := normalize(input_text);
    -- Paso 2. Conversión a minúsculas.
    normalized := lower(normalized);
    -- Paso 3. Eliminación de diacríticos (tildes, diéresis, etc.).
    -- Sustitución temporal de los indicadores ordinales para evitar su eliminación.
    normalized := replace(normalized, 'º', chr(1));
    normalized := replace(normalized, 'ª', chr(2)); 
    normalized := unaccent(normalized); 
    -- Restauración de los indicadores ordinales.
    normalized := replace(normalized, chr(1), 'º');
    normalized := replace(normalized, chr(2), 'ª');
    -- Inserción de un espacio de cierre para posibilitar la expansión de abreviaturas
    -- presentes al final de la cadena (imposición de lookahead).
    normalized := normalized || ' ';
    -- Paso 4. Expansión de abreviaturas.
    for fila in
        select expansion, pattern
        from search.abbreviation
        order by priority asc, id asc
    loop
        normalized := regexp_replace(normalized, fila.pattern, fila.expansion, 'g');
    end loop;
    -- Paso 5. Sustitución de puntuación residual por espacios.
    normalized := regexp_replace(normalized, '[^\w\s]', ' ', 'g');
    -- Paso 6. Colapso de espacios múltiples en uno solo, y recorte de bordes.
    normalized := trim(regexp_replace(normalized, '\s+', ' ', 'g'));
    return normalized;
end;
$$;