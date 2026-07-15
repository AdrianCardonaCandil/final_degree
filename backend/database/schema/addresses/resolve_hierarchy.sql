/*
* Este archivo proporciona una amplicación a la tabla 'address' proveyendo dos nuevas
* columnas:
*   - Hierarchy: corresponde a la jeraquía territorial del punto donde se encuentra la
*   división. Ordenada de mayor a menor generalidad, comprende los diferentes tipos de
*   entes administrativos más tipicos (barrio, localidad, region, etcétera).
*   - ResolvedType: corresponde al tipo de división administrativa menor con registro
*   disponible en la tabla 'division' para aportar contexto informativo a una entrada
*   determinada.
**/

-- Fase 0: columnas necesarias (idempotente)
alter table addresses.address add column if not exists hierarchy jsonb;
alter table addresses.address add column if not exists resolved_type text;

-- Fase 0: índice espacial necesario para que las intersecciones sean eficientes
-- Generado en el archivo de creación de la base de datos

-- Fase 1 y 2: cascada geométrica descendente
do $$
declare
    levels text[] := array['microhood', 'neighborhood', 'macrohood', 'locality', 'county', 'region'];
    level text;
    rows_updated integer;
begin
    foreach level in array levels loop
        execute '
            update addresses.address a
            set
                hierarchy = d.hierarchy,
                resolved_type = $1
            from divisions.division d
            where
                a.hierarchy is null
                and d.id = (
                    select da.division_id
                    from divisions.division_area da
                    where
                        da.type = $1
                        and ST_Intersects(da.geometry, a.geometry)
                    order by ST_Distance(a.geometry, ST_Centroid(da.geometry))
                    limit 1
                )
        ' using level;
        get diagnostics rows_updated = row_count;
        raise notice 'Nivel %: % direcciones resueltas', level, rows_updated;
    end loop;
end $$;

-- Fase 3: fallback final a nivel país (con tolerancia geométrica)
do $$
declare
    rows_updated integer;
begin
    update addresses.address a
    set
        hierarchy = d.hierarchy,
        resolved_type = 'country'
    from divisions.division d
    where
        a.hierarchy is null
        and d.id = (
            select da.division_id
            from divisions.division_area da
            where
                da.type = 'country'
                and ST_DWithin(da.geometry, a.geometry, 0.01)
            order by ST_Distance(a.geometry, da.geometry)
            limit 1
        );
    get diagnostics rows_updated = row_count;
    raise notice 'Nivel country (fallback): % direcciones resueltas', rows_updated;
end $$;

-- Fase 4: limpiamos los registros muertos de la tabla de direcciones tras el update
vacuum analyze addresses.address;

-- Para ejecutar: psql overture_es -f resolve_address_hierarchy.sql