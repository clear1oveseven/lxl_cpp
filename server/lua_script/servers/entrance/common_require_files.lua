
return {

    "servers.common.config.etcd_server_config",
    "servers.common.config.redis_server_config",
    "servers.common.config.mongo_server_config",

    "servers.common.const.const",
    "servers.common.rpc.rpc",
    "servers.common.pto.pto_def",
    "servers.common.error.error",

    "servers.server_impl.server_def",
    "servers.server_impl.server_base",
    "servers.server_impl.game_server_base",

    "servers.services.service_def",
    "servers.services.service_base",
    "servers.services.service_mgr_base",
    "servers.services.custom_service_help_fn",
    "servers.services.hotfix_service",

    "servers.services.join_cluster.join_cluster_service_def",
    "servers.services.join_cluster.join_cluster_service",
    "servers.services.join_cluster.zone_server_json_data",

    "servers.services.discovery.discovery_service_def",
    "servers.services.discovery.discovery_service",
    "servers.services.discovery.discovery_server_data",

    "servers.services.peer_net.peer_net_def",
    "servers.services.peer_net.peer_net_cnn_state",
    "servers.services.peer_net.peer_net_server_state",
    "servers.services.peer_net.peer_net_service",
    "servers.services.peer_net.peer_net_service_cnn_logic",

    "servers.services.rpc_service.rpc_service_def",
    "servers.services.rpc_service.rpc_service_rpc_mgr",
    "servers.services.rpc_service.rpc_service",
    "servers.services.rpc_service.rpc_service_proxy",

    "servers.services.zone_setting.zone_setting_def",
    "servers.services.zone_setting.zone_setting_service",

    "servers.services.logic_service.logic_service_def",
    "servers.services.logic_service.logic_service_base",
    "servers.services.logic_service.logic_entity_base",
    "servers.services.logic_service.game_logic_entity",

    "servers.services.client_net_service.client_net_def",
    "servers.services.client_net_service.client_net_cnn",
    "servers.services.client_net_service.client_net_service",

    "servers.services.http_net_service.http_net_service",
    "servers.services.http_net_service.http_net_service_proxy",

    "libs.etcd_watch.etcd_watch_def",
    "libs.etcd_watch.etcd_watch_result",
    "libs.etcd_watch.etcd_watcher",

    "libs.etcd_result.etcd_result_def",
    "libs.etcd_result.etcd_result",
    "libs.etcd_result.etcd_result_node",
    "libs.etcd_result.etcd_result_dir",
    "libs.etcd_result.etcd_result_node_visitor",

}
