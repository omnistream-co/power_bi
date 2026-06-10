SELECT
    item_details.gen_id,
    item_details.shelf_count,
    item_details.base_pog_id,
    --item_details.store_code,
    FALSE AS exist_in_pog,
    item_details.facingsRows,
    core_range,
    item_details.shelf,
    item_details.product_code,
    item_details.name,
    item_details.brand,
    item_details.category_code,
    item_details.merch_style_orig,
    item_details.case_total_number,
    item_details.quantity,
    item_details.facings,
    item_details.p_depth,
    item_details.noOfUnitsInTray,
    item_details.noOfUnitsInCase,
    item_details.unitDepth,
    item_details.Orientation,
    item_details.units_deep_2,
    item_details.shelf_depth,
    item_details.units_deep,
    item_details.uos1,
    item_details.dos1,
    CASE WHEN item_details.uos1 < CASE WHEN item_details.merch_style_orig != 'UNIT' THEN
        CASE WHEN item_details.noOfUnitsInTray > 0 THEN
            item_details.noOfUnitsInTray
        WHEN item_details.noOfUnitsInCase > 0 THEN
            item_details.noOfUnitsInCase
        ELSE
            1
        END
    ELSE
        item_details.case_total_number
    END THEN
        1
    ELSE
        0
    END AS less_than_case_flag,
    CASE WHEN item_details.uos1 < 1.25 * CASE WHEN item_details.merch_style_orig != 'UNIT' THEN
        CASE WHEN item_details.noOfUnitsInTray > 0 THEN
            item_details.noOfUnitsInTray
        WHEN item_details.noOfUnitsInCase > 0 THEN
            item_details.noOfUnitsInCase
        ELSE
            1
        END
    ELSE
        item_details.case_total_number
    END THEN
        1
    ELSE
        0
    END AS less_than_case_mpl_flag,
    CASE WHEN item_details.dos1 < 2 THEN
        1
    ELSE
        0
    END AS dos_lt_3,
    CASE WHEN item_details.dos1 < 1 THEN
        1
    ELSE
        0
    END AS dos_gt_50
FROM (
    SELECT
        osp.filter_config_id AS gen_id,
        osp.id AS base_pog_id,
        --osp.store AS store_code,
        item ->> 'productCode' AS product_code,
        item ->> 'facingsRows' AS facingsRows,
        CASE WHEN item ->> 'InCoreRange' = 'true' THEN
            TRUE
        ELSE
            FALSE
        END AS core_range,
        item ->> 'name' AS name,
        item ->> 'orientation' AS Orientation,
        item ->> 'brand' AS brand,
        item ->> 'shelf' AS shelf,
        item ->> 'categoryCode' AS category_code,
        item ->> 'merchandisingStyle' AS merch_style_orig,
        COUNT(DISTINCT item ->> 'shelf') AS shelf_count,
        SUM(CAST(item ->> 'noOfUnitsInTray' AS numeric)) AS noOfUnitsInTray,
        SUM(CAST(item ->> 'noOfUnitsInCase' AS numeric)) AS noOfUnitsInCase,
        AVG(CAST(item ->> 'quantity' AS numeric)) AS quantity,
        CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
            CAST(item ->> 'trayDepth' AS numeric)
        WHEN item ->> 'merchandisingStyle' = 'CASE' THEN
            CAST(item ->> 'caseDepth' AS numeric)
        ELSE
            CAST(item ->> 'unitDepth' AS numeric)
        END AS p_depth,
        SUM(
            CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                CAST(item ->> 'noOfUnitsInTray' AS numeric)
            WHEN item ->> 'merchandisingStyle' = 'CASE' THEN
                CAST(item ->> 'noOfUnitsInCase' AS numeric)
            ELSE
                1
            END) AS case_total_number,
        SUM(CAST(item ->> 'facings' AS numeric)) AS facings,
        AVG(CAST(shelf ->> 'depth' AS numeric)) AS shelf_depth,
        AVG(CAST(item ->> 'unitDepth' AS numeric)) AS unitDepth,
        AVG(FLOOR(CAST(shelf ->> 'depth' AS numeric) / CASE WHEN item ->> 'orientation' = 'FRONT' THEN
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
                END)) AS units_deep_2,
        AVG(FLOOR(CAST(shelf ->> 'depth' AS numeric) / (
                    CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                        CAST(item ->> 'trayDepth' AS numeric)
                    WHEN item ->> 'merchandisingStyle' = 'CASE' THEN
                        CAST(item ->> 'caseDepth' AS numeric)
                    ELSE
                        CAST(item ->> 'unitDepth' AS numeric)
                    END))) AS units_deep, --        FLOOR(efd.shelf_depth / epm.p_depth) AS units_deep,
        AVG(FLOOR(CAST(shelf ->> 'depth' AS numeric) / (
                    CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                        CAST(item ->> 'trayDepth' AS numeric)
                    WHEN item ->> 'merchandisingStyle' = 'CASE' THEN
                        CAST(item ->> 'caseDepth' AS numeric)
                    ELSE
                        CAST(item ->> 'unitDepth' AS numeric)
                    END)) * CAST(item ->> 'facings' AS numeric) * (
                CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                    CAST(item ->> 'noOfUnitsInTray' AS numeric)
                WHEN item ->> 'merchandisingStyle' = 'CASE' THEN
                    CAST(item ->> 'noOfUnitsInCase' AS numeric)
                ELSE
                    1
                END)) AS uos1, --  FLOOR(efd.shelf_depth / epm.p_depth) * epd.total_facings) * facings_rows * units_in_caseortrayor1  as uos1
        -- SUM(CAST(item ->> 'noOfUnitsInCase' AS NUMERIC))  AS uos1, --  FLOOR(efd.shelf_depth / epm.p_depth) * epd.total_facings) * facings_rows * units_in_caseortrayor1  as uos1
        AVG((FLOOR(CAST(shelf ->> 'depth' AS numeric) / (
                    CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                        CAST(item ->> 'trayDepth' AS numeric)
                    WHEN item ->> 'merchandisingStyle' = 'CASE' THEN
                        CAST(item ->> 'caseDepth' AS numeric)
                    ELSE
                        CAST(item ->> 'unitDepth' AS numeric)
                    END)) * CAST(item ->> 'facings' AS numeric) * (
                CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                    CAST(item ->> 'noOfUnitsInTray' AS numeric)
                WHEN item ->> 'merchandisingStyle' = 'CASE' THEN
                    CAST(item ->> 'noOfUnitsInCase' AS numeric)
                ELSE
                    1
                END)) / CAST(item ->> 'quantity' AS numeric)) * 7 AS dos1 --         (uos1 / epm.quantity * 7 AS dos1,
    FROM
        base_pog osp
    CROSS JOIN LATERAL jsonb_array_elements(osp.pog_data -> 'planogram' -> 'bays') AS bays (bay)
    CROSS JOIN LATERAL jsonb_array_elements(bay -> 'shelves') AS shelf
    CROSS JOIN LATERAL jsonb_array_elements(shelf -> 'items') AS item
WHERE
    osp.id = '{{bpid}}'
    AND osp.filter_config_id = '{{gen_id}}'
GROUP BY
    osp.filter_config_id,
    osp.id,
    --osp.store,
    item ->> 'productCode',
    core_range,
    item ->> 'name',
    item ->> 'shelf',
    item ->> 'brand',
    item ->> 'categoryCode',
    item ->> 'orientation',
    item ->> 'merchandisingStyle',
    item ->> 'facingsRows',
    p_depth) AS item_details
