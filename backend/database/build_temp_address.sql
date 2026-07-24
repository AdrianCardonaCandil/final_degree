
/*
 * @file ./database/setup/aggregation/place/hierarchy.sql
 * @author Adrián Cardona Candil
 * @brief A spatial enrichment process that calculates and associates the hierarchical political-administrative
 *        structure of a location with each point of interest. It operates through a top-down geometric cascade
 *        of spatial intersections, mirroring ./database/setup/aggregation/address/hierarchy.sql.
 *
 *        The place.address jsonb column is restructured to hold exactly four keys: freeform and postcode
 *        (preserved as-is from the original Overture data) plus hierarchy and resolved_type, both derived
 *        here. locality, region and country are dropped, since hierarchy supersedes them.
 *
 * @updates address.hierarchy {jsonb} - Territorial hierarchy tree (from most general to least general) derived
 *       from the corresponding administrative division.
 * @updates address.resolved_type {text} - The lowest-level administrative division used to determine the
 *       location of the point of interest (e.g., "neighborhood," "locality," etc.).
 **/
 
-- Step 0: rebuilds address keeping only freeform/postcode as-is; hierarchy and resolved_type are
-- intentionally omitted here (not set to jsonb null) so that address -> 'hierarchy' reads as SQL NULL
-- below, letting jsonb_set add both keys cleanly once resolved.
update places.place
set address = jsonb_build_object(
    'freeform', address ->> 'freeform',
    'postcode', address ->> 'postcode'
);
 
-- Launches the hierarchy resolution process
do $$
declare
    levels text[] := array['microhood', 'neighborhood', 'macrohood', 'locality', 'county', 'region'];
    level text;
    rows_updated integer;
begin
    -- Iterating through the hierarchy levels from most specific to most general.
    foreach level in array levels loop
        update places.place p
        set address = jsonb_set(
                jsonb_set(p.address, '{hierarchy}', d.hierarchy),
                '{resolved_type}', to_jsonb(level)
            )
        from divisions.division d
        where
            p.address -> 'hierarchy' is null
            and d.id = (
                select da.division_id
                from divisions.division_area da
                where
                    da.type = level
                    and ST_Intersects(da.geometry, p.geometry)
                order by ST_Distance(p.geometry, ST_Centroid(da.geometry))
                limit 1
            );
        get diagnostics rows_updated = row_count;
        raise notice 'Nivel %: % lugares resueltos', level, rows_updated;
    end loop;
end $$;
 
-- Fallback for places that couldn't be resolved
do $$
declare
    rows_updated integer;
begin
    update places.place p
    set address = jsonb_set(
            jsonb_set(p.address, '{hierarchy}', d.hierarchy),
            '{resolved_type}', to_jsonb('country'::text)
        )
    from divisions.division d
    where
        p.address -> 'hierarchy' is null
        and d.id = (
            select da.division_id
            from divisions.division_area da
            where
                da.type = 'country'
                and ST_DWithin(da.geometry, p.geometry, 0.01)
            order by ST_Distance(p.geometry, da.geometry)
            limit 1
        );
    get diagnostics rows_updated = row_count;
    raise notice 'Nivel country (fallback): % lugares resueltos', rows_updated;
end $$;
 
-- Updates statistics and updates the index for better performance
vacuum full analyze places.place;