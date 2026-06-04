WITH unranged_data AS (
    SELECT DISTINCT
        osp.id,
        osp.filter_config_id,
        osp.base_pog_id,
        osp.store AS store_code,
        item.value ->> 'productCode'::text AS product_code,
        0::numeric AS total_facings_rows,
        0::numeric AS facings_rows,
        0::numeric AS facings,
        (item.value ->> 'price'::text)::numeric AS price,
        (item.value ->> 'profit'::text)::numeric AS profit,
        item.value ->> 'name'::text AS name,
        item.value ->> 'cdt1'::text AS cdt1,
        item.value ->> 'cdt2'::text AS cdt2,
        item.value ->> 'cdt3'::text AS cdt3,
        item.value ->> 'variant'::text AS variant,
        item.value ->> 'inCoreRange'::text AS core_range,
        item.value ->> 'brand'::text AS brand,
        item.value ->> 'categoryCode'::text AS category_code,
        (item.value ->> 'salesAmount'::text)::numeric AS sales_amount,
        item.value ->> 'merchandisingStyle'::text AS merch_style_orig,
        (item.value ->> 'quantity'::text)::numeric AS quantity,
        CASE WHEN (item.value ->> 'orientation'::text) = 'FRONT'::text THEN
            CASE WHEN (item.value ->> 'merchandisingStyle'::text) = 'TRAY'::text THEN
                (item.value ->> 'trayDepth'::text)::numeric
            WHEN (item.value ->> 'merchandisingStyle'::text) = 'CASE'::text THEN
                (item.value ->> 'caseDepth'::text)::numeric
            ELSE
                (item.value ->> 'unitDepth'::text)::numeric
            END
        WHEN (item.value ->> 'orientation'::text) = 'SIDE'::text THEN
            CASE WHEN (item.value ->> 'merchandisingStyle'::text) = 'TRAY'::text THEN
                (item.value ->> 'trayWidth'::text)::numeric
            WHEN (item.value ->> 'merchandisingStyle'::text) = 'CASE'::text THEN
                (item.value ->> 'caseWidth'::text)::numeric
            ELSE
                (item.value ->> 'unitWidth'::text)::numeric
            END
        ELSE
            NULL::numeric
        END AS p_depth,
        CASE WHEN (item.value ->> 'merchandisingStyle'::text) = 'TRAY'::text THEN
            (item.value ->> 'trayDepth'::text)::numeric
        WHEN (item.value ->> 'merchandisingStyle'::text) = 'UNIT'::text THEN
            (item.value ->> 'unitDepth'::text)::numeric
        ELSE
            (item.value ->> 'caseDepth'::text)::numeric
        END AS merch_depth,
        CASE WHEN (item.value ->> 'merchandisingStyle'::text) = 'TRAY'::text THEN
            (item.value ->> 'trayWidth'::text)::numeric
        WHEN (item.value ->> 'merchandisingStyle'::text) = 'UNIT'::text THEN
            (item.value ->> 'unitWidth'::text)::numeric
        ELSE
            (item.value ->> 'caseWidth'::text)::numeric
        END AS merch_width,
        CASE WHEN (item.value ->> 'merchandisingStyle'::text) = 'TRAY'::text THEN
            (item.value ->> 'trayHeight'::text)::numeric
        WHEN (item.value ->> 'merchandisingStyle'::text) = 'UNIT'::text THEN
            (item.value ->> 'unitHeight'::text)::numeric
        ELSE
            (item.value ->> 'caseHeight'::text)::numeric
        END AS merch_height
    FROM
        output_store_pog osp
        CROSS JOIN LATERAL jsonb_array_elements(osp.pog -> 'unrangedItems'::text) item (value)
        JOIN (
            SELECT
                v_merchflow_projects_temp.id
            FROM
                reporting.v_merchflow_projects_temp
            WHERE
                v_merchflow_projects_temp.project_id = 1) project_filters ON osp.id = project_filters.id
),
pog_raw_data_json AS (
    SELECT
        osp.id,
        osp.filter_config_id,
        osp.base_pog_id,
        pm_elem.value ->> 'OOS'::text AS oos,
        pm_elem.value ->> 'store_code'::text AS store_code,
        pm_elem.value ->> 'product_code'::text AS product_code
    FROM
        output_store_pog osp
        CROSS JOIN LATERAL jsonb_array_elements(osp.pog_raw_data::jsonb -> 'pm'::text) pm_elem (value)
        JOIN (
            SELECT
                v_merchflow_projects_temp.id
            FROM
                reporting.v_merchflow_projects_temp
            WHERE
                v_merchflow_projects_temp.project_id = 1) project_filters ON osp.id = project_filters.id
),
distinct_items AS (
    SELECT DISTINCT
        osp.id,
        osp.filter_config_id,
        osp.base_pog_id,
        osp.store AS store_code,
        item.value ->> 'productCode'::text AS product_code,
        item.value ->> 'inCoreRange'::text AS core_range,
        (item.value ->> 'price'::text)::numeric AS price,
        (item.value ->> 'profit'::text)::numeric AS profit,
        item.value ->> 'name'::text AS name,
        item.value ->> 'cdt1'::text AS cdt1,
        item.value ->> 'cdt2'::text AS cdt2,
        item.value ->> 'cdt3'::text AS cdt3,
        item.value ->> 'variant'::text AS variant,
        item.value ->> 'brand'::text AS brand,
        item.value ->> 'categoryCode'::text AS category_code,
        (item.value ->> 'salesAmount'::text)::numeric AS sales_amount,
        item.value ->> 'merchandisingStyle'::text AS merch_style_orig,
        (item.value ->> 'noOfUnitsInTray'::text)::numeric AS no_of_units_in_tray,
        (item.value ->> 'noOfUnitsInCase'::text)::numeric AS no_of_units_in_case,
        (item.value ->> 'quantity'::text)::numeric AS quantity,
        (item.value ->> 'facings'::text)::numeric AS facings,
        (item.value ->> 'facingsRows'::text)::numeric AS facings_rows,
        ((item.value ->> 'facings'::text)::numeric) * ((item.value ->> 'facingsRows'::text)::numeric) AS total_facings_rows,
        (shelf.value ->> 'depth'::text)::numeric AS shelf_depth,
        (shelf.value ->> 'width'::text)::numeric AS shelf_width,
        CASE WHEN (item.value ->> 'orientation'::text) = 'FRONT'::text THEN
            CASE WHEN (item.value ->> 'merchandisingStyle'::text) = 'TRAY'::text THEN
                (item.value ->> 'trayDepth'::text)::numeric
            WHEN (item.value ->> 'merchandisingStyle'::text) = 'CASE'::text THEN
                (item.value ->> 'caseDepth'::text)::numeric
            ELSE
                (item.value ->> 'unitDepth'::text)::numeric
            END
        WHEN (item.value ->> 'orientation'::text) = 'SIDE'::text THEN
            CASE WHEN (item.value ->> 'merchandisingStyle'::text) = 'TRAY'::text THEN
                (item.value ->> 'trayWidth'::text)::numeric
            WHEN (item.value ->> 'merchandisingStyle'::text) = 'CASE'::text THEN
                (item.value ->> 'caseWidth'::text)::numeric
            ELSE
                (item.value ->> 'unitWidth'::text)::numeric
            END
        ELSE
            NULL::numeric
        END AS p_depth,
        CASE WHEN (item.value ->> 'merchandisingStyle'::text) = 'TRAY'::text THEN
            (item.value ->> 'trayDepth'::text)::numeric
        WHEN (item.value ->> 'merchandisingStyle'::text) = 'UNIT'::text THEN
            (item.value ->> 'unitDepth'::text)::numeric
        ELSE
            (item.value ->> 'caseDepth'::text)::numeric
        END AS merch_depth,
        CASE WHEN (item.value ->> 'merchandisingStyle'::text) = 'TRAY'::text THEN
            (item.value ->> 'trayWidth'::text)::numeric
        WHEN (item.value ->> 'merchandisingStyle'::text) = 'UNIT'::text THEN
            (item.value ->> 'unitWidth'::text)::numeric
        ELSE
            (item.value ->> 'caseWidth'::text)::numeric
        END AS merch_width,
        CASE WHEN (item.value ->> 'merchandisingStyle'::text) = 'TRAY'::text THEN
            (item.value ->> 'trayHeight'::text)::numeric
        WHEN (item.value ->> 'merchandisingStyle'::text) = 'UNIT'::text THEN
            (item.value ->> 'unitHeight'::text)::numeric
        ELSE
            (item.value ->> 'caseHeight'::text)::numeric
        END AS merch_height
    FROM
        output_store_pog osp
        CROSS JOIN LATERAL jsonb_array_elements((osp.pog -> 'planogram'::text) -> 'bays'::text) bay (value)
        CROSS JOIN LATERAL jsonb_array_elements(bay.value -> 'shelves'::text) shelf (value)
        CROSS JOIN LATERAL jsonb_array_elements(shelf.value -> 'items'::text) item (value)
        JOIN (
            SELECT
                v_merchflow_projects_temp.id
            FROM
                reporting.v_merchflow_projects_temp
            WHERE
                v_merchflow_projects_temp.project_id = 1) project_filters ON osp.id = project_filters.id
),
aggregated_items AS (
    SELECT
        distinct_items.filter_config_id AS gen_id,
        'Y'::text AS ranged,
        distinct_items.merch_height,
        distinct_items.merch_width,
        distinct_items.merch_depth,
        distinct_items.base_pog_id,
        distinct_items.store_code,
        distinct_items.product_code,
        distinct_items.core_range,
        avg(distinct_items.price) AS price,
        sum(distinct_items.profit) AS profit,
        distinct_items.name,
        distinct_items.cdt1,
        distinct_items.cdt2,
        distinct_items.cdt3,
        distinct_items.brand,
        distinct_items.variant,
        distinct_items.category_code,
        distinct_items.merch_style_orig,
        sum(distinct_items.no_of_units_in_tray) AS no_of_units_in_tray,
        sum(distinct_items.no_of_units_in_case) AS no_of_units_in_case,
        avg(distinct_items.quantity) AS quantity,
        distinct_items.p_depth,
        sum(distinct_items.facings) AS total_facings,
        avg(distinct_items.facings) AS facings,
        sum(distinct_items.facings_rows) AS facings_rows,
        sum(distinct_items.sales_amount) AS sales_amount,
        avg(distinct_items.shelf_depth) AS shelf_depth,
        avg(distinct_items.shelf_width) AS shelf_width,
        sum(
            CASE WHEN distinct_items.merch_style_orig = 'TRAY'::text THEN
                distinct_items.no_of_units_in_tray
            WHEN distinct_items.merch_style_orig = 'CASE'::text THEN
                distinct_items.no_of_units_in_case
            ELSE
                1::numeric
            END) AS case_total_number,
        avg(floor(distinct_items.shelf_depth / distinct_items.p_depth)) AS units_deep,
        sum(floor(distinct_items.shelf_depth / distinct_items.p_depth) * distinct_items.facings * CASE WHEN distinct_items.merch_style_orig = 'TRAY'::text THEN
                distinct_items.no_of_units_in_tray
            WHEN distinct_items.merch_style_orig = 'CASE'::text THEN
                distinct_items.no_of_units_in_case
            ELSE
                1::numeric
            END) AS uos1,
        sum(floor(distinct_items.shelf_depth / distinct_items.p_depth) * distinct_items.facings * CASE WHEN distinct_items.merch_style_orig = 'TRAY'::text THEN
                distinct_items.no_of_units_in_tray
            WHEN distinct_items.merch_style_orig = 'CASE'::text THEN
                distinct_items.no_of_units_in_case
            ELSE
                1::numeric
            END / distinct_items.quantity * 7::numeric) AS dos1
    FROM
        distinct_items
    GROUP BY
        distinct_items.filter_config_id,
        distinct_items.merch_height,
        distinct_items.merch_width,
        distinct_items.merch_depth,
        distinct_items.base_pog_id,
        distinct_items.store_code,
        distinct_items.product_code,
        distinct_items.core_range,
        distinct_items.name,
        distinct_items.brand,
        distinct_items.category_code,
        distinct_items.merch_style_orig,
        distinct_items.p_depth,
        distinct_items.cdt1,
        distinct_items.cdt2,
        distinct_items.cdt3,
        distinct_items.variant
),
combined_data AS (
    SELECT
        ai.gen_id,
        ai.ranged,
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
        ai.brand,
        ai.variant,
        ai.category_code,
        ai.merch_style_orig,
        ai.no_of_units_in_tray,
        ai.no_of_units_in_case,
        ai.quantity,
        ai.p_depth,
        ai.total_facings,
        ai.facings,
        ai.facings_rows,
        ai.sales_amount,
        ai.shelf_depth,
        ai.shelf_width,
        ai.case_total_number,
        ai.units_deep,
        ai.uos1,
        ai.dos1,
        concat(ai.store_code, '-', ai.variant, '-', ai.cdt1) AS rank_key,
        CASE WHEN ai.uos1 < ai.case_total_number THEN
            1
        ELSE
            0
        END AS less_than_case_flag,
        CASE WHEN ai.uos1 < (1.25 * ai.case_total_number) THEN
            1
        ELSE
            0
        END AS less_than_case_mpl_flag,
        CASE WHEN ai.dos1 < 3::numeric THEN
            1
        ELSE
            0
        END AS dos_lt_3,
        CASE WHEN ai.dos1 < 1::numeric THEN
            1
        ELSE
            0
        END AS dos_lt_1,
        (EXISTS (
                SELECT
                    1
                FROM
                    pog_raw_data_json prd2
                WHERE
                    prd2.base_pog_id = ai.base_pog_id
                    AND prd2.store_code = ai.store_code::text
                    AND prd2.product_code = ai.product_code)) AS exist_in_pog
        FROM
            aggregated_items ai
        LEFT JOIN pog_raw_data_json prd ON ai.base_pog_id = prd.base_pog_id
            AND ai.store_code::text = prd.store_code
            AND ai.product_code = prd.product_code
        UNION ALL
        SELECT
            unranged_data.filter_config_id AS gen_id,
            'N'::text AS ranged,
            unranged_data.merch_height,
            unranged_data.merch_width,
            unranged_data.merch_depth,
            unranged_data.base_pog_id,
            unranged_data.store_code,
            unranged_data.product_code,
            unranged_data.core_range,
            unranged_data.price,
            unranged_data.profit,
            unranged_data.name,
            unranged_data.cdt1,
            unranged_data.cdt2,
            unranged_data.cdt3,
            unranged_data.brand,
            unranged_data.variant,
            unranged_data.category_code,
            unranged_data.merch_style_orig,
            NULL::numeric AS no_of_units_in_tray,
            NULL::numeric AS no_of_units_in_case,
            unranged_data.quantity,
            unranged_data.p_depth,
            NULL::numeric AS total_facings,
            unranged_data.facings,
            unranged_data.facings_rows,
            unranged_data.sales_amount,
            NULL::numeric AS shelf_depth,
            NULL::numeric AS shelf_width,
            NULL::numeric AS case_total_number,
            NULL::numeric AS units_deep,
            NULL::numeric AS uos1,
            NULL::numeric AS dos1,
            concat(unranged_data.store_code, '-', unranged_data.variant, '-', unranged_data.cdt1) AS rank_key,
            0 AS less_than_case_flag,
            0 AS less_than_case_mpl_flag,
            0 AS dos_lt_3,
            0 AS dos_lt_1,
            FALSE AS exist_in_pog
        FROM
            unranged_data
),
ranked_data AS (
    SELECT
        combined_data.gen_id,
        combined_data.ranged,
        combined_data.merch_height,
        combined_data.merch_width,
        combined_data.merch_depth,
        combined_data.base_pog_id,
        combined_data.store_code,
        combined_data.product_code,
        combined_data.core_range,
        combined_data.price,
        combined_data.profit,
        combined_data.name,
        combined_data.cdt1,
        combined_data.cdt2,
        combined_data.cdt3,
        combined_data.brand,
        combined_data.variant,
        combined_data.category_code,
        combined_data.merch_style_orig,
        combined_data.no_of_units_in_tray,
        combined_data.no_of_units_in_case,
        combined_data.quantity,
        combined_data.p_depth,
        combined_data.total_facings,
        combined_data.facings,
        combined_data.facings_rows,
        combined_data.sales_amount,
        combined_data.shelf_depth,
        combined_data.shelf_width,
        combined_data.case_total_number,
        combined_data.units_deep,
        combined_data.uos1,
        combined_data.dos1,
        combined_data.rank_key,
        combined_data.less_than_case_flag,
        combined_data.less_than_case_mpl_flag,
        combined_data.dos_lt_3,
        combined_data.dos_lt_1,
        combined_data.exist_in_pog,
        row_number() OVER (PARTITION BY combined_data.store_code,
            combined_data.variant,
            combined_data.cdt1 ORDER BY combined_data.sales_amount DESC) AS rank,
        count(*) OVER (PARTITION BY combined_data.store_code,
            combined_data.variant,
            combined_data.cdt1) AS total_count,
        round(1.0 / count(*) OVER (PARTITION BY combined_data.store_code, combined_data.variant, combined_data.cdt1)::numeric, 10) AS item_count_percentage
    FROM
        combined_data
),
cumulative_data AS (
    SELECT
        rd.gen_id,
        rd.ranged,
        rd.merch_height,
        rd.merch_width,
        rd.merch_depth,
        rd.base_pog_id,
        rd.store_code,
        rd.product_code,
        rd.core_range,
        rd.price,
        rd.profit,
        rd.name,
        rd.cdt1,
        rd.cdt2,
        rd.cdt3,
        rd.brand,
        rd.variant,
        rd.category_code,
        rd.merch_style_orig,
        rd.no_of_units_in_tray,
        rd.no_of_units_in_case,
        rd.quantity,
        rd.p_depth,
        rd.total_facings,
        rd.facings,
        rd.facings_rows,
        rd.sales_amount,
        rd.shelf_depth,
        rd.shelf_width,
        rd.case_total_number,
        rd.units_deep,
        rd.uos1,
        rd.dos1,
        rd.rank_key,
        rd.less_than_case_flag,
        rd.less_than_case_mpl_flag,
        rd.dos_lt_3,
        rd.dos_lt_1,
        rd.exist_in_pog,
        rd.rank,
        rd.total_count,
        rd.item_count_percentage,
        sum(rd.item_count_percentage) OVER (PARTITION BY rd.store_code,
            rd.variant,
            rd.cdt1 ORDER BY rd.sales_amount DESC) AS cumulative_percentage
    FROM
        ranked_data rd
),
flagged_data AS (
    SELECT
        cd.gen_id,
        cd.ranged,
        cd.merch_height,
        cd.merch_width,
        cd.merch_depth,
        cd.base_pog_id,
        cd.store_code,
        cd.product_code,
        cd.core_range,
        cd.price,
        cd.profit,
        cd.name,
        cd.cdt1,
        cd.cdt2,
        cd.cdt3,
        cd.brand,
        cd.variant,
        cd.category_code,
        cd.merch_style_orig,
        cd.no_of_units_in_tray,
        cd.no_of_units_in_case,
        cd.quantity,
        cd.p_depth,
        cd.total_facings,
        cd.facings,
        cd.facings_rows,
        cd.sales_amount,
        cd.shelf_depth,
        cd.shelf_width,
        cd.case_total_number,
        cd.units_deep,
        cd.uos1,
        cd.dos1,
        cd.rank_key,
        cd.less_than_case_flag,
        cd.less_than_case_mpl_flag,
        cd.dos_lt_3,
        cd.dos_lt_1,
        cd.exist_in_pog,
        cd.rank,
        cd.total_count,
        cd.item_count_percentage,
        cd.cumulative_percentage,
        cd.cumulative_percentage <= 0.2 AS current_under_twenty,
        lag(cd.cumulative_percentage <= 0.2, 1) OVER (PARTITION BY cd.store_code,
            cd.variant,
            cd.cdt1 ORDER BY cd.sales_amount DESC) AS previous_under_twenty
    FROM
        cumulative_data cd
),
final_data AS (
    SELECT
        fd.gen_id,
        fd.ranged,
        fd.merch_height,
        fd.merch_width,
        fd.merch_depth,
        fd.base_pog_id,
        fd.store_code,
        fd.product_code,
        fd.core_range,
        fd.price,
        fd.profit,
        fd.name,
        fd.cdt1,
        fd.cdt2,
        fd.cdt3,
        fd.brand,
        fd.variant,
        fd.category_code,
        fd.merch_style_orig,
        fd.no_of_units_in_tray,
        fd.no_of_units_in_case,
        fd.quantity,
        fd.p_depth,
        fd.total_facings,
        fd.facings,
        fd.facings_rows,
        fd.sales_amount,
        fd.shelf_depth,
        fd.shelf_width,
        fd.case_total_number,
        fd.units_deep,
        fd.uos1,
        fd.dos1,
        fd.rank_key,
        fd.less_than_case_flag,
        fd.less_than_case_mpl_flag,
        fd.dos_lt_3,
        fd.dos_lt_1,
        fd.exist_in_pog,
        fd.rank,
        fd.total_count,
        fd.item_count_percentage,
        fd.cumulative_percentage,
        fd.current_under_twenty,
        fd.previous_under_twenty,
        concat(fd.store_code, '-', fd.product_code) AS store_product_id,
        concat(fd.store_code, '-', fd.category_code) AS store_cat_id,
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
),
final_data_with_status AS (
    SELECT
        fd.gen_id,
        fd.ranged,
        fd.merch_height,
        fd.merch_width,
        fd.merch_depth,
        fd.base_pog_id,
        fd.store_code,
        fd.product_code,
        fd.core_range,
        fd.price,
        fd.profit,
        fd.name,
        fd.cdt1,
        fd.cdt2,
        fd.cdt3,
        fd.brand,
        fd.variant,
        fd.category_code,
        fd.merch_style_orig,
        fd.no_of_units_in_tray,
        fd.no_of_units_in_case,
        fd.quantity,
        fd.p_depth,
        fd.total_facings,
        fd.facings,
        fd.facings_rows,
        fd.sales_amount,
        fd.shelf_depth,
        fd.shelf_width,
        fd.case_total_number,
        fd.units_deep,
        fd.uos1,
        fd.dos1,
        fd.rank_key,
        fd.less_than_case_flag,
        fd.less_than_case_mpl_flag,
        fd.dos_lt_3,
        fd.dos_lt_1,
        fd.exist_in_pog,
        fd.rank,
        fd.total_count,
        fd.item_count_percentage,
        fd.cumulative_percentage,
        fd.current_under_twenty,
        fd.previous_under_twenty,
        fd.store_product_id,
        fd.store_cat_id,
        fd.percent_flag,
        es.sales AS ewma_sales,
        es.quantity AS ewma_quantity,
        CASE WHEN es.sales = 0::numeric
            AND fd.facings > 0::numeric THEN
            'add'::text
        WHEN fd.facings = 0::numeric
            AND es.sales > 0::numeric THEN
            'delete'::text
        WHEN es.sales = 0::numeric
            AND fd.facings = 0::numeric THEN
            'never there'::text
        ELSE
            'keep'::text
        END AS status,
        fd.facings * fd.merch_width AS occupied,
        vss.cluster
    FROM
        final_data fd
    LEFT JOIN ( SELECT DISTINCT
            v_ewma_sales_temp.store_code,
            v_ewma_sales_temp.product_code,
            v_ewma_sales_temp.sales,
            v_ewma_sales_temp.quantity,
            concat(v_ewma_sales_temp.store_code, '-', v_ewma_sales_temp.product_code) AS store_product_id
        FROM
            reporting.v_ewma_sales_temp
        WHERE
            v_ewma_sales_temp.is_latest_version = TRUE) es ON fd.store_product_id = es.store_product_id
        LEFT JOIN ( SELECT DISTINCT
                store.code AS store,
                store_cat.cluster
            FROM
                store_cat
                JOIN store ON store_cat.store_id = store.id) vss ON fd.store_code::text = vss.store::text
),
enhanced_final_data AS (
    SELECT
        fds.gen_id,
        fds.ranged,
        fds.merch_height,
        fds.merch_width,
        fds.merch_depth,
        fds.base_pog_id,
        fds.store_code,
        fds.product_code,
        fds.core_range,
        fds.price,
        fds.profit,
        fds.name,
        fds.cdt1,
        fds.cdt2,
        fds.cdt3,
        fds.brand,
        fds.variant,
        fds.category_code,
        fds.merch_style_orig,
        fds.no_of_units_in_tray,
        fds.no_of_units_in_case,
        fds.quantity,
        fds.p_depth,
        fds.total_facings,
        fds.facings,
        fds.facings_rows,
        fds.sales_amount,
        fds.shelf_depth,
        fds.shelf_width,
        fds.case_total_number,
        fds.units_deep,
        fds.uos1,
        fds.dos1,
        fds.rank_key,
        fds.less_than_case_flag,
        fds.less_than_case_mpl_flag,
        fds.dos_lt_3,
        fds.dos_lt_1,
        fds.exist_in_pog,
        fds.rank,
        fds.total_count,
        fds.item_count_percentage,
        fds.cumulative_percentage,
        fds.current_under_twenty,
        fds.previous_under_twenty,
        fds.store_product_id,
        fds.store_cat_id,
        fds.percent_flag,
        fds.ewma_sales,
        fds.ewma_quantity,
        fds.status,
        fds.occupied,
        fds.cluster,
        CASE WHEN fds.status = 'add'::text THEN
            1
        ELSE
            0
        END AS count_add,
        CASE WHEN fds.status = 'delete'::text THEN
            1
        ELSE
            0
        END AS count_delete,
        CASE WHEN fds.status = 'keep'::text THEN
            1
        ELSE
            0
        END AS count_keep,
        CASE WHEN fds.ewma_sales > 0::numeric THEN
            fds.profit
        ELSE
            0::numeric
        END AS profit_before,
        CASE WHEN fds.ranged = 'Y'::text THEN
            fds.profit
        ELSE
            0::numeric
        END AS profit_now,
        CASE WHEN fds.status = 'add'::text THEN
            fds.profit
        ELSE
            0::numeric
        END AS profits_of_add,
        CASE WHEN fds.status = 'delete'::text THEN
            fds.profit
        ELSE
            0::numeric
        END AS profits_of_delete,
        CASE WHEN fds.status = 'keep'::text THEN
            fds.profit
        ELSE
            0::numeric
        END AS profits_of_keep,
        CASE WHEN fds.status = 'add'::text THEN
            fds.sales_amount
        ELSE
            0::numeric
        END AS sales_of_add,
        CASE WHEN fds.status = 'delete'::text THEN
            fds.sales_amount
        ELSE
            0::numeric
        END AS sales_of_delete,
        CASE WHEN fds.status = 'keep'::text THEN
            fds.sales_amount
        ELSE
            0::numeric
        END AS sales_of_keep,
        CASE WHEN fds.ewma_sales > 0::numeric THEN
            fds.sales_amount
        ELSE
            0::numeric
        END AS sales_realized_before,
        CASE WHEN fds.ranged = 'Y'::text THEN
            fds.sales_amount
        ELSE
            0::numeric
        END AS sales_realized_now,
        CASE WHEN fds.ewma_quantity > 0::numeric THEN
            1
        ELSE
            0
        END AS distribution_point_before,
        CASE WHEN fds.ranged = 'Y'::text THEN
            1
        ELSE
            0
        END AS distribution_point_now
    FROM
        final_data_with_status fds
),
aggregated_metrics AS (
    SELECT
        count(DISTINCT enhanced_final_data.store_code) AS store_count,
        count(DISTINCT enhanced_final_data.cluster) AS cluster_count,
        sum(
            CASE WHEN enhanced_final_data.status = 'add'::text THEN
                1
            ELSE
                0
            END) AS total_distribution_added,
        sum(
            CASE WHEN enhanced_final_data.status = 'delete'::text THEN
                1
            ELSE
                0
            END) AS total_distribution_deleted,
        sum(
            CASE WHEN enhanced_final_data.status = 'keep'::text THEN
                1
            ELSE
                0
            END) AS total_distribution_keep,
        sum(
            CASE WHEN enhanced_final_data.ewma_sales > 0::numeric THEN
                enhanced_final_data.profit
            ELSE
                0::numeric
            END) AS profit_before,
        sum(
            CASE WHEN enhanced_final_data.ranged = 'Y'::text THEN
                enhanced_final_data.profit
            ELSE
                0::numeric
            END) AS profit_now,
        sum(
            CASE WHEN enhanced_final_data.status = 'add'::text THEN
                enhanced_final_data.profit
            ELSE
                0::numeric
            END) AS profits_of_add,
        sum(
            CASE WHEN enhanced_final_data.status = 'delete'::text THEN
                enhanced_final_data.profit
            ELSE
                0::numeric
            END) AS profits_of_delete,
        sum(
            CASE WHEN enhanced_final_data.status = 'keep'::text THEN
                enhanced_final_data.profit
            ELSE
                0::numeric
            END) AS profits_of_keep,
        sum(
            CASE WHEN enhanced_final_data.status = 'add'::text THEN
                enhanced_final_data.sales_amount
            ELSE
                0::numeric
            END) AS sales_of_add,
        sum(
            CASE WHEN enhanced_final_data.status = 'delete'::text THEN
                enhanced_final_data.sales_amount
            ELSE
                0::numeric
            END) AS sales_of_delete,
        sum(
            CASE WHEN enhanced_final_data.status = 'keep'::text THEN
                enhanced_final_data.sales_amount
            ELSE
                0::numeric
            END) AS sales_of_keep,
        sum(
            CASE WHEN enhanced_final_data.ewma_sales > 0::numeric THEN
                enhanced_final_data.sales_amount
            ELSE
                0::numeric
            END) AS sales_realized_before,
        sum(
            CASE WHEN enhanced_final_data.ranged = 'Y'::text THEN
                enhanced_final_data.sales_amount
            ELSE
                0::numeric
            END) AS sales_realized_now,
        sum(
            CASE WHEN enhanced_final_data.ewma_quantity > 0::numeric THEN
                1
            ELSE
                0
            END) AS total_distribution_points_before,
        sum(
            CASE WHEN enhanced_final_data.ranged = 'Y'::text THEN
                1
            ELSE
                0
            END) AS total_distribution_points_now
    FROM
        enhanced_final_data
),
calculated_metrics AS (
    SELECT
        aggregated_metrics.store_count,
        aggregated_metrics.cluster_count,
        aggregated_metrics.total_distribution_added,
        aggregated_metrics.total_distribution_deleted,
        aggregated_metrics.total_distribution_keep,
        aggregated_metrics.profit_before,
        aggregated_metrics.profit_now,
        aggregated_metrics.profits_of_add,
        aggregated_metrics.profits_of_delete,
        aggregated_metrics.profits_of_keep,
        aggregated_metrics.sales_of_add,
        aggregated_metrics.sales_of_delete,
        aggregated_metrics.sales_of_keep,
        aggregated_metrics.sales_realized_before,
        aggregated_metrics.sales_realized_now,
        aggregated_metrics.total_distribution_points_before,
        aggregated_metrics.total_distribution_points_now,
        aggregated_metrics.total_distribution_points_now::double precision / NULLIF (aggregated_metrics.total_distribution_points_before, 0)::double precision - 1::double precision AS percent_change_distribution,
        aggregated_metrics.profit_now::double precision / NULLIF (aggregated_metrics.profit_before, 0::numeric)::double precision - 1::double precision AS percent_change_profit,
        aggregated_metrics.sales_realized_now::double precision / NULLIF (aggregated_metrics.sales_realized_before, 0::numeric)::double precision - 1::double precision AS percent_change_sales,
        aggregated_metrics.sales_realized_now::double precision / NULLIF (aggregated_metrics.sales_realized_before, 0::numeric)::double precision - 1::double precision AS sales_realization
    FROM
        aggregated_metrics
)
SELECT
    subquery.measure,
    subquery.value,
    CASE WHEN subquery.measure ~~ '%.Percent_%'::text
        OR subquery.measure ~~ '%Change%'::text
        OR subquery.measure = '19.Sales_Realization'::text THEN
        round(subquery.value::numeric * 100::numeric, 2) || '%'::text
    ELSE
        CASE WHEN abs(subquery.value::numeric) >= 1000000::numeric THEN
            round(subquery.value::numeric / 1000000::numeric, 2) || 'M'::text
        WHEN abs(subquery.value::numeric) >= 1000::numeric THEN
            round(subquery.value::numeric / 1000::numeric, 2) || 'K'::text
        ELSE
            round(subquery.value::numeric, 2)::text
        END
    END AS formatted_value
FROM (
    SELECT
        '02.Distribution points_Before'::text AS measure,
        calculated_metrics.total_distribution_points_before AS value
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '01.Distribution Points_Now'::text,
        calculated_metrics.total_distribution_points_now
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '03.Distribution_Added'::text,
        calculated_metrics.total_distribution_added
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '04.Distribution_Deleted'::text,
        calculated_metrics.total_distribution_deleted
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '05.Distribution_Keep'::text,
        calculated_metrics.total_distribution_keep
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '06.Sales_Realized_Now'::text,
        calculated_metrics.sales_realized_now
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '07.Sales_Realized_Before'::text,
        calculated_metrics.sales_realized_before
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '08.Sales_of_Add'::text,
        calculated_metrics.sales_of_add
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '09.Sales_of_Delete'::text,
        calculated_metrics.sales_of_delete
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '10.Sales_of_Keep'::text,
        calculated_metrics.sales_of_keep
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '11.Profit_Now'::text,
        calculated_metrics.profit_now
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '12.Profit_Before'::text,
        calculated_metrics.profit_before
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '13.Profits_of_Add'::text,
        calculated_metrics.profits_of_add
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '14.Profits_of_Delete'::text,
        calculated_metrics.profits_of_delete
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '15.Profits_of_Keep'::text,
        calculated_metrics.profits_of_keep
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '16.Percent_Change_distribution'::text,
        calculated_metrics.percent_change_distribution
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '17.Percent_Change_profit'::text,
        calculated_metrics.percent_change_profit
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '18.Percent_Change_sales'::text,
        calculated_metrics.percent_change_sales
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '19.Sales_Realization'::text,
        calculated_metrics.sales_realization
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '20.Store_count'::text,
        calculated_metrics.store_count
    FROM
        calculated_metrics
    UNION ALL
    SELECT
        '21.Cluster_count'::text,
        calculated_metrics.cluster_count
    FROM
        calculated_metrics) subquery
ORDER BY
    subquery.measure
