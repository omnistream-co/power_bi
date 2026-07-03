SELECT
    osp.store AS store_code,
    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'returnOnSpace')::numeric / 100) AS return_on_space,
    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'shelfAlignment')::numeric / 100) AS shelf_alignment,
    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'dosMos')::numeric / 100) AS dos_mos,
    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'coreRange')::numeric / 100) AS coreRange
FROM
    output_store_pog osp
WHERE
    osp.filter_config_id = '{{gen_id}}'
    AND osp.base_pog_id = '{{bpid}}'
GROUP BY
    osp.filter_config_id,
    osp.base_pog_id,
    osp.store
