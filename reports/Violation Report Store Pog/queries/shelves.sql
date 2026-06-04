WITH shelf_data AS (
    SELECT
        osp.store AS store_code,
        CAST(bay ->> 'bayNo' AS integer) AS bay_number,
        CAST(shelf_element ->> 'width' AS numeric) AS shelf_width,
        shelf_index AS shelf_number
    FROM
        output_store_pog osp
        CROSS JOIN LATERAL jsonb_array_elements(CAST(osp.pog AS jsonb) -> 'planogram' -> 'bays') AS bay
        CROSS JOIN LATERAL jsonb_array_elements(bay -> 'shelves')
        WITH ORDINALITY AS shelf (shelf_element, shelf_index)
    WHERE
        osp.filter_config_id IN ({{gen_id}})
            AND osp.base_pog_id IN ({{bpid}}) GROUP BY osp.store, bay, shelf_element, shelf_index)
            SELECT DISTINCT
                store_code, bay_number, shelf_width, shelf_number FROM shelf_data ORDER BY store_code, bay_number, shelf_number
