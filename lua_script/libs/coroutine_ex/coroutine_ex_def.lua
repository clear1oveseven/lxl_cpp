
CoroutineState = {
    Dead = "dead",
    Suspended = "suspended",
    Normal = "normal",
    Running = "running",
}

CoroutineKillReason = {
    ReportError = "report_error",
    Expired = "expried",
    Other = "other",
}

function ex_coroutine_running()
    return CoroutineExMgr.get_running()
end

function ex_coroutine_create(main_logic, over_fn)
    return CoroutineExMgr.create_co(main_logic, over_fn)
end

function ex_coroutine_start(co, ...)
    return co:start(...)
end

function ex_coroutine_resume(co, ...)
    -- log_debug("ex_coroutine_resume %s %s", tostring(co),  debug.traceback())
    return co:resume(...)
end

function ex_coroutine_delay_resume(co, ...)
    local key = co:get_key()
    local n, params = Functional.varlen_param_info(...)
    CoroutineExMgr.add_delay_execute_fn(function()
        local ex_co = CoroutineExMgr.get_co(key)
        if ex_co then
            ex_coroutine_resume(ex_co, table.unpack(params, 1, n))
        end
    end)
end

function ex_coroutine_yield(co, ...)
    return co:yield(...)
end

function ex_coroutine_status(co)
    return co:status()
end

function delay_execute(fn)
    CoroutineExMgr.add_delay_execute_fn(fn)
end

function new_coroutine_callback(co)
    return Functional.make_closure(function(...)
        ex_coroutine_delay_resume(co, ...)
    end)
end

function ex_coroutine_expired(co, ms)
    co:expired_after_ms(ms)
end

function ex_coroutine_cancel_expried(co)
    co:cancel_expried()
end

function ex_coroutine_kill(co, kill_reason, error_msg)
    co:kill(kill_reason, error_msg)
end

function ex_coroutine_report_error(co, error_msg)
    co:report_error(error_msg)
end