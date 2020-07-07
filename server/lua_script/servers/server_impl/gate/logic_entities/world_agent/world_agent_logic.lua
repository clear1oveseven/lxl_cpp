
---@class WorldAgentLogic:LogicEntity
WorldAgentLogic = WorldAgentLogic or class("WorldAgentLogic", LogicEntity)

function WorldAgentLogic:ctor(logic_svc, logic_name)
    WorldAgentLogic.super.ctor(self, logic_svc, logic_name)
    ---@type GateClientMgr
    self._gate_client_mgr = nil
    ---@type OnlineWorldShadow
    self._world_online_shadow = nil
end

function WorldAgentLogic:_on_init()
    WorldAgentLogic.super._on_init(self)
    self._gate_client_mgr = self.logic_svc.gate_client_mgr
    self._world_online_shadow = self.server.world_online_shadow
end

function WorldAgentLogic:_on_start()
    WorldAgentLogic.super._on_start(self)
    self._gate_client_mgr:set_msg_handler(Login_Pid.req_launch_role, Functional.make_closure(self._on_msg_launch_role, self))
    -- self._gate_client_mgr:set_msg_handler(Login_Pid.req_create_role, Functional.make_closure(self._create_role, self))
end

function WorldAgentLogic:_on_stop()
    WorldAgentLogic.super._on_stop(self)
    self._rpc_svc_proxy:clear_remote_call()
    self._gate_client_mgr:set_msg_handler(Login_Pid.req_pull_role_digest, nil)
    -- self._gate_client_mgr:set_msg_handler(Login_Pid.req_create_role, nil)
end

function WorldAgentLogic:_on_release()
    WorldAgentLogic.super._on_release(self)
end

function WorldAgentLogic:_on_update()
    -- log_print("WorldAgentLogic:_on_update")
end

---@param gate_client GateClient
function WorldAgentLogic:_on_msg_launch_role(gate_client, pid, msg)
    local world_addr = self._world_online_shadow:find_server_address(gate_client.user_id)
    -- log_print("------------------------- WorldAgentLogic:_on_msg_launch_role ", world_addr, self._world_online_shadow:get_version())
--[[    local server_key = self.server.peer_net:random_server_key(Server_Role.Create_Role)
    if server_key then
        self._rpc_svc_proxy:call(function(rpc_error_num, ...)
            log_print("Rpc.create_role.method.query_roles", rpc_error_num, ...)
            gate_client:send_msg(Login_Pid.rsp_pull_role_digest, {
                error_num = rpc_error_num,
                role_digests = {},
            })
        end, server_key, Rpc.create_role.method.query_roles, gate_client.user_id, msg.role_id)
    end]]
end

function WorldAgentLogic:_create_role(gate_client, pid, msg)
    local server_key = self.server.peer_net:random_server_key(Server_Role.Create_Role)
    if server_key then
        self._rpc_svc_proxy:call(function(rpc_error_num, ...)
            log_print("Rpc.create_role.method._create_role", rpc_error_num, ...)
            gate_client:send_msg(Login_Pid.rsp_create_role, {
                error_num = rpc_error_num,
                role_id = 0,
            })
        end, server_key, Rpc.create_role.method.create_role, gate_client.user_id, msg.params)
    end
end


