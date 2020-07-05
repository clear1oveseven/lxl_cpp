
Client = Client or class("Client")

function Client:ctor()
    self.netid = nil
    self.cnn = nil
    self.state = Gate_Client_State.free
    self.user_id = nil
    self.launch_role_id = nil
    self.game_client = nil
    self.world_client = nil
    self.world_role_session_id = nil
    self.token = nil
end

function Client:is_authed()
    return self.state > Gate_Client_State.authing
end

function Client:is_alive()
    return self.state < Gate_Client_State.releasing
end

function Client:is_ingame()
    return Gate_Client_State.in_game == self.state
end

function Client:is_free()
    return Gate_Client_State.free == self.state
end

function Client:is_authing()
    return Gate_Client_State.authing == self.state
end

function Client:is_launching()
    return Gate_Client_State.launch_role == self.state
end

