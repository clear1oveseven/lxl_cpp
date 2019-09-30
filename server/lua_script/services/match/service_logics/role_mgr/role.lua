
Role = Role or class("Role")

function Role:ctor(role_id)
    self.role_id = role_id
    self.match_type = nil
    self.match_cell_id = nil
    self.match_room_id = nil
    self.game_client = nil
    self.game_session_id = nil
end

function Role:set_match_cell(match_type, match_cell_id)
    self.match_type = match_type
    self.match_cell_id = match_cell_id
end

function Role:clear_match_cell()
    self.match_type = nil
    self.match_cell_id = nil
end


