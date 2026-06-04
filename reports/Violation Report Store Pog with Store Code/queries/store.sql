WITH pog_raw_data_json AS (
    SELECT
        osp.filter_config_id,
        osp.base_pog_id,
        pm_elem ->> 'OOS' AS oos,
        pm_elem ->> 'store_code' AS store_code,
        pm_elem ->> 'product_code' AS product_code,
        CASE WHEN pm_elem ->> 'is_in_core_range' IN ('true', 'True', 'TRUE') THEN
            TRUE
        WHEN pm_elem ->> 'is_in_core_range' IN ('false', 'False', 'FALSE') THEN
            FALSE
        ELSE
            NULL -- Handle unexpected or missing values appropriately
        END AS core_range
    FROM
        output_store_pog osp
        -- Ensure that osp.pog_raw_data is of type jsonb; if it's json, cast it to jsonb
        CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog_raw_data AS jsonb) -> 'pm') AS pm_elem
    WHERE
        osp.filter_config_id = '{{gen_id}}'
        AND osp.base_pog_id = '{{bpid}}'
),
DistinctItems AS (
    SELECT DISTINCT
        osp.filter_config_id,
        osp.base_pog_id,
        osp.store AS store_code,
        item ->> 'productCode' AS product_code,
        CASE WHEN item ->> 'InCoreRange' IN ('true', 'True', 'TRUE') THEN
            TRUE
        WHEN item ->> 'InCoreRange' IN ('false', 'False', 'FALSE') THEN
            FALSE
        ELSE
            NULL
        END AS core_range,
        item ->> 'name' AS name,
        item ->> 'brand' AS brand,
        item ->> 'categoryCode' AS category_code,
        item ->> 'merchandisingStyle' AS merch_style_orig,
        CAST(item ->> 'noOfUnitsInTray' AS numeric) AS noOfUnitsInTray,
        CAST(item ->> 'noOfUnitsInCase' AS numeric) AS noOfUnitsInCase,
        CAST(item ->> 'quantity' AS numeric) AS quantity,
        CAST(item ->> 'facings' AS numeric) AS facings,
        --CAST(item->>'facingsRows' AS NUMERIC) AS facings_rows,
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
        ELSE
            NULL -- You can adjust this to handle cases where neither FRONT nor SIDE apply
        END AS p_depth
    FROM
        output_store_pog osp
        -- Ensure that osp.pog is of type jsonb; if it's json, cast it to jsonb
        CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog AS jsonb) -> 'planogram' -> 'bays') AS bay
        CROSS JOIN LATERAL jsonb_array_elements(bay -> 'shelves') AS shelf
        CROSS JOIN LATERAL jsonb_array_elements(shelf -> 'items') AS item
    WHERE
        osp.filter_config_id = '{{gen_id}}'
        AND osp.base_pog_id = '{{bpid}}'
),
AggregatedItems AS (
    SELECT
        filter_config_id AS gen_id,
        base_pog_id,
        store_code,
        product_code,
        core_range,
        name,
        brand,
        category_code,
        merch_style_orig,
        SUM(noOfUnitsInTray) AS noOfUnitsInTray,
        SUM(noOfUnitsInCase) AS noOfUnitsInCase,
        AVG(quantity) AS quantity,
        p_depth,
        SUM(facings) AS total_facings,
        AVG(shelf_depth) AS shelf_depth,
        SUM(
            CASE WHEN merch_style_orig = 'TRAY' THEN
                noOfUnitsInTray
            WHEN merch_style_orig = 'CASE' THEN
                noOfUnitsInCase
            ELSE
                1
            END) AS case_total_number,
        AVG(FLOOR(shelf_depth / p_depth)) AS units_deep,
        SUM(FLOOR(shelf_depth / p_depth) * facings * (
                CASE WHEN merch_style_orig = 'TRAY' THEN
                    noOfUnitsInTray
                WHEN merch_style_orig = 'CASE' THEN
                    noOfUnitsInCase
                ELSE
                    1
                END)) AS uos1,
        SUM(((FLOOR(shelf_depth / p_depth) * facings * (
                CASE WHEN merch_style_orig = 'TRAY' THEN
                    noOfUnitsInTray
                WHEN merch_style_orig = 'CASE' THEN
                    noOfUnitsInCase
                ELSE
                    1
                END)) / quantity) * 7) AS dos1
    FROM
        DistinctItems
    GROUP BY
        filter_config_id,
        base_pog_id,
        store_code,
        product_code,
        core_range,
        name,
        brand,
        category_code,
        merch_style_orig,
        p_depth
)
SELECT
    ai.*,
    CASE WHEN ai.uos1 < ai.case_total_number THEN
        1
    ELSE
        0
    END AS less_than_case_flag,
    CASE WHEN ai.uos1 < 1.25 * ai.case_total_number THEN
        1
    ELSE
        0
    END AS less_than_case_mpl_flag,
    CASE WHEN ai.dos1 < 3 THEN
        1
    ELSE
        0
    END AS dos_lt_3,
    CASE WHEN ai.dos1 < 1 THEN
        1
    ELSE
        0
    END AS dos_gt_50,
    prd.store_code AS storecode2,
    EXISTS (
        SELECT
            1
        FROM
            pog_raw_data_json prd2
        WHERE
            prd2.base_pog_id = ai.base_pog_id
            AND prd2.store_code = ai.store_code
            AND prd2.product_code = ai.product_code) AS exist_in_pog
FROM
    AggregatedItems ai
    LEFT JOIN pog_raw_data_json prd ON ai.base_pog_id = prd.base_pog_id
        AND ai.store_code = prd.store_code
        AND ai.product_code = prd.product_code
