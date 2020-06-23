
local Logic_State = {
    free = "free",
    reset_all = "reset_all",
    wait_join_cluster = "wait_join_cluster",
    joined_cluster = "joined_cluster",
    pull_persistent_data = "pull_persistent_data",
    pulled_persistent_data = "pulled_persistent_data",
    diff_online_server_data = "diff_online_server_data",
    persist_online_server_data = "persist_online_server_data",
    lead_world_rehash = "lead_world_rehash",
    guarantee_data_valid = "guarantee_data_valid",
    released = "released",
}

local Opera_Name = {
    query_db_version = "query_db_version",
    query_db_adjusting_version = "query_db_adjusting_version",
    query_db_online_servers = "query_db_online_servers",

    set_db_version = "set_db_version",
    set_db_adjusting_version = "set_db_adjusting_version",
    set_db_online_servers = "set_db_online_servers",
}

local Opera_State = {
    free = "free",
    acting = "acting",
    success = "success",
    fail = "fail",
}

local LEAD_WORLD_REHASH_DURATION_SEC = 10
local GUARANTEE_DATA_VALID_DURATION_SEC = 60

---@class OnlineWorldMonitor: ServiceBase
OnlineWorldMonitor = OnlineWorldMonitor or class("OnlineWorldMonitor", ServiceBase)

function OnlineWorldMonitor:ctor(service_mgr, service_name)
    OnlineWorldMonitor.super.ctor(self, service_mgr, service_name)
    ---@type RedisClient
    self._redis_key_online_world_adjusting_version = string.format(Online_World_Const.redis_key_online_world_adjusting_version_format, self.server.zone)
    self._redis_key_online_world_version = string.format(Online_World_Const.redis_key_online_world_version_format, self.server.zone)
    self._redis_key_online_world_servers = string.format(Online_World_Const.redis_key_online_world_servers_format, self.server.zone)

    log_print("self._redis_key_online_world_adjusting_version", self._redis_key_online_world_adjusting_version)
    log_print("self._redis_key_online_world_version", self._redis_key_online_world_version)
    log_print("self._redis_key_online_world_servers", self._redis_key_online_world_servers)

    self._redis_client = nil
    self._zone_setting = self.server.zone_setting

    self._curr_logic_state = Logic_State.free
    self._has_pulled_from_db = false
    self._online_world_servers = {}
    self._version = nil
    self._adjusting_version = nil
    self._opera_states = {}

    self._adjusting_online_world_servers = nil
    self._lead_world_rehash_state_over_sec = nil
    self._guarantee_data_valid_over_sec = 0
    self._last_tick_logic_sec = 0
    self._is_never_lead_rehash = true
end

function OnlineWorldMonitor:_on_init()
    OnlineWorldMonitor.super:_on_init(self)
    ---@type RedisServerConfig
    local redis_cfg = self.server.redis_online_servers_setting
    self._redis_client = RedisClient:new(redis_cfg.is_cluster, redis_cfg.host, redis_cfg.pwd, redis_cfg.thread_num, redis_cfg.cnn_timeout_ms, redis_cfg.cmd_timeout_ms)
end

function OnlineWorldMonitor:_on_start()
    OnlineWorldMonitor.super._on_start(self)
    local ret = self._redis_client:start()
    if not ret then
        self._error_num = -1
        self._error_msg = "OnlineWorldMonitor start redis client fail"
        return
    end

    self:_set_logic_state(Logic_State.reset_all)

    -- self:_try_pull_data()

    self.server.rpc:set_remote_call_handle_fn(Online_World_Rpc_Method.query_online_world_servers_data,
            Functional.make_closure(self._on_rpc_query_online_world_servers_data, self))
end

function OnlineWorldMonitor:_on_stop()
    OnlineWorldMonitor.super._on_stop(self)
    self._redis_client:stop()
    self.server.rpc:set_remote_call_handle_fn(Online_World_Rpc_Method.query_online_world_servers_data, nil)
end

function OnlineWorldMonitor:_on_release()
    OnlineWorldMonitor.super._on_release(self)
    self._curr_logic_state = Logic_State.released
end

function OnlineWorldMonitor:_on_update()
    -- log_print("OnlineWorldMonitor:_on_update")
    OnlineWorldMonitor.super._on_update(self)

    if false then
        if not self._last_sec or logic_sec() - self._last_sec > 5 then
            self._last_sec = logic_sec()

            local cmd = ""

            cmd = string.format("set %s %d", self._redis_key_online_world_adjusting_version, 10)
            self._redis_client:command(2, function(ret)
                log_print("OnlineWorldMonitor:_on_update ", self._redis_key_online_world_adjusting_version, ret)
            end, cmd)

            cmd = string.format("set %s %d", self._redis_key_online_world_version, 1)
            self._redis_client:command(2, function(ret)
                log_print("OnlineWorldMonitor:_on_update ", self._redis_key_online_world_version, ret)
            end, cmd)

           self._redis_client:command(1, nil, "del %s", self._redis_key_online_world_servers)

            --cmd = string.format("rpush %s '%s' %s", self._redis_key_online_world_servers, "hello", "world")
            --self._redis_client:command(2, function(ret)
            --    log_print("OnlineWorldMonitor:_on_update ", self._redis_key_online_world_servers, ret)
            --end, cmd)

        end
    end
    self:_tick_logic()
end

function OnlineWorldMonitor:_tick_logic()
    if not self.server.discovery:is_joined_cluster() then
        return
    end
    local now_sec = logic_sec()
    if now_sec - self._last_tick_logic_sec >= 1 then
        self._last_tick_logic_sec = now_sec
    end

    if Logic_State.reset_all == self._curr_logic_state then
        self:_reset_datas()
        self:_set_logic_state(Logic_State.wait_join_cluster)
    end

    if Logic_State.wait_join_cluster == self._curr_logic_state then
        if self.server.discovery:is_joined_cluster() then
            self:_set_logic_state(Logic_State.joined_cluster)
        end
    end

    if Logic_State.joined_cluster == self._curr_logic_state then
        self:_set_logic_state(Logic_State.pull_persistent_data)
    end

    if Logic_State.pull_persistent_data == self._curr_logic_state then
        local is_all_done = self:_check_query_db_logic()
        if is_all_done then
            self:_set_logic_state(Logic_State.pulled_persistent_data)
            assert(self._version)
        end
    end

    if Logic_State.pulled_persistent_data == self._curr_logic_state then
        self:_set_logic_state(Logic_State.diff_online_server_data)
    end

    if Logic_State.diff_online_server_data == self._curr_logic_state then
        local has_diff, allow_join_world_servers = self:_check_online_server_diff()
        -- log_print("xxxxxxxxxxxxxxxxxxxxx", has_diff, allow_join_world_servers, self._online_world_servers)
        if has_diff then
            self._adjusting_online_world_servers = allow_join_world_servers
            self._adjusting_version = self._version + 1
            self._redis_client:command(1, nil, "del %s", self._redis_key_online_world_servers)
            self:_set_logic_state(Logic_State.persist_online_server_data)
        else
            self._guarantee_data_valid_over_sec = now_sec + GUARANTEE_DATA_VALID_DURATION_SEC
            if self._is_never_lead_rehash then
                self._lead_world_rehash_state_over_sec = now_sec + LEAD_WORLD_REHASH_DURATION_SEC
                self:_set_logic_state(Logic_State.lead_world_rehash)
            else
                self:_set_logic_state(Logic_State.guarantee_data_valid)
            end
        end
    end

    if Logic_State.persist_online_server_data == self._curr_logic_state then
        -- 当如果redis集群不可达时，要想给个容错策略，
        -- 最简单的就是超时就放弃持久化，且放弃应用新配置
        -- 暂时以now_sec >= self._guarantee_data_valid_over_sec 定为超时
        local is_all_done = self:_persist_online_server_data()
        if is_all_done or now_sec >= self._guarantee_data_valid_over_sec then
            if now_sec >= self._guarantee_data_valid_over_sec then
                self._guarantee_data_valid_over_sec = now_sec + GUARANTEE_DATA_VALID_DURATION_SEC

                if is_all_done then
                    self._lead_world_rehash_state_over_sec = now_sec + LEAD_WORLD_REHASH_DURATION_SEC
                    self._version = self._adjusting_version
                    self._online_world_servers = self._adjusting_online_world_servers
                    self._adjusting_version = nil
                    self._adjusting_online_world_servers = nil
                    self:_set_logic_state(Logic_State.lead_world_rehash)
                else
                    self._adjusting_version = nil
                    self._adjusting_online_world_servers = nil
                    self:_set_logic_state(Logic_State.guarantee_data_valid)
                end
            end
        end
    end

    if Logic_State.lead_world_rehash == self._curr_logic_state then
        if now_sec >= self._lead_world_rehash_state_over_sec then
            self._lead_world_rehash_state_over_sec = nil
            self:_set_logic_state(Logic_State.guarantee_data_valid)
        else
            -- todo:尽其所能全力通知所有关联的server，rehash
            self._is_never_lead_rehash = false
            self:_notify_online_world_data()
        end
    end

    if Logic_State.guarantee_data_valid == self._curr_logic_state then
        -- 提前10秒去检查配置是否有变动,如果有变动，
        -- 在Logic_State.persist_online_server_data中等等时间走完，然后设置新值
        if now_sec >= self._guarantee_data_valid_over_sec -10 then --
            self:_set_logic_state(Logic_State.diff_online_server_data)
        end
    end
end

function OnlineWorldMonitor:_set_logic_state(state)
    self._curr_logic_state = state
end

function OnlineWorldMonitor:_get_opera_state(opera_name)
    assert(opera_name)
    local ret = Opera_State.free
    if self._opera_states[opera_name] then
        ret = self._opera_states[opera_name]
    end
    -- log_print("OnlineWorldMonitor:_get_opera_state ", opera_name, ret)
    return ret
end

function OnlineWorldMonitor:_set_opera_state(opera_name, opera_state)
    self._opera_states[opera_name] = opera_state
end

function OnlineWorldMonitor:_reset_datas()
    self._curr_logic_state = Logic_State.Free
    self._has_pulled_from_db = false
    self._online_world_servers = {}
    self._version = nil
    log_print("OnlineWorldMonitor:_reset_datas")
    self._adjusting_version = nil
    self._opera_states = {}
end

function OnlineWorldMonitor:_check_query_db_logic()
    local opera_state = Opera_State.free
    opera_state = self:_get_opera_state(Opera_Name.query_db_adjusting_version)
    if Opera_State.success ~= opera_state and Opera_State.acting ~= opera_state then
        self:_set_opera_state(Opera_Name.query_db_adjusting_version, Opera_State.acting)
        self._redis_client:command(1, function(ret)
            if Error_None ~= ret:get_error() then
                self:_set_opera_state(Opera_Name.query_db_adjusting_version, Opera_State.fail)
            else
                self:_set_opera_state(Opera_Name.query_db_adjusting_version, Opera_State.success)
                self._adjusting_version = ret:get_reply():get_number()
            end
        end, "get " .. self._redis_key_online_world_adjusting_version)
    end

    opera_state = self:_get_opera_state(Opera_Name.query_db_version)
    if Opera_State.success ~= opera_state and Opera_State.acting ~= opera_state then
        self:_set_opera_state(Opera_Name.query_db_version, Opera_State.acting)
        self._redis_client:command(1, function(ret)
            if Error_None ~= ret:get_error() then
                self:_set_opera_state(Opera_Name.query_db_version, Opera_State.fail)
            else
                self:_set_opera_state(Opera_Name.query_db_version, Opera_State.success)
                self._version = ret:get_reply():get_number() or 0
                -- log_print("!!!!!!!!!!!!!!!!!!!!!", self._version, ret)
            end
        end, "get " .. self._redis_key_online_world_version)
    end

    opera_state = self:_get_opera_state(Opera_Name.query_db_online_servers)
    if Opera_State.success ~= opera_state and Opera_State.acting ~= opera_state then
        self:_set_opera_state(Opera_Name.query_db_online_servers, Opera_State.acting)
        self._redis_client:command(1, function(ret)
            if Error_None ~= ret:get_error() then
                self:_set_opera_state(Opera_Name.query_db_online_servers, Opera_State.fail)
            else
                self:_set_opera_state(Opera_Name.query_db_online_servers, Opera_State.success)
                self._online_world_servers = {}
                if Error_None == ret:get_error() and not ret:get_reply():get_error() then
                    for _, v in pairs(ret:get_reply():get_array()) do
                        self._online_world_servers[v:get_str()] = true
                    end
                end
            end
        end, "LRANGE %s 0 -1", self._redis_key_online_world_servers)
    end

    local is_all_done = true
    for _, v in pairs({
        Opera_Name.query_db_adjusting_version,
        Opera_Name.query_db_online_servers,
        Opera_Name.query_db_version,
    }) do
        if Opera_State.success ~= self:_get_opera_state(v) then
            is_all_done = false
        end
    end
    return is_all_done
end

function OnlineWorldMonitor:_check_online_server_diff()
    local has_diff = false
    local allow_join_world_servers = {}
    local allow_join_servers = self._zone_setting:get_allow_join_servers()
    for server_key, is_allow_join in pairs(allow_join_servers) do
        if is_allow_join then
            local server_role = extract_from_cluster_server_name(server_key)
            if Server_Role.World == server_role then
                allow_join_world_servers[server_key] = true
                if not self._online_world_servers[server_key] then
                    has_diff = true
                end
            end
        end
    end
    if not has_diff then
        for server_key, _ in pairs(self._online_world_servers) do
            if not allow_join_world_servers[server_key] then
                has_diff = true
            end
        end
    end
    return has_diff, allow_join_world_servers
end

function OnlineWorldMonitor:_persist_online_server_data()
    local opera_state = Opera_State.free
    opera_state = self:_get_opera_state(Opera_Name.set_db_adjusting_version)
    local adjusting_version_alive_sec = self._guarantee_data_valid_over_sec - logic_sec()
    if adjusting_version_alive_sec < 0 then
        adjusting_version_alive_sec = 0
    end
    adjusting_version_alive_sec = adjusting_version_alive_sec + LEAD_WORLD_REHASH_DURATION_SEC
    self._redis_client:command(1, function(ret)
        self:_set_opera_state(Opera_Name.set_db_adjusting_version, Opera_State.acting)
        if Error_None ~= ret:get_error() or ret:get_reply():get_error() then
            self:_set_opera_state(Opera_Name.set_db_adjusting_version, Opera_State.fail)
        else
            self:_set_opera_state(Opera_Name.set_db_adjusting_version, Opera_State.success)
        end
    end, "SETEX %s %s %s ", self._redis_key_online_world_adjusting_version, adjusting_version_alive_sec, self._adjusting_version)

    if Opera_State.success == opera_state then
        opera_state = self:_get_opera_state(Opera_Name.set_db_version)
        if Opera_State.success ~= opera_state and Opera_State.acting ~= opera_state then
            self:_set_opera_state(Opera_Name.set_db_version, Opera_State.acting)
            self._redis_client:command(1, function(ret)
                if Error_None ~= ret:get_error() or ret:get_reply():get_error() then
                    self:_set_opera_state(Opera_Name.set_db_version, Opera_State.fail)
                else
                    self:_set_opera_state(Opera_Name.set_db_version, Opera_State.success)
                end

            end, "set %s %s", self._redis_key_online_world_version, self._adjusting_version)
        end

        opera_state = self:_get_opera_state(Opera_Name.set_db_online_servers)
        if Opera_State.success ~= opera_state and Opera_State.acting ~= opera_state then
            self:_set_opera_state(Opera_Name.set_db_online_servers, Opera_State.acting)
            if not self._adjusting_online_world_servers or not next(self._adjusting_online_world_servers) then
                self:_set_opera_state(Opera_Name.set_db_online_servers, Opera_State.success)
            else
                local cmd = string.format("rpush %s %s", self._redis_key_online_world_servers,
                        table.concat(table.keys(self._adjusting_online_world_servers), " "))
                self._redis_client:command(1, function(ret)
                    if Error_None ~= ret:get_error() or ret:get_reply():get_error() then
                        self:_set_opera_state(Opera_Name.set_db_online_servers, Opera_State.fail)
                    else
                        self:_set_opera_state(Opera_Name.set_db_online_servers, Opera_State.success)
                    end
                end, cmd)
            end
        end
    end
    local is_all_done = true
    for _, v in pairs({
        Opera_Name.set_db_adjusting_version,
        Opera_Name.set_db_version,
        Opera_Name.set_db_online_servers,
    }) do
        if Opera_State.success ~= self:_get_opera_state(v) then
            is_all_done = false
        end
    end
    return is_all_done
end

function OnlineWorldMonitor:_notify_online_world_data(to_server_key)
    local notify_servers = nil
    if to_server_key then
        notify_servers = { to_server_key }
    else
        notify_servers = self.server.peer_net:get_role_server_keys(Server_Role.World)
    end
    local send_tb = {
        version = self._version,
        servers = self._online_world_servers,
    }
    if self._guarantee_data_valid_over_sec then
        send_tb.data_valid_left_sec = self._guarantee_data_valid_over_sec - logic_sec()
    end
    if self._lead_world_rehash_state_over_sec then
        send_tb.lead_rehash_left_sec = self._lead_world_rehash_state_over_sec - logic_sec()
    end
    log_print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ", self._curr_logic_state,  send_tb)
    for _, v in pairs(notify_servers) do
        self.server.rpc:call(nil, v, Online_World_Rpc_Method.notify_online_world_servers_data, send_tb)
    end
end

---@param rsp RpcRsp
function OnlineWorldMonitor:_on_rpc_query_online_world_servers_data(rsp, ...)
    -- log_print("++++++++++++++++++++++++++++++ OnlineWorldMonitor:_on_rpc_query_online_world_servers_data", ...)
    rsp:respone()
    self:_notify_online_world_data(rsp.from_host)
end
