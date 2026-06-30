SELECT
				
				    osp.store AS store_code,
				    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'returnOnSpace')::NUMERIC/100) AS return_on_space,
				    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'shelfAlignment')::NUMERIC/100) AS shelf_alignment,
				    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'dosMos')::NUMERIC/100) AS dos_mos,
				    AVG((CAST(osp.pog AS jsonb) -> 'metrics' ->> 'coreRange')::NUMERIC/100) AS coreRange
				FROM
				    output_store_pog osp
				WHERE osp.filter_config_id = '{{gen_id}}' AND osp.base_pog_id = '{{bpid}}'
				GROUP BY
				    osp.filter_config_id,
				    osp.base_pog_id,
				    osp.store
