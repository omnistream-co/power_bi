SELECT
    review_id merchflow_id,
    status,
    osp.created_at,
    base_pog_id,
    store_pog_trigger_id,
    count(DISTINCT store)
FROM
    output_store_pog osp
    INNER JOIN flow_filter_config ffc ON osp.filter_config_id = ffc.id
WHERE
    osp.base_pog_id = '{{bpid}}'
    AND osp.filter_config_id = '{{gen_id}}'
GROUP BY
    1,
    2,
    3,
    4,
    5
