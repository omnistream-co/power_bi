WITH unrangedData AS (
    SELECT DISTINCT
        osp.id,
        osp.filter_config_id,
        osp.base_pog_id,
        osp.store AS store_code,
        osp.status AS store_status,
        item->>'productCode' AS product_code,
        CAST(0 AS NUMERIC) AS total_facings_rows,
        CAST(0 AS NUMERIC) AS facings_rows,
        CAST(0 AS NUMERIC) AS facings,
        CAST(item->>'price' AS NUMERIC) AS price,
        CAST(item->>'profit' AS NUMERIC) AS profit,
        item->>'name' AS name,
        item->>'cdt1' AS cdt1,
        item->>'cdt2' AS cdt2,
        item->>'cdt3' AS cdt3,
        item->>'minFacings' AS minFacings,
        item->>'variant' AS variant,
        item->>'inCoreRange' AS core_range,
        item->>'brand' AS brand,
        item->>'categoryCode' AS category_code,
        CAST(item->>'salesAmount' AS NUMERIC) AS salesAmount,
        item->>'merchandisingStyle' AS merch_style_orig,
        CAST(item->>'quantity' AS NUMERIC) AS quantity,
        CASE
            WHEN item->>'orientation' = 'FRONT' THEN
                CASE
                    WHEN item->>'merchandisingStyle' = 'TRAY' THEN CAST(item->>'trayDepth' AS NUMERIC)
                    WHEN item->>'merchandisingStyle' = 'CASE' THEN CAST(item->>'caseDepth' AS NUMERIC)
                    ELSE CAST(item->>'unitDepth' AS NUMERIC)
                END
            WHEN item->>'orientation' = 'SIDE' THEN
                CASE
                    WHEN item->>'merchandisingStyle' = 'TRAY' THEN CAST(item->>'trayWidth' AS NUMERIC)
                    WHEN item->>'merchandisingStyle' = 'CASE' THEN CAST(item->>'caseWidth' AS NUMERIC)
                    ELSE CAST(item->>'unitWidth' AS NUMERIC)
                END
            ELSE NULL
        END AS p_depth,
        CASE
            WHEN item->>'merchandisingStyle' = 'TRAY' THEN CAST(item->>'trayDepth' AS NUMERIC)
            WHEN item->>'merchandisingStyle' = 'UNIT' THEN CAST(item->>'unitDepth' AS NUMERIC)
            ELSE CAST(item->>'caseDepth' AS NUMERIC)
        END as merch_depth,
        CASE
            WHEN item->>'merchandisingStyle' = 'TRAY' THEN CAST(item->>'trayWidth' AS NUMERIC)
            WHEN item->>'merchandisingStyle' = 'UNIT' THEN CAST(item->>'unitWidth' AS NUMERIC)
            ELSE CAST(item->>'caseWidth' AS NUMERIC)
        END as merch_width,
        CASE
            WHEN item->>'merchandisingStyle' = 'TRAY' THEN CAST(item->>'trayHeight' AS NUMERIC)
            WHEN item->>'merchandisingStyle' = 'UNIT' THEN CAST(item->>'unitHeight' AS NUMERIC)
            ELSE CAST(item->>'caseHeight' AS NUMERIC)
        END as merch_height,
        item->>'shelf' AS shelf_id
    FROM
        output_store_pog osp
    CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog AS jsonb) -> 'unrangedItems') AS item
    WHERE osp.base_pog_id = '{{bpid}}'  AND osp.filter_config_id = '{{gen_id}}'  AND osp.is_latest_version = TRUE
),
pog_raw_data_json AS (
    SELECT
        osp.id,
        osp.filter_config_id,
        osp.base_pog_id,
        pm_elem->>'OOS' AS oos,
        pm_elem->>'store_code' AS store_code,
        pm_elem->>'product_code' AS product_code
    FROM
        output_store_pog osp
    CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog_raw_data AS jsonb) -> 'pm') AS pm_elem
    WHERE osp.base_pog_id = '{{bpid}}'  AND osp.filter_config_id = '{{gen_id}}'  AND osp.is_latest_version = TRUE
),
DistinctItems AS (
    -- v2: planogram_data CTE removed; its bay/shelf columns are computed inline here
    -- (bay + shelf are already in scope during the item expansion). WITH ORDINALITY
    -- on shelves gives planogram_bays_shelves_shelfNo. No join -> no sort -> no temp spill.
    SELECT DISTINCT
        osp.id,
        osp.filter_config_id,
        osp.base_pog_id,
        osp.store AS store_code,
        osp.status AS store_status,
        item->>'productCode' AS product_code,
        item->>'inCoreRange' AS core_range,
        CAST(item->>'price' AS NUMERIC) AS price,
        CAST(item->>'profit' AS NUMERIC) AS profit,
        item->>'name' AS name,
        item->>'cdt1' AS cdt1,
        item->>'cdt2' AS cdt2,
        item->>'cdt3' AS cdt3,
        item->>'minFacings' AS minFacings,
        item->>'variant' AS variant,
        item->>'brand' AS brand,
        item->>'categoryCode' AS category_code,
        CAST(item->>'salesAmount' AS NUMERIC) AS salesAmount,
        item->>'merchandisingStyle' AS merch_style_orig,
        CAST(item->>'noOfUnitsInTray' AS NUMERIC) AS noOfUnitsInTray,
        CAST(item->>'noOfUnitsInCase' AS NUMERIC) AS noOfUnitsInCase,
        CAST(item->>'quantity' AS NUMERIC) AS quantity,
        CAST(item->>'facings' AS NUMERIC) AS facings,
        CAST(item->>'facingsRows' AS NUMERIC) AS facings_rows,
        CAST(item->>'facings' AS NUMERIC) * CAST(item->>'facingsRows' AS NUMERIC) AS total_facings_rows,
        CAST(shelf ->> 'depth' AS NUMERIC) AS shelf_depth,
        CAST(shelf ->> 'width' AS NUMERIC) AS shelf_width,
        CASE
            WHEN item->>'orientation' = 'FRONT' THEN
                CASE
                    WHEN item->>'merchandisingStyle' = 'TRAY' THEN CAST(item->>'trayDepth' AS NUMERIC)
                    WHEN item->>'merchandisingStyle' = 'CASE' THEN CAST(item->>'caseDepth' AS NUMERIC)
                    ELSE CAST(item->>'unitDepth' AS NUMERIC)
                END
            WHEN item->>'orientation' = 'SIDE' THEN
                CASE
                    WHEN item->>'merchandisingStyle' = 'TRAY' THEN CAST(item->>'trayWidth' AS NUMERIC)
                    WHEN item->>'merchandisingStyle' = 'CASE' THEN CAST(item->>'caseWidth' AS NUMERIC)
                    ELSE CAST(item->>'unitWidth' AS NUMERIC)
                END
            ELSE NULL
        END AS p_depth,
        CASE
            WHEN item->>'merchandisingStyle' = 'TRAY' THEN CAST(item->>'trayDepth' AS NUMERIC)
            WHEN item->>'merchandisingStyle' = 'UNIT' THEN CAST(item->>'unitDepth' AS NUMERIC)
            ELSE CAST(item->>'caseDepth' AS NUMERIC)
        END as merch_depth,
        CASE
            WHEN item->>'merchandisingStyle' = 'TRAY' THEN CAST(item->>'trayWidth' AS NUMERIC)
            WHEN item->>'merchandisingStyle' = 'UNIT' THEN CAST(item->>'unitWidth' AS NUMERIC)
            ELSE CAST(item->>'caseWidth' AS NUMERIC)
        END as merch_width,
        CASE
            WHEN item->>'merchandisingStyle' = 'TRAY' THEN CAST(item->>'trayHeight' AS NUMERIC)
            WHEN item->>'merchandisingStyle' = 'UNIT' THEN CAST(item->>'unitHeight' AS NUMERIC)
            ELSE CAST(item->>'caseHeight' AS NUMERIC)
        END as merch_height,
        item->>'shelf' AS shelf_id,
        CAST(FLOOR(CAST(bay ->> 'bayNo' AS NUMERIC)) AS INTEGER) AS planogram_bays_bayNo,
        CAST(shelf ->> 'width' AS NUMERIC) AS planogram_bays_shelves_width,
        CAST(shelf ->> 'depth' AS NUMERIC) AS planogram_bays_shelves_depth,
        shelf_index AS planogram_bays_shelves_shelfNo
    FROM
        output_store_pog osp
    CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog AS jsonb) -> 'planogram' -> 'bays') AS bay
    CROSS JOIN LATERAL jsonb_array_elements(bay -> 'shelves') WITH ORDINALITY AS s(shelf, shelf_index)
    CROSS JOIN LATERAL jsonb_array_elements(shelf -> 'items') AS item
    WHERE osp.base_pog_id = '{{bpid}}'  AND osp.filter_config_id = '{{gen_id}}'  AND osp.is_latest_version = TRUE
),
ProductsPerShelf AS (
    SELECT DISTINCT
        base_pog_id,
        store_code,
        shelf_id,
        COUNT(*) OVER (PARTITION BY base_pog_id, store_code, shelf_id) AS products_per_shelf
    FROM DistinctItems
),
AggregatedItems AS (
    SELECT
        di.filter_config_id AS gen_id,
        'Y' as Ranged,
        di.store_status,
        di.merch_height,
        di.merch_width,
        di.merch_depth,
        di.base_pog_id,
        di.store_code,
        di.product_code,
        di.core_range,
        AVG(di.price) as price,
        SUM(di.profit) as profit,
        di.name,
        di.cdt1, di.cdt2, di.cdt3,
        di.minFacings,
        di.brand, di.variant,
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
        SUM(CASE
            WHEN di.merch_style_orig = 'TRAY' THEN di.noOfUnitsInTray
            WHEN di.merch_style_orig = 'CASE' THEN di.noOfUnitsInCase
            ELSE 1
        END) AS case_total_number,
        AVG(FLOOR(di.shelf_depth / di.p_depth)) AS units_deep,
        SUM(FLOOR(di.shelf_depth / di.p_depth) * di.facings * (CASE
            WHEN di.merch_style_orig = 'TRAY' THEN di.noOfUnitsInTray
            WHEN di.merch_style_orig = 'CASE' THEN di.noOfUnitsInCase
            ELSE 1
        END)) AS uos1,
        SUM(((FLOOR(di.shelf_depth / di.p_depth) * di.facings * (CASE
            WHEN di.merch_style_orig = 'TRAY' THEN di.noOfUnitsInTray
            WHEN di.merch_style_orig = 'CASE' THEN di.noOfUnitsInCase
            ELSE 1
        END)) / di.quantity) * 7) AS dos1,
        MAX(di.planogram_bays_bayNo) AS planogram_bays_bayNo,
        MAX(di.planogram_bays_shelves_width) AS planogram_bays_shelves_width,
        MAX(di.planogram_bays_shelves_depth) AS planogram_bays_shelves_depth,
        MAX(di.planogram_bays_shelves_shelfNo) AS planogram_bays_shelves_shelfNo
    FROM DistinctItems di
    LEFT JOIN ProductsPerShelf pps ON di.base_pog_id = pps.base_pog_id
        AND di.store_code = pps.store_code
        AND di.shelf_id = pps.shelf_id
    GROUP BY
        di.filter_config_id, di.store_status,
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
        di.cdt1, di.cdt2, di.cdt3,
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
        CASE
            WHEN ai.uos1 < ai.case_total_number THEN 1
            ELSE 0
        END AS less_than_case_flag,
        CASE
            WHEN ai.uos1 < 1.25 * ai.case_total_number THEN 1
            ELSE 0
        END AS less_than_case_mpl_flag,
        CASE
            WHEN ai.dos1 < 3 THEN 1
            ELSE 0
        END AS dos_lt_3,
        CASE
            WHEN ai.dos1 < 1 THEN 1
            ELSE 0
        END AS dos_gt_50,
        CASE
            WHEN ai.facings * ai.facings_rows < CAST(ai.minFacings AS NUMERIC) THEN 1
            ELSE 0
        END AS less_than_min_facings_flag,
        EXISTS (
            SELECT 1
            FROM pog_raw_data_json prd2
            WHERE prd2.base_pog_id = ai.base_pog_id AND prd2.store_code = ai.store_code AND prd2.product_code = ai.product_code
        ) AS exist_in_pog,
        CAST(ai.planogram_bays_bayNo AS INTEGER) AS planogram_bays_bayNo,
        CAST(ai.planogram_bays_shelves_width AS NUMERIC) AS planogram_bays_shelves_width,
        CAST(ai.planogram_bays_shelves_depth AS NUMERIC) AS planogram_bays_shelves_depth,
        CAST(ai.planogram_bays_shelves_shelfNo AS INTEGER) AS planogram_bays_shelves_shelfNo
    FROM
        AggregatedItems ai
    LEFT JOIN pog_raw_data_json prd ON ai.base_pog_id = prd.base_pog_id AND ai.store_code = prd.store_code AND ai.product_code = prd.product_code

    UNION ALL

    SELECT
        ud.filter_config_id AS gen_id,
        'N' as Ranged,
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
        CAST(NULL AS NUMERIC) AS noOfUnitsInTray,
        CAST(NULL AS NUMERIC) AS noOfUnitsInCase,
        ud.quantity,
        ud.p_depth,
        CAST(NULL AS NUMERIC) AS total_facings,
        CAST(ud.facings AS NUMERIC) AS facings,
        CAST(ud.facings_rows AS NUMERIC) AS facings_rows,
        ud.salesAmount,
        CAST(NULL AS NUMERIC) AS shelf_depth,
        CAST(NULL AS NUMERIC) AS shelf_width,
        ud.shelf_id AS shelf_ids,
        1 AS products_per_shelf,
        CAST(NULL AS NUMERIC) AS case_total_number,
        CAST(NULL AS NUMERIC) AS units_deep,
        CAST(NULL AS NUMERIC) AS uos1,
        CAST(NULL AS NUMERIC) AS dos1,
        CONCAT(ud.store_code, '-', ud.variant, '-', ud.cdt1) AS rank_key,
        0 AS less_than_case_flag,
        0 AS less_than_case_mpl_flag,
        0 AS dos_lt_3,
        0 AS dos_gt_50,
        CASE
            WHEN CAST(ud.facings AS NUMERIC) * CAST(ud.facings_rows AS NUMERIC) < CAST(ud.minFacings AS NUMERIC) THEN 1
            ELSE 0
        END AS less_than_min_facings_flag,
        FALSE AS exist_in_pog,
        CAST(NULL AS INTEGER) AS planogram_bays_bayNo,
        CAST(NULL AS NUMERIC) AS planogram_bays_shelves_width,
        CAST(NULL AS NUMERIC) AS planogram_bays_shelves_depth,
        CAST(NULL AS INTEGER) AS planogram_bays_shelves_shelfNo
    FROM unrangedData ud
),
ranked_data AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY store_code, variant, cdt1 ORDER BY salesAmount DESC) AS rank,
        COUNT(*) OVER (PARTITION BY store_code, variant, cdt1) AS total_count,
        ROUND((1.0 / COUNT(*) OVER (PARTITION BY store_code, variant, cdt1)), 10) AS item_count_percentage
    FROM combined_data
),
cumulative_data AS (
    SELECT
        rd.*,
        SUM(rd.item_count_percentage) OVER (PARTITION BY store_code, variant, cdt1 ORDER BY salesAmount DESC) AS cumulative_percentage
    FROM ranked_data rd
),
flagged_data AS (
    SELECT
        cd.*,
        cd.cumulative_percentage <= 0.2 AS current_under_twenty,
        LAG(cd.cumulative_percentage <= 0.2, 1) OVER (PARTITION BY store_code, variant, cdt1 ORDER BY salesAmount DESC) AS previous_under_twenty
    FROM cumulative_data cd
),
final_data AS (
    SELECT
        fd.*,
        CONCAT(fd.store_code, '-', fd.product_code) AS store_product_id,
        CONCAT(fd.store_code, '-', fd.category_code) AS store_cat_id,
        CASE
            WHEN fd.current_under_twenty THEN 1
            WHEN fd.previous_under_twenty IS NULL THEN 1
            WHEN fd.previous_under_twenty THEN 1
            ELSE 0
        END AS percent_flag
    FROM flagged_data fd
),
MinWidthCTE AS (
    SELECT
        variant,
        cdt1,
        MIN(CASE WHEN facings = 0 THEN merch_width END) AS min_merch_width_zero_facings,
        MIN(merch_width) AS min_merch_width_all
    FROM
        final_data
    GROUP BY
        variant, cdt1
),
final_data_with_min_width AS (
    SELECT
        fd.*,
        COALESCE(mw.min_merch_width_zero_facings, fd.merch_width) AS min_width_for_variant_cdt1_zero_facings,
        COALESCE(mw.min_merch_width_all, fd.merch_width) AS min_width_for_variant_cdt1_all
    FROM
        final_data fd
    LEFT JOIN
        MinWidthCTE mw ON fd.variant = mw.variant AND fd.cdt1 = mw.cdt1
)

SELECT
    fdwm.*,
    vss.cluster,
    CASE
        WHEN fdwm.facings_rows = 0 THEN NULL
        ELSE COALESCE(fdwm.facings / NULLIF(fdwm.facings_rows, 0), 0)
    END AS wide_facings,
    CASE
        WHEN fdwm.facings_rows = 0 THEN NULL
        ELSE COALESCE((fdwm.facings / NULLIF(fdwm.facings_rows, 0)) * fdwm.merch_width, 0)
    END AS width_occupied
FROM
    final_data_with_min_width fdwm
LEFT JOIN
    (SELECT DISTINCT
        store_code,
        product_code,
        sales,
        quantity,
        CONCAT(store_code, '-', product_code) AS store_product_id
    FROM
        ewma_sales
    WHERE
        is_latest_version = TRUE
    ) es ON fdwm.store_product_id = es.store_product_id
LEFT JOIN
    (SELECT DISTINCT
        store,
        cluster
    FROM
        v_store_summary
    ) vss ON fdwm.store_code = vss.store
