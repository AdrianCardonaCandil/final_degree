/*
 * @file ./database/setup/aggregation/address/hierarchy.sql
 * @author Adrián Cardona Candil
 * @brief A spatial enrichment process that calculates and associates the hierarchical political-administrative
 *        structure of a location with each direction. It operates through a top-down geometric cascade of spatial
 *        intersections.
 *
 * @adds hierarchy {jsonb} - Territorial hierarchy tree (from most general to least general) derived from the
 *       corresponding administrative division.
 * @adds resolved_type {text} - The lowest-level administrative division used to determine the location of the
 *       address (e.g., “neighborhood,” “locality,” etc.).
 **/

-- Adds columns to the address table
alter table addresses.address add column if not exists hierarchy jsonb;
alter table addresses.address add column if not exists resolved_type text;

-- Launches the hierarchy resolution process
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

-- Fallback for addresses that couldn't be resolved
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

-- Updates statistics and updates the index for better performance
vacuum full analyze addresses.address;