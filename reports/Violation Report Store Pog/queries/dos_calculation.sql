WITH placement_data AS (
    SELECT
        osp.filter_config_id AS gen_id,
        osp.base_pog_id,
        osp.store AS store_code,
        item ->> 'productCode' AS product_code,
        item ->> 'name' AS name,
        CAST(item ->> 'quantity' AS numeric) AS quantity,
        CAST(item ->> 'facings' AS numeric) AS h_facings,
        CAST(item ->> 'facingsRows' AS numeric) AS v_facings,
        CAST(shelf ->> 'depth' AS numeric) AS shelf_depth,
        CASE WHEN item ->> 'orientation' = 'FRONT' THEN
            CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                CAST(item ->> 'trayDepth' AS numeric)
            WHEN item ->> 'merchandisingStyle' = 'CASE' THEN
                CAST(item ->> 'caseDepth' AS numeric)
            ELSE
                CAST(item ->> 'unitDepth' AS numeric)
            END
        WHEN item ->> 'orientation' = 'SIDE' THEN
            CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                CAST(item ->> 'trayWidth' AS numeric)
            WHEN item ->> 'merchandisingStyle' = 'CASE' THEN
                CAST(item ->> 'caseWidth' AS numeric)
            ELSE
                CAST(item ->> 'unitWidth' AS numeric)
            END
        WHEN item ->> 'orientation' = 'TOP' THEN
            CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                CAST(item ->> 'trayHeight' AS numeric)
            WHEN item ->> 'merchandisingStyle' = 'CASE' THEN
                CAST(item ->> 'caseHeight' AS numeric)
            ELSE
                CAST(item ->> 'unitHeight' AS numeric)
            END
        ELSE
            NULL
        END AS p_depth
    FROM
        output_store_pog osp
        CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog AS jsonb) -> 'planogram' -> 'bays') AS bay
        CROSS JOIN LATERAL jsonb_array_elements(bay -> 'shelves') AS shelf
        CROSS JOIN LATERAL jsonb_array_elements(shelf -> 'items') AS item
    WHERE
        osp.base_pog_id = '{{bpid}}'
        AND osp.filter_config_id = '{{gen_id}}'
        AND osp.is_latest_version = TRUE
),
units_per_placement AS (
    SELECT
        gen_id,
        base_pog_id,
        store_code,
        product_code,
        name,
        quantity,
        h_facings * v_facings * FLOOR(shelf_depth / NULLIF (p_depth, 0)) AS units_on_shelf
    FROM
        placement_data
    WHERE
        p_depth IS NOT NULL
),
product_totals AS (
    SELECT
        gen_id,
        base_pog_id,
        store_code,
        product_code,
        name,
        AVG(quantity) AS weekly_quantity,
        SUM(units_on_shelf) AS total_units_on_shelf,
        CASE WHEN AVG(quantity) > 0 THEN
            (SUM(units_on_shelf) / AVG(quantity)) * 7
        END AS dos
    FROM
        units_per_placement
    GROUP BY
        gen_id,
        base_pog_id,
        store_code,
        product_code,
        name
)
SELECT
    gen_id,
    base_pog_id,
    store_code,
    product_code,
    name,
    CONCAT(store_code, '-', product_code) AS store_product_id,
    weekly_quantity,
    total_units_on_shelf,
    dos,
    CASE WHEN dos < 3 THEN
        1
    ELSE
        0
    END AS dos_lt_3,
    CASE WHEN dos < 1 THEN
        1
    ELSE
        0
    END AS dos_lt_1
FROM
    product_totals
