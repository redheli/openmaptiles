
-- etldoc: layer_place[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="layer_place | <zall> z0-z14_ " ] ;

-- etldoc: osm_continent_point -> layer_place
-- etldoc: osm_country_point   -> layer_place
-- etldoc: osm_state_point     -> layer_place
-- etldoc: osm_island_point    -> layer_place
-- etldoc: osm_island_polygon  -> layer_place
-- etldoc: layer_city          -> layer_place

CREATE OR REPLACE FUNCTION layer_place(bbox geometry, zoom_level int, pixel_width numeric)
RETURNS TABLE(osm_id bigint, geometry geometry, name text, name_en text, class text, "rank" int, capital INT) AS $$
    SELECT
        osm_id, geometry, name, name_en,
        'continent' AS class, 1 AS "rank", NULL::int AS capital
    FROM osm_continent_point
    WHERE geometry && bbox AND zoom_level < 4
    UNION ALL
    SELECT
        osm_id, geometry, name, COALESCE(NULLIF(name_en, ''), name) AS name_en,
        'country' AS class, "rank", NULL::int AS capital
    FROM osm_country_point
    WHERE geometry && bbox AND "rank" <= zoom_level AND name <> ''
    UNION ALL
    SELECT
        osm_id, geometry, name, COALESCE(NULLIF(name_en, ''), name) AS name_en,
        'state' AS class, "rank", NULL::int AS capital
    FROM osm_state_point
    WHERE geometry && bbox AND
          name <> '' AND
          ("rank" + 2 <= zoom_level) AND (
              zoom_level >= 5 OR
              is_in_country IN ('United Kingdom', 'USA', 'Россия', 'Brasil', 'China', 'India') OR
              is_in_country_code IN ('AU', 'CN', 'IN', 'BR', 'US'))
    UNION ALL
    SELECT
        osm_id, geometry, name, COALESCE(NULLIF(name_en, ''), name) AS name_en,
        'island' AS class, 7 AS "rank", NULL::int AS capital
    FROM osm_island_point
    WHERE zoom_level BETWEEN 12 AND 14
        AND geometry && bbox
    UNION ALL
    SELECT
        osm_id, geometry, name, COALESCE(NULLIF(name_en, ''), name) AS name_en,
        'island' AS class, island_rank(area) AS "rank", NULL::int AS capital
    FROM osm_island_polygon
    WHERE geometry && bbox AND
        ((zoom_level = 8 AND island_rank(area) <= 3)
        OR (zoom_level = 9 AND island_rank(area) <= 4)
        OR (zoom_level >= 10))
    UNION ALL
    SELECT
        osm_id, geometry, name, name_en,
        place::text AS class, "rank", capital
    FROM layer_city(bbox, zoom_level, pixel_width)
    ORDER BY "rank" ASC
$$ LANGUAGE SQL IMMUTABLE;