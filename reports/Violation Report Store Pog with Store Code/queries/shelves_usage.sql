WITH unrangedData AS (
    SELECT DISTINCT
        osp.id,
        osp.filter_config_id,
        osp.base_pog_id,
        osp.store AS store_code,
        osp.status AS store_status,
        item ->> 'productCode' AS product_code,
        CAST(0 AS numeric) AS total_facings_rows,
        CAST(0 AS numeric) AS facings_rows,
        CAST(0 AS numeric) AS facings,
        CAST(item ->> 'price' AS numeric) AS price,
        CAST(item ->> 'profit' AS numeric) AS profit,
        item ->> 'name' AS name,
        item ->> 'cdt1' AS cdt1,
        item ->> 'cdt2' AS cdt2,
        item ->> 'cdt3' AS cdt3,
        item ->> 'minFacings' AS minFacings,
        item ->> 'variant' AS variant,
        item ->> 'inCoreRange' AS core_range,
        item ->> 'brand' AS brand,
        item ->> 'categoryCode' AS category_code,
        CAST(item ->> 'salesAmount' AS numeric) AS salesAmount,
        item ->> 'merchandisingStyle' AS merch_style_orig,
        CAST(item ->> 'quantity' AS numeric) AS quantity,
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
            NULL
        END AS p_depth,
        CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
            CAST(item ->> 'trayDepth' AS numeric)
        WHEN item ->> 'merchandisingStyle' = 'UNIT' THEN
            CAST(item ->> 'unitDepth' AS numeric)
        ELSE
            CAST(item ->> 'caseDepth' AS numeric)
        END AS merch_depth,
        CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
            CAST(item ->> 'trayWidth' AS numeric)
        WHEN item ->> 'merchandisingStyle' = 'UNIT' THEN
            CAST(item ->> 'unitWidth' AS numeric)
        ELSE
            CAST(item ->> 'caseWidth' AS numeric)
        END AS merch_width,
        CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
            CAST(item ->> 'trayHeight' AS numeric)
        WHEN item ->> 'merchandisingStyle' = 'UNIT' THEN
            CAST(item ->> 'unitHeight' AS numeric)
        ELSE
            CAST(item ->> 'caseHeight' AS numeric)
        END AS merch_height,
        item ->> 'shelf' AS shelf_id
    FROM
        output_store_pog osp
        CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog AS jsonb) -> 'unrangedItems') AS item
    WHERE
        osp.base_pog_id = '{{bpid}}'
        AND osp.filter_config_id = '{{gen_id}}'
        AND osp.is_latest_version = TRUE
),
pog_raw_data_json AS (
    SELECT
        osp.id,
        osp.filter_config_id,
        osp.base_pog_id,
        pm_elem ->> 'OOS' AS oos,
        pm_elem ->> 'store_code' AS store_code,
        pm_elem ->> 'product_code' AS product_code
    FROM
        output_store_pog osp
        CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog_raw_data AS jsonb) -> 'pm') AS pm_elem
    WHERE
        osp.base_pog_id = '{{bpid}}'
        AND osp.filter_config_id = '{{gen_id}}'
        AND osp.is_latest_version = TRUE
),
planogram_data AS (
    SELECT
        osp.id,
        osp.store AS store_code,
        CAST(FLOOR(CAST(bay ->> 'bayNo' AS numeric)) AS integer) AS planogram_bays_bayNo,
        CAST(shelf_element ->> 'width' AS numeric) AS planogram_bays_shelves_width,
        CAST(shelf_element ->> 'depth' AS numeric) AS planogram_bays_shelves_depth,
        shelf_index AS planogram_bays_shelves_shelfNo,
        COALESCE((
            SELECT
                items.value ->> 'shelf'
            FROM jsonb_array_elements(shelf_element -> 'items')
            WITH ORDINALITY AS items (value, idx)
        ORDER BY items.idx LIMIT 1), CONCAT(osp.id, '_', bay ->> 'bayNo', '_', shelf_index)) AS shelf_id
        FROM
            output_store_pog osp
        CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog AS jsonb) -> 'planogram' -> 'bays') AS bay
        CROSS JOIN LATERAL jsonb_array_elements(bay -> 'shelves')
        WITH ORDINALITY AS shelf (shelf_element, shelf_index)
    WHERE
        osp.base_pog_id = '{{bpid}}'
        AND osp.filter_config_id = '{{gen_id}}'
        AND osp.is_latest_version = TRUE
),
DistinctItems AS (
    SELECT DISTINCT
        di.*,
        pd.planogram_bays_bayNo,
        pd.planogram_bays_shelves_width,
        pd.planogram_bays_shelves_depth,
        pd.planogram_bays_shelves_shelfNo,
        COALESCE(di.shelf_id_orig, pd.shelf_id) AS shelf_id
    FROM ( SELECT DISTINCT
            osp.id,
            osp.filter_config_id,
            osp.base_pog_id,
            osp.store AS store_code,
            osp.status AS store_status,
            item ->> 'productCode' AS product_code,
            item ->> 'inCoreRange' AS core_range,
            CAST(item ->> 'price' AS numeric) AS price,
            CAST(item ->> 'profit' AS numeric) AS profit,
            item ->> 'name' AS name,
            item ->> 'cdt1' AS cdt1,
            item ->> 'cdt2' AS cdt2,
            item ->> 'cdt3' AS cdt3,
            item ->> 'minFacings' AS minFacings,
            item ->> 'variant' AS variant,
            item ->> 'brand' AS brand,
            item ->> 'categoryCode' AS category_code,
            CAST(item ->> 'salesAmount' AS numeric) AS salesAmount,
            item ->> 'merchandisingStyle' AS merch_style_orig,
            CAST(item ->> 'noOfUnitsInTray' AS numeric) AS noOfUnitsInTray,
            CAST(item ->> 'noOfUnitsInCase' AS numeric) AS noOfUnitsInCase,
            CAST(item ->> 'quantity' AS numeric) AS quantity,
            CAST(item ->> 'facings' AS numeric) AS facings,
            CAST(item ->> 'facingsRows' AS numeric) AS facings_rows,
            CAST(item ->> 'facings' AS numeric) * CAST(item ->> 'facingsRows' AS numeric) AS total_facings_rows,
            CAST(shelf ->> 'depth' AS numeric) AS shelf_depth,
            CAST(shelf ->> 'width' AS numeric) AS shelf_width,
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
                NULL
            END AS p_depth,
            CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                CAST(item ->> 'trayDepth' AS numeric)
            WHEN item ->> 'merchandisingStyle' = 'UNIT' THEN
                CAST(item ->> 'unitDepth' AS numeric)
            ELSE
                CAST(item ->> 'caseDepth' AS numeric)
            END AS merch_depth,
            CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                CAST(item ->> 'trayWidth' AS numeric)
            WHEN item ->> 'merchandisingStyle' = 'UNIT' THEN
                CAST(item ->> 'unitWidth' AS numeric)
            ELSE
                CAST(item ->> 'caseWidth' AS numeric)
            END AS merch_width,
            CASE WHEN item ->> 'merchandisingStyle' = 'TRAY' THEN
                CAST(item ->> 'trayHeight' AS numeric)
            WHEN item ->> 'merchandisingStyle' = 'UNIT' THEN
                CAST(item ->> 'unitHeight' AS numeric)
            ELSE
                CAST(item ->> 'caseHeight' AS numeric)
            END AS merch_height,
            item ->> 'shelf' AS shelf_id_orig
        FROM
            output_store_pog osp
        CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog AS jsonb) -> 'planogram' -> 'bays') AS bay
        CROSS JOIN LATERAL jsonb_array_elements(bay -> 'shelves') AS shelf
        CROSS JOIN LATERAL jsonb_array_elements(shelf -> 'items') AS item
    WHERE
        osp.base_pog_id = '{{bpid}}'
        AND osp.filter_config_id = '{{gen_id}}'
        AND osp.is_latest_version = TRUE) di
    LEFT JOIN planogram_data pd ON di.store_code = pd.store_code
        AND di.shelf_id_orig = pd.shelf_id
),
ProductsPerShelf AS (
    SELECT DISTINCT
        base_pog_id,
        store_code,
        shelf_id,
        COUNT(*) OVER (PARTITION BY base_pog_id,
            store_code,
            shelf_id) AS products_per_shelf
    FROM
        DistinctItems
),
AggregatedItems AS (
    SELECT
        di.filter_config_id AS gen_id,
        'Y' AS Ranged,
        di.store_status,
        di.merch_height,
        di.merch_width,
        di.merch_depth,
        di.base_pog_id,
        di.store_code,
        di.product_code,
        di.core_range,
        AVG(di.price) AS price,
        SUM(di.profit) AS profit,
        di.name,
        di.cdt1,
        di.cdt2,
        di.cdt3,
        di.minFacings,
        di.brand,
        di.variant,
        di.category_code,
        di.merch_style_orig,
        SUM(di.noOfUnitsInTray) AS noOfUnitsInTray,
        SUM(di.noOfUnitsInCase) AS noOfUnitsInCase,
        AVG(di.quantity) AS quantity,
        di.p_depth,
        SUM(di.facings) AS total_facings,
        AVG(di.facings) AS facings,
        SUM(di.facings_rows) AS facings_rows,
        SUM(di.salesAmount) AS salesAmount,
        AVG(di.shelf_depth) AS shelf_depth,
        AVG(di.shelf_width) AS shelf_width,
        STRING_AGG(DISTINCT di.shelf_id, ', ') AS shelf_ids,
        MAX(pps.products_per_shelf) AS products_per_shelf,
        SUM(
            CASE WHEN di.merch_style_orig = 'TRAY' THEN
                di.noOfUnitsInTray
            WHEN di.merch_style_orig = 'CASE' THEN
                di.noOfUnitsInCase
            ELSE
                1
            END) AS case_total_number,
        AVG(FLOOR(di.shelf_depth / di.p_depth)) AS units_deep,
        SUM(FLOOR(di.shelf_depth / di.p_depth) * di.facings * (
                CASE WHEN di.merch_style_orig = 'TRAY' THEN
                    di.noOfUnitsInTray
                WHEN di.merch_style_orig = 'CASE' THEN
                    di.noOfUnitsInCase
                ELSE
                    1
                END)) AS uos1,
        SUM(((FLOOR(di.shelf_depth / di.p_depth) * di.facings * (
                CASE WHEN di.merch_style_orig = 'TRAY' THEN
                    di.noOfUnitsInTray
                WHEN di.merch_style_orig = 'CASE' THEN
                    di.noOfUnitsInCase
                ELSE
                    1
                END)) / di.quantity) * 7) AS dos1,
        MAX(di.planogram_bays_bayNo) AS planogram_bays_bayNo,
        MAX(di.planogram_bays_shelves_width) AS planogram_bays_shelves_width,
        MAX(di.planogram_bays_shelves_depth) AS planogram_bays_shelves_depth,
        MAX(di.planogram_bays_shelves_shelfNo) AS planogram_bays_shelves_shelfNo
    FROM
        DistinctItems di
    LEFT JOIN ProductsPerShelf pps ON di.base_pog_id = pps.base_pog_id
        AND di.store_code = pps.store_code
        AND di.shelf_id = pps.shelf_id
GROUP BY
    di.filter_config_id,
    di.store_status,
    di.merch_height,
    di.merch_width,
    di.merch_depth,
    di.base_pog_id,
    di.store_code,
    di.product_code,
    di.core_range,
    di.name,
    di.brand,
    di.category_code,
    di.merch_style_orig,
    di.p_depth,
    di.cdt1,
    di.cdt2,
    di.cdt3,
    di.minFacings,
    di.variant
),
combined_data AS (
    SELECT
        ai.gen_id,
        ai.Ranged,
        ai.store_status,
        ai.merch_height,
        ai.merch_width,
        ai.merch_depth,
        ai.base_pog_id,
        ai.store_code,
        ai.product_code,
        ai.core_range,
        ai.price,
        ai.profit,
        ai.name,
        ai.cdt1,
        ai.cdt2,
        ai.cdt3,
        ai.minFacings,
        ai.brand,
        ai.variant,
        ai.category_code,
        ai.merch_style_orig,
        ai.noOfUnitsInTray,
        ai.noOfUnitsInCase,
        ai.quantity,
        ai.p_depth,
        ai.total_facings,
        ai.facings,
        ai.facings_rows,
        ai.salesAmount,
        ai.shelf_depth,
        ai.shelf_width,
        ai.shelf_ids,
        ai.products_per_shelf,
        ai.case_total_number,
        ai.units_deep,
        ai.uos1,
        ai.dos1,
        CONCAT(ai.store_code, '-', ai.variant, '-', ai.cdt1) AS rank_key,
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
        CASE WHEN ai.facings * ai.facings_rows < CAST(ai.minFacings AS numeric) THEN
            1
        ELSE
            0
        END AS less_than_min_facings_flag,
        EXISTS (
            SELECT
                1
            FROM
                pog_raw_data_json prd2
            WHERE
                prd2.base_pog_id = ai.base_pog_id
                AND prd2.store_code = ai.store_code
                AND prd2.product_code = ai.product_code) AS exist_in_pog,
            CAST(ai.planogram_bays_bayNo AS integer) AS planogram_bays_bayNo,
            CAST(ai.planogram_bays_shelves_width AS numeric) AS planogram_bays_shelves_width,
            CAST(ai.planogram_bays_shelves_depth AS numeric) AS planogram_bays_shelves_depth,
            CAST(ai.planogram_bays_shelves_shelfNo AS integer) AS planogram_bays_shelves_shelfNo
        FROM
            AggregatedItems ai
        LEFT JOIN pog_raw_data_json prd ON ai.base_pog_id = prd.base_pog_id
            AND ai.store_code = prd.store_code
            AND ai.product_code = prd.product_code
        UNION ALL
        SELECT
            ud.filter_config_id AS gen_id,
            'N' AS Ranged,
            ud.store_status,
            ud.merch_height,
            ud.merch_width,
            ud.merch_depth,
            ud.base_pog_id,
            ud.store_code,
            ud.product_code,
            ud.core_range,
            ud.price,
            ud.profit,
            ud.name,
            ud.cdt1,
            ud.cdt2,
            ud.cdt3,
            ud.minFacings,
            ud.brand,
            ud.variant,
            ud.category_code,
            ud.merch_style_orig,
            CAST(NULL AS numeric) AS noOfUnitsInTray,
            CAST(NULL AS numeric) AS noOfUnitsInCase,
            ud.quantity,
            ud.p_depth,
            CAST(NULL AS numeric) AS total_facings,
            CAST(ud.facings AS numeric) AS facings,
            CAST(ud.facings_rows AS numeric) AS facings_rows,
            ud.salesAmount,
            CAST(NULL AS numeric) AS shelf_depth,
            CAST(NULL AS numeric) AS shelf_width,
            ud.shelf_id AS shelf_ids,
            1 AS products_per_shelf,
            CAST(NULL AS numeric) AS case_total_number,
            CAST(NULL AS numeric) AS units_deep,
            CAST(NULL AS numeric) AS uos1,
            CAST(NULL AS numeric) AS dos1,
            CONCAT(ud.store_code, '-', ud.variant, '-', ud.cdt1) AS rank_key,
            0 AS less_than_case_flag,
            0 AS less_than_case_mpl_flag,
            0 AS dos_lt_3,
            0 AS dos_gt_50,
            CASE WHEN CAST(ud.facings AS numeric) * CAST(ud.facings_rows AS numeric) < CAST(ud.minFacings AS numeric) THEN
                1
            ELSE
                0
            END AS less_than_min_facings_flag,
            FALSE AS exist_in_pog,
            CAST(NULL AS integer) AS planogram_bays_bayNo,
            CAST(NULL AS numeric) AS planogram_bays_shelves_width,
            CAST(NULL AS numeric) AS planogram_bays_shelves_depth,
            CAST(NULL AS integer) AS planogram_bays_shelves_shelfNo
        FROM
            unrangedData ud
),
MinWidthCTE AS (
    SELECT
        variant,
        cdt1,
        MIN(
            CASE WHEN facings = 0 THEN
                merch_width
            END) AS min_merch_width_zero_facings,
        MIN(merch_width) AS min_merch_width_all
    FROM
        combined_data -- Changed from final_data to combined_data
GROUP BY
    variant,
    cdt1
),
final_data_with_min_width AS (
    SELECT
        cd.*, -- Changed from fd.* to cd.*
        COALESCE(mw.min_merch_width_zero_facings, cd.merch_width) AS min_width_for_variant_cdt1_zero_facings,
        COALESCE(mw.min_merch_width_all, cd.merch_width) AS min_width_for_variant_cdt1_all
    FROM
        combined_data cd -- Changed from final_data to combined_data
        LEFT JOIN MinWidthCTE mw ON cd.variant = mw.variant
            AND cd.cdt1 = mw.cdt1
),
shelf_agg AS (
    -- v2: compute variant/cdt1 string-aggs for ALL shelves in ONE grouped pass,
    -- replacing the per-shelf correlated subqueries (6649 x 2 full scans of DistinctItems).
    SELECT
        store_code,
        shelf_id,
        STRING_AGG(DISTINCT variant, ',') AS variant,
        STRING_AGG(DISTINCT cdt1, ',') AS cdt1
    FROM
        DistinctItems
GROUP BY
    store_code,
    shelf_id
),
shelf_classification AS (
    SELECT DISTINCT
        pd.store_code,
        pd.shelf_id AS shelf_ids,
        CONCAT(pd.store_code, '-', pd.shelf_id) AS shelf_unique_id,
        COALESCE(sa.variant, 'EMPTY') AS variant,
        COALESCE(sa.cdt1, 'EMPTY') AS cdt1
    FROM
        planogram_data pd
        LEFT JOIN shelf_agg sa ON sa.store_code = pd.store_code
            AND sa.shelf_id = pd.shelf_id
),
min_width_cdt1_floating AS (
    SELECT
        shelf_ids,
        MIN(min_width_for_variant_cdt1_zero_facings) AS min_width_on_cdt1_floating_shelf
    FROM
        final_data_with_min_width
    WHERE
        shelf_ids IS NOT NULL
    GROUP BY
        shelf_ids
),
min_width_cdt1_all AS (
    SELECT
        shelf_ids,
        MIN(min_width_for_variant_cdt1_all) AS min_width_on_cdt1
    FROM
        final_data_with_min_width
    WHERE
        shelf_ids IS NOT NULL
    GROUP BY
        shelf_ids
),
shelf_data AS (
    SELECT
        pd.store_code,
        pd.shelf_id AS shelf_ids,
        CONCAT(pd.store_code, '-', pd.shelf_id) AS shelf_unique_id,
        pd.planogram_bays_bayNo,
        pd.planogram_bays_shelves_width,
        pd.planogram_bays_shelves_shelfNo,
        pd.planogram_bays_shelves_depth,
        LEAST ( -- Add LEAST to cap at shelf width
            pd.planogram_bays_shelves_width, COALESCE(SUM(
                    CASE WHEN fdwm.facings_rows = 0 THEN
                        0
                    ELSE
                        COALESCE(fdwm.facings * fdwm.merch_width, -- Changed calculation
                            0)
                    END), 0)) AS width_occupied
    FROM
        planogram_data pd
        LEFT JOIN final_data_with_min_width fdwm ON pd.store_code = fdwm.store_code
            AND pd.shelf_id = fdwm.shelf_ids
    GROUP BY
        pd.store_code,
        pd.shelf_id,
        pd.planogram_bays_bayNo,
        pd.planogram_bays_shelves_width,
        pd.planogram_bays_shelves_shelfNo,
        pd.planogram_bays_shelves_depth
),
final_shelf_data AS (
    SELECT
        sd.shelf_unique_id,
        sd.store_code,
        sd.shelf_ids,
        sd.planogram_bays_bayNo,
        sd.planogram_bays_shelves_width,
        sd.planogram_bays_shelves_shelfNo,
        sd.planogram_bays_shelves_depth,
        sd.width_occupied,
        sc.variant,
        sc.cdt1,
        mwf.min_width_on_cdt1_floating_shelf,
        mwa.min_width_on_cdt1,
        sd.planogram_bays_shelves_width - sd.width_occupied AS linear_shelf_space_available,
        CASE WHEN sd.planogram_bays_shelves_width - sd.width_occupied > mwf.min_width_on_cdt1_floating_shelf
            AND mwf.min_width_on_cdt1_floating_shelf > 0 THEN
            1
        ELSE
            0
        END AS flag_floating_shelf,
        CASE WHEN sd.planogram_bays_shelves_width - sd.width_occupied > mwa.min_width_on_cdt1
            AND mwa.min_width_on_cdt1 = 0 THEN
            1
        ELSE
            0
        END AS flag,
        CASE WHEN sd.planogram_bays_shelves_width - sd.width_occupied > mwf.min_width_on_cdt1_floating_shelf THEN
            1
        ELSE
            0
        END AS potential_floating_shelf,
        1.0 / COUNT(*) OVER (PARTITION BY sd.store_code,
            CASE WHEN sd.planogram_bays_shelves_width - sd.width_occupied > mwf.min_width_on_cdt1_floating_shelf
                AND mwf.min_width_on_cdt1_floating_shelf > 0 THEN
                1
            ELSE
                0
            END) AS count_stores_floating_shelf,
        COUNT(*) OVER (PARTITION BY sd.store_code,
            CASE WHEN sd.planogram_bays_shelves_width - sd.width_occupied > mwf.min_width_on_cdt1_floating_shelf
                AND mwf.min_width_on_cdt1_floating_shelf > 0 THEN
                1
            ELSE
                0
            END) AS count_shelves_floating_shelf,
        1.0 / COUNT(*) OVER (PARTITION BY sd.store_code,
            CASE WHEN sd.planogram_bays_shelves_width - sd.width_occupied > mwa.min_width_on_cdt1
                AND mwa.min_width_on_cdt1 = 0 THEN
                1
            ELSE
                0
            END) AS count_stores,
        COUNT(*) OVER (PARTITION BY sd.store_code,
            CASE WHEN sd.planogram_bays_shelves_width - sd.width_occupied > mwa.min_width_on_cdt1
                AND mwa.min_width_on_cdt1 = 0 THEN
                1
            ELSE
                0
            END) AS count_shelves
    FROM
        shelf_data sd
        LEFT JOIN min_width_cdt1_floating mwf ON sd.shelf_ids = mwf.shelf_ids
        LEFT JOIN min_width_cdt1_all mwa ON sd.shelf_ids = mwa.shelf_ids
        LEFT JOIN shelf_classification sc ON sd.shelf_unique_id = sc.shelf_unique_id
)
SELECT
    *
FROM
    final_shelf_data
ORDER BY
    store_code,
    planogram_bays_bayNo,
    planogram_bays_shelves_shelfNo
