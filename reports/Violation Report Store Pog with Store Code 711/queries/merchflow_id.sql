select review_id merchflow_id, status, osp.created_at, base_pog_id , store_pog_trigger_id , count(distinct store)
				from output_store_pog osp
				inner join flow_filter_config ffc
				on osp.filter_config_id  = ffc.id
				where osp.base_pog_id='{{bpid}}'AND osp.filter_config_id = '{{gen_id}}'  
				group by 1,2,3,4,5
