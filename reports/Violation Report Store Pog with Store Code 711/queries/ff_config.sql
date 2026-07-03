WITH shelf_data AS (
    SELECT
        osp.store AS store_code,
        sc.cluster AS template_id,
        CAST(FLOOR(CAST(bay.value ->> 'bayNo' AS numeric)) AS integer) AS bay_number,
        CAST(shelf.value ->> 'width' AS numeric) AS shelf_width,
        CAST(shelf.value ->> 'depth' AS numeric) AS shelf_depth,
        CAST(osp.pog -> 'planogram' ->> 'height' AS numeric) AS planogram_height
    FROM
        output_store_pog osp
        LEFT JOIN reporting.mv_store_cluster sc ON osp.store = sc.store
        CROSS JOIN LATERAL jsonb_array_elements(osp.pog -> 'planogram' -> 'bays') AS bay (value)
        CROSS JOIN LATERAL jsonb_array_elements(bay.value -> 'shelves') AS shelf (value)
    WHERE
        osp.filter_config_id = '{{gen_id}}'
        AND osp.base_pog_id = '{{bpid}}'
),
unique_shelf_info AS (
    SELECT DISTINCT ON (store_code,
        template_id,
        bay_number)
        store_code,
        template_id,
        bay_number,
        planogram_height,
        shelf_width,
        shelf_depth
    FROM
        shelf_data
    ORDER BY
        store_code,
        template_id,
        bay_number,
        planogram_height DESC
),
bay_info AS (
    SELECT
        store_code,
        template_id,
        bay_number,
        COUNT(*) AS shelf_count,
    CONCAT('H', TO_CHAR(MAX(planogram_height) / 100.0, 'FM999.00'), '-W', TO_CHAR(MAX(shelf_width) / 100.0, 'FM999.00'), '-D', TO_CHAR(MAX(shelf_depth) / 100.0, 'FM999.00')) AS shelf_info
FROM
    unique_shelf_info
GROUP BY
    store_code,
    template_id,
    bay_number
),
combined_bays AS (
    SELECT
        store_code,
        template_id,
        STRING_AGG(CONCAT(bay_number::text, '-', shelf_count::text, '-', shelf_info), ' || ' ORDER BY bay_number) AS combined_info
    FROM
        bay_info
    GROUP BY
        store_code,
        template_id
)
SELECT
    store_code,
    template_id,
    combined_info AS ff_id
FROM
    combined_bays
ORDER BY
    store_code
