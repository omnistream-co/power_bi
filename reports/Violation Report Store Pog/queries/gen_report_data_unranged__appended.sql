WITH v_store_summary AS (
    SELECT DISTINCT
        store.code AS store,
        store_cat.template_id AS cluster
    FROM
        store_cat
        JOIN store ON store_cat.store_id = store.id
),
v_ewma_sales_temp AS (
    SELECT
        sp.store_code,
        p.product_code,
        sp.quantity,
        sp.sales_amount AS sales,
        TRUE AS is_latest_version,
        NULL::text AS forecast_run_date
    FROM
        store_product sp
        JOIN product p ON p.product_id = sp.product_id
),
unrangedData AS (
    SELECT DISTINCT
        osp.id,
        osp.filter_config_id,
        osp.base_pog_id,
        osp.store AS store_code,
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
        pd.planogram_bays_shelves_shelfNo
    FROM ( SELECT DISTINCT
            osp.id,
            osp.filter_config_id,
            osp.base_pog_id,
            osp.store AS store_code,
            item ->> 'productCode' AS product_code,
            item ->> 'inCoreRange' AS core_range,
            CAST(item ->> 'price' AS numeric) AS price,
            CAST(item ->> 'profit' AS numeric) AS profit,
            item ->> 'name' AS name,
            item ->> 'cdt1' AS cdt1,
            item ->> 'cdt2' AS cdt2,
            item ->> 'cdt3' AS cdt3,
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
        CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog AS jsonb) -> 'planogram' -> 'bays') AS bay
        CROSS JOIN LATERAL jsonb_array_elements(bay -> 'shelves') AS shelf
        CROSS JOIN LATERAL jsonb_array_elements(shelf -> 'items') AS item
    WHERE
        osp.base_pog_id = '{{bpid}}'
        AND osp.filter_config_id = '{{gen_id}}'
        AND osp.is_latest_version = TRUE) di
    LEFT JOIN planogram_data pd ON di.id = pd.id
        AND di.shelf_id = pd.shelf_id
),
AggregatedItems AS (
    SELECT
        filter_config_id AS gen_id,
        'Y' AS Ranged,
        merch_height,
        merch_width,
        merch_depth,
        base_pog_id,
        store_code,
        product_code,
        core_range,
        AVG(price) AS price,
        SUM(profit) AS profit,
        name,
        cdt1,
        cdt2,
        cdt3,
        brand,
        variant,
        category_code,
        merch_style_orig,
        SUM(noOfUnitsInTray) AS noOfUnitsInTray,
        SUM(noOfUnitsInCase) AS noOfUnitsInCase,
        AVG(quantity) AS quantity,
        p_depth,
        SUM(facings) AS total_facings,
        AVG(facings) AS facings,
        SUM(facings_rows) AS facings_rows,
        SUM(salesAmount) AS salesAmount,
        AVG(planogram_bays_shelves_depth) AS shelf_depth,
        AVG(planogram_bays_shelves_width) AS shelf_width,
        SUM(
            CASE WHEN merch_style_orig = 'TRAY' THEN
                noOfUnitsInTray
            WHEN merch_style_orig = 'CASE' THEN
                noOfUnitsInCase
            ELSE
                1
            END) AS case_total_number,
        AVG(FLOOR(planogram_bays_shelves_depth / p_depth)) AS units_deep,
        SUM(FLOOR(planogram_bays_shelves_depth / p_depth) * facings * (
                CASE WHEN merch_style_orig = 'TRAY' THEN
                    noOfUnitsInTray
                WHEN merch_style_orig = 'CASE' THEN
                    noOfUnitsInCase
                ELSE
                    1
                END)) AS uos1,
        SUM(((FLOOR(planogram_bays_shelves_depth / p_depth) * facings * (
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
    merch_height,
    merch_width,
    merch_depth,
    base_pog_id,
    store_code,
    product_code,
    core_range,
    name,
    brand,
    category_code,
    merch_style_orig,
    p_depth,
    cdt1,
    cdt2,
    cdt3,
    variant
),
combined_data AS (
    SELECT
        ai.*,
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
        UNION ALL
        SELECT
            filter_config_id AS gen_id,
            'N' AS Ranged,
            merch_height,
            merch_width,
            merch_depth,
            base_pog_id,
            store_code,
            product_code,
            core_range,
            price,
            profit,
            name,
            cdt1,
            cdt2,
            cdt3,
            brand,
            variant,
            category_code,
            merch_style_orig,
            CAST(NULL AS numeric) AS noOfUnitsInTray,
            CAST(NULL AS numeric) AS noOfUnitsInCase,
            quantity,
            p_depth,
            CAST(NULL AS numeric) AS total_facings,
            CAST(facings AS numeric) AS facings,
            CAST(facings_rows AS numeric) AS facings_rows,
            salesAmount,
            CAST(NULL AS numeric) AS shelf_depth,
            CAST(NULL AS numeric) AS shelf_width,
            CAST(NULL AS numeric) AS case_total_number,
            CAST(NULL AS numeric) AS units_deep,
            CAST(NULL AS numeric) AS uos1,
            CAST(NULL AS numeric) AS dos1,
            CONCAT(store_code, '-', variant, '-', cdt1) AS rank_key,
            0 AS less_than_case_flag,
            0 AS less_than_case_mpl_flag,
            0 AS dos_lt_3,
            0 AS dos_gt_50,
            FALSE AS exist_in_pog
        FROM
            unrangedData
),
ranked_data AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY store_code,
            variant,
            cdt1 ORDER BY salesAmount DESC) AS rank,
        COUNT(*) OVER (PARTITION BY store_code,
            variant,
            cdt1) AS total_count,
        ROUND((1.0 / COUNT(*) OVER (PARTITION BY store_code, variant, cdt1)), 10) AS item_count_percentage
    FROM
        combined_data
),
cumulative_data AS (
    SELECT
        rd.*,
        SUM(rd.item_count_percentage) OVER (PARTITION BY store_code,
            variant,
            cdt1 ORDER BY salesAmount DESC) AS cumulative_percentage
    FROM
        ranked_data rd
),
flagged_data AS (
    SELECT
        cd.*,
        cd.cumulative_percentage <= 0.2 AS current_under_twenty,
        LAG(cd.cumulative_percentage <= 0.2, 1) OVER (PARTITION BY store_code,
            variant,
            cdt1 ORDER BY salesAmount DESC) AS previous_under_twenty
    FROM
        cumulative_data cd
),
final_data AS (
    SELECT
        fd.*,
        CONCAT(fd.store_code, '-', fd.product_code) AS store_product_id,
        CONCAT(fd.store_code, '-', fd.category_code) AS store_cat_id,
        CASE WHEN fd.current_under_twenty THEN
            1
        WHEN fd.previous_under_twenty IS NULL THEN
            1
        WHEN fd.previous_under_twenty THEN
            1
        ELSE
            0
        END AS percent_flag
    FROM
        flagged_data fd
)
SELECT
    fd.*,
    es.sales AS ewma_sales,
    es.quantity AS ewma_quantity,
    CASE WHEN es.sales = 0
        AND fd.facings > 0 THEN
        'add'
    WHEN fd.facings = 0
        AND es.sales > 0 THEN
        'delete'
    WHEN es.sales = 0
        AND fd.facings = 0 THEN
        'never there'
    ELSE
        'keep'
    END AS Status,
    CASE WHEN fd.facings_rows = 0 THEN
        NULL
    ELSE
        COALESCE((fd.facings / NULLIF (fd.facings_rows, 0)) * fd.merch_width, 0)
    END AS occupied,
    vss.cluster
FROM
    final_data fd
    LEFT JOIN ( SELECT DISTINCT
            store_code,
            product_code,
            sales,
            quantity,
            CONCAT(store_code, '-', product_code) AS store_product_id
        FROM
            v_ewma_sales_temp
        WHERE
            is_latest_version = TRUE) es ON fd.store_product_id = es.store_product_id
    LEFT JOIN ( SELECT DISTINCT
            store,
            CLUSTER
        FROM
            v_store_summary) vss ON fd.store_code = vss.store
ORDER BY
    fd.rank_key,
    fd.salesAmount DESC
