SELECT
    COUNT(DISTINCT store)
FROM
    output_store_pog osp
WHERE
    is_latest_version = TRUE
    AND osp.base_pog_id = '{{bpid}}'
    AND osp.filter_config_id = '{{gen_id}}'
