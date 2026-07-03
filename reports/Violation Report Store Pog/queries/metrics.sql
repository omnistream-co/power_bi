WITH merchflow_projects AS (
    SELECT
        1 AS project_id,
        flow_filter_config.review_id,
        flow_filter_config.id AS filter_config_id
    FROM
        flow_filter_config
),
v_merchflow_projects_temp AS (
    SELECT DISTINCT
        p.project_id,
        s.store,
        p.review_id,
        p.filter_config_id,
        s.base_pog_id,
        MAX(s.id) AS id
FROM
    output_store_pog s
    JOIN merchflow_projects p ON s.filter_config_id = p.filter_config_id
        AND s.is_latest_version = TRUE
GROUP BY
    p.project_id,
    s.store,
    p.review_id,
    p.filter_config_id,
    s.base_pog_id
)
SELECT
    osp.store AS store_code,
    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'returnOnSpace')::numeric / 100) AS return_on_space,
    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'shelfAlignment')::numeric / 100) AS shelf_alignment,
    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'dosMos')::numeric / 100) AS dos_mos,
    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'coreRange')::numeric / 100) AS core_range
FROM
    output_store_pog osp
WHERE (osp.filter_config_id, osp.base_pog_id) IN (
        SELECT
            filter_config_id,
            base_pog_id
        FROM
            v_merchflow_projects_temp)
GROUP BY
    osp.filter_config_id,
    osp.base_pog_id,
    osp.store
