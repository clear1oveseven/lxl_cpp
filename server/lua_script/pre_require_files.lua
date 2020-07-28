local files = {
    "common.log",
    "common.error_handler",
    "libs.functional",
    "libs.class",
    "libs.string_ext",
    "libs.table_ext",
    "libs.type_check",
    "libs.assert",
    "libs.path_ext",
    "libs.random",
    "libs.xml2lua.xml2lua_ext",
    "rapidjson",
    "pb",
    "lpeg",
    "tryuselualib",
    "lfs",
    "libs.coroutine_ex.coroutine_ex_def",
    "libs.coroutine_ex.coroutine_ex",
    "libs.coroutine_ex.coroutine_ex_mgr",
    "libs.net.net_handler",
    "libs.net.net_cnn",
    "libs.net.net_listen",
    "libs.net.pid_bin_cnn",
    "libs.net.http_rsp_cnn",
    "libs.net.net",
    "libs.net.net_handler_map",
    "libs.net.cnn_handler_map",
    "libs.http.http_def",
    "libs.http.http_service",
    "libs.http.http_client",
    "libs.mongo.mongo_def",
    "libs.mongo.mongo_client",
    "libs.mongo.mongo_options",
    "libs.redis.redis_def",
    "libs.redis.redis_client",
    "libs.redis.redis_reply",
    "libs.redis.redis_result",
    "libs.etcd.etcd_client_def",
    "libs.etcd.etcd_client",
    "libs.etcd.etcd_client_op_base",
    "libs.etcd.etcd_client_op_delete",
    "libs.etcd.etcd_client_op_get",
    "libs.etcd.etcd_client_op_set",
    "libs.etcd.etcd_client_result",
    "libs.etcd.etcd_client_cxx",
    "libs.hotfix",
    "common.date_time",
    "common.sequencer",
    "common.zone_service_mgr.zone_service_mgr_def",
    "common.zone_service_mgr.zone_service_mgr",
    "common.zone_service_mgr.zone_service_state",
    "common.zone_service_mgr.zone_service_mgr__peer_connect",
    "common.zone_service_mgr.zone_service_mgr__accept_connect",

    "libs.proto_parser.proto_store_base",
    "libs.proto_parser.protobuf_store",
    "libs.proto_parser.sproto_store",
    "libs.proto_parser.proto_parser",
    "common.timer.timer",
    "common.timer.timer_proxy",
    "common.event.event_mgr",
    "common.event.event_proxy",
    "common.msg_handler.msg_handler_base",
    "common.msg_handler.zone_service_msg_handler_base",
    "common.rpc.rpc_def",
    "common.rpc.rpc_mgr_base",
    "common.rpc.rpc_req",
    "common.rpc.rpc_rsp",
    "common.rpc.rpc_client",
    "common.rpc.zone_service.zone_service_rpc_mgr",
    "services.common.service_def",
    "services.service_base",
    "services.common.rpc.match_rpc_def",
    "services.common.rpc.fight_rpc_def",
    "services.common.rpc.game_rpc_def",
    "services.common.rpc.gate_rpc_def",
    "services.common.rpc.world_rpc_def",
    "services.common.rpc.room_rpc_def",
    "share.common.error.error_def",
    "share.common.error.error_login_process",
    "share.common.error.error_match",
    "share.common.error.error_room",
    "share.common.reason.reason_define",
    "share.common.match.match_define",
    "share.common.match.match_reason_define",
    "share.common.fight.fight_define",
    "share.common.fight.error_fight",
    "share.common.fight.reason_fight",
    "services.service_module.service_module_def",
    "services.service_module.service_module",
    "services.service_module.service_module_mgr",
    "services.service_module.service_listen_module",
    "services.service_module.client_cnn_mgr_base",
    "services.service_module.zone_net_module",
    "services.service_module.hotfix_module",
    "services.service_module.http_net_module",
    "services.service_module.mongo_client_module",
    "services.service_module.redis_client_module",
    "services.service_module.database_uuid_module",
    "services.service_module.service_logic_mgr.service_logic_def",
    "services.service_module.service_logic_mgr.service_logic_mgr",
    "services.service_module.service_logic_mgr.service_logic",
    "share.game_proto.game_pids",
    "share.game_proto.game_pid_proto_map",
    "share.game_proto.game_proto_files",
    "services.service_bases.game_service_base.game_service_base",
    "services.service_bases.game_service_base.game_all_service_config",
    "common.init_global_vars",
}
return files