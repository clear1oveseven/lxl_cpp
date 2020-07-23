
---@class GameRole
GameRole = GameRole or class("GameRole")

function GameRole:ctor(mgr, user_id, role_id)
    self._mgr = mgr
    self._user_id = user_id
    self._role_id = role_id
    self._state = Game_Role_State.free
    self._gate_server_key = nil
    self._gate_netid = nil
    self._world_server_key = nil

    self._db_ret = nil
    self._is_dirty = false
end

function GameRole:init()

end

function GameRole:init_from_db(db_ret)
    self._db_ret = db_ret
    return true
end

function GameRole:save_to_db(db_client, db_name, coll_name)

end

function GameRole:check_and_save(db_client, db_name, coll_name, is_force)
    local need_save = is_force or self:is_dirty()
    if need_save then
        self:save_to_db(db_client, db_name, coll_name)
    end
end

function GameRole:is_dirty()
    return self._is_dirty
end

function GameRole:get_user_id()
    return self._user_id
end

function GameRole:get_role_id()
    return self._role_id
end


function GameRole:set_state(val)
    self._state = val
end

function GameRole:get_state()
    return self._state
end

function GameRole:set_gate(gate_server_key, gate_netid)
    self._gate_server_key = gate_server_key
    self._gate_netid = gate_netid
end

function GameRole:get_gate()
    return self._gate_server_key, self._gate_netid
end

function GameRole:get_world_server_key()
    return self._world_server_key
end

function GameRole:set_world_server_key(val)
    log_print("GameRole:set_world_server_key", val)
    self._world_server_key = val
end


