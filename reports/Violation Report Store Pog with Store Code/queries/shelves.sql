WITH params AS (
    -- Materialize filter once (filter_config_id + base_pog_id pairs)
    SELECT
        filter_config_id,
        base_pog_id
    FROM
        reporting.v_merchflow_projects_temp
)
SELECT DISTINCT
    pd.store_code,
    pd.planogram_bays_bay_no AS bay_number,
    pd.planogram_bays_shelves_width AS shelf_width,
    pd.planogram_bays_shelves_shelf_no AS shelf_number
FROM
    reporting.mv_planogram_data pd
    -- mv_osp_latest already filters is_latest_version = TRUE
    -- Join to get filter_config_id and base_pog_id for scoping
    INNER JOIN reporting.mv_osp_latest osp ON osp.id = pd.id
    INNER JOIN params p ON osp.filter_config_id = p.filter_config_id
        AND osp.base_pog_id = p.base_pog_id
    ORDER BY
        pd.store_code,
        pd.planogram_bays_bay_no,
        pd.planogram_bays_shelves_shelf_no
