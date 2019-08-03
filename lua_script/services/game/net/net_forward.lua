
NetForward = NetForward or class("NetForward", ServiceLogic)

function NetForward:ctor(logic_mgr, logic_name)
    NetForward.super.ctor(self, logic_mgr, logic_name)
    self.rpc_mgr = self.service.rpc_mgr
end

function NetForward:init()
    NetForward.super.init(self)

    local rpc_process_fns_map = {
        [GameRpcFn.client_forward_msg] = self._on_client_forward_msg,
    }

    local rpc_co_process_fns_map = {

    }
    for fn_name, fn in pairs(rpc_process_fns_map) do
        self.rpc_mgr:set_req_msg_process_fn(fn_name, Functional.make_closure(fn, self))
    end
    for fn_name, fn in pairs(rpc_co_process_fns_map) do
        self.rpc_mgr:set_req_msg_coroutine_process_fn(fn_name, Functional.make_closure(fn, self))
    end
end

function NetForward:_on_client_forward_msg(rpc_rsp, role_id, pid, msg_bytes)
    rpc_rsp:respone()
    local role = self.service.role_mgr:get_role(role_id)
    if not role then
        return
    end
    local is_ok, msg = true, nil
    if msg_bytes and PROTO_PARSER:exist(pid) then
        is_ok, msg = PROTO_PARSER:decode(pid, msg_bytes or "")
    end
    if not is_ok then
        return
    end
    -- for test
    self:to_client(role_id, pid, msg)
end

function NetForward:to_client(role_id, pid, msg)
    local is_ok, msg_bytes = true, nil
    if msg then
        if not PROTO_PARSER:exist(pid) then
            is_ok = false
        else
            is_ok, msg_bytes = PROTO_PARSER:encode(pid, msg)
        end
    end
    if not is_ok then
        log_error("NetForward:to_client fail, pid:%s", pid)
        return false
    end
    return self:to_client_bytes(role_id, pid, msg_bytes)
end

function NetForward:to_client_bytes(role_id, pid, msg_bytes)
    local role = self.service.role_mgr:get_role(role_id)
    if not role then
        return false
    end
    if not role.gate_client or not role.gate_client_netid then
        return false
    end
    role.gate_client:call(nil, GateRpcFn.game_forword_client,
            role.gate_client_netid, pid, msg_bytes)
    return true
end
