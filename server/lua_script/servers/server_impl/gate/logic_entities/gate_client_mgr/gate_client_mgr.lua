
---@class GateClientMgr:LogicEntity
GateClientMgr = GateClientMgr or class("GateClientMgr", LogicEntity)

function GateClientMgr:ctor(logic_svc, logic_name)
    GateClientMgr.super.ctor(self, logic_svc, logic_name)
    self._gate_clients = {}
    ---@type ClientNetService
    self._client_net_svc = self.server.client_net
    self._msg_handlers = {}
    ---@type ProtoParser
    self._pto_parser = self.server.pto_parser
end

function GateClientMgr:_on_init()
    GateClientMgr.super._on_init(self)
    -- self:setup_proto_handler()

    ---@type ClientNetServiceCnnCallback
    local cnn_cbs = {}
    cnn_cbs.on_open = Functional.make_closure(self._client_net_svc_cnn_on_open, self)
    cnn_cbs.on_close = Functional.make_closure(self._client_net_svc_cnn_on_close, self)
    cnn_cbs.on_recv = Functional.make_closure(self._client_net_svc_cnn_on_recv, self)
    self._client_net_svc:set_cnn_cbs(cnn_cbs)
end

function GateClientMgr:_on_start()
    GateClientMgr.super._on_start(self)

    local Tick_Span_Ms = 2 * 1000
    self._timer_proxy:firm(Functional.make_closure(self._on_tick, self), Tick_Span_Ms, -1)
end

function GateClientMgr:_on_stop()
    GateClientMgr.super._on_stop(self)
    self._timer_proxy:release_all()
end

function GateClientMgr:_on_release()
    GateLogic.super._on_release(self)
end

function GateClientMgr:_on_update()
    GateLogic.super._on_update(self)
end

---@param client_net_svc ClientNetService
function GateClientMgr:_client_net_svc_cnn_on_open(client_net_svc, netid)
    log_print("GateClientMgr:_client_net_svc_cnn_on_open", netid)
    local cnn = client_net_svc:get_cnn(netid)
    if not cnn then
        return
    end

    if self._gate_clients[netid] then
        log_error("GateClientMgr:_client_net_svc_cnn_on_open unknown error: repeated netid %s", netid)
        cnn:reset()
        return
    end

    local gate_client = GateClient:new(cnn)
    self._gate_clients[netid] = gate_client
end

function GateClientMgr:_client_net_svc_cnn_on_close(client_net_svc, netid, error_code)
    local gate_client = self._gate_clients[netid]
    if not gate_client then
        return
    end
    self._gate_clients[netid] = nil
end

function GateClientMgr:_client_net_svc_cnn_on_recv(client_net_svc, netid, pid, bin)
    -- log_print("GateClientMgr:_client_net_svc_cnn_on_recv", netid, pid)

    local handle_fn = self._msg_handlers[pid]
    if not handle_fn then
        log_warn("GateClientMgr:_client_net_svc_cnn_on_recv not set handle function for pid %s", pid)
        return
    end

    local gate_client = self._gate_clients[netid]
    if not gate_client then
        local cnn = client_net_svc:get_cnn(netid)
        if cnn then
            cnn:reset()
        end
        return
    end

    local is_ok, msg = self._pto_parser:decode(pid, bin)
    if is_ok then
        handle_fn(gate_client, pid, msg)
    end

    -- gate_client.cnn:send_msg(pid + 1, {})
end

function GateClientMgr:_on_tick()

end

function GateClientMgr:get_client(netid)
    return self._gate_clients[netid]
end

function GateClientMgr:set_msg_handler(pid, handler)
    if handler then
        assert(is_function(handler))
        assert(not self._msg_handlers[pid])
    end
    self._msg_handlers[pid] = handler
end