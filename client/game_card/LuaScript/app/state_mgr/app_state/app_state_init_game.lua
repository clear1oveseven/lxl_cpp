
AppStateInitGame = AppStateInitGame or class("AppStateInitGame", AppStateBase)

function AppStateInitGame:ctor(state_mgr, main_logic)
    AppStateInitGame.super.ctor(self, state_mgr, App_State_Name.init_game, main_logic)
end

function AppStateInitGame:on_enter(params)
    AppStateInitGame.super.on_enter(self, params)
    self.main_logic.ui_panel_mgr:prepare_assets()
end

function AppStateInitGame:on_update()
    AppStateInitGame.super.on_update(self)
    if self:is_all_done() then
        self.state_mgr:change_state(App_State_Name.in_game)
    end
end

function AppStateInitGame:on_exit()
    AppStateInitGame.super.on_exit(self)
end

function AppStateInitGame:is_all_done()
    return true
end