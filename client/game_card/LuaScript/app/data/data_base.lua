
---@class DataBase:EventMgr
DataBase = DataBase or class("DataBase", EventMgr)

function DataBase:ctor(data_mgr, name)
    DataBase.super.ctor(self)
    ---@type DataMgr
    self._data_mgr = data_mgr
    ---@type LuaApp
    self._app = self._data_mgr._app
    self._name = name
    ---@type EventBinder
    self._event_binder = EventBinder:new()
end

function DataBase:get_name()
    return self._name
end

function DataBase:init()
    self:_on_init()
end

function DataBase:release()
    self:cancel_all()
    self:_on_release()
end

function DataBase:_on_init()

end

function DataBase:_on_release()

end