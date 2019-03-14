EtcdClientOpDelete = EtcdClientOpDelete or class("EtcdClientOpDelete", EtcdClientOpBase)

function EtcdClientOpDelete:ctor()
    EtcdClientOpSet.super.ctor(self)
    self[EtcdConst.Key] = nil
end

function EtcdClientOpDelete:get_http_url()
    if not self[EtcdConst.Key] then
        return false, ""
    end
    local keys = {
    }
    local query_str = self:concat_values(keys, "%s=%s", "&")
    local ret_str = ""
    if #query_str > 0 then
        string.format("%s?%s", self[EtcdConst.Key], query_str)
    else
        ret_str = self[EtcdConst.Key]
    end
    return true, ret_str
end

function EtcdClientOpDelete:get_http_content()
    local keys = {
    }
    local kv_foramt = "%s=%s"
    local sep = "&"
    local ret_str = self:concat_values(keys, kv_foramt, sep)
    return ret_str
end

function EtcdClientOpDelete:execute(etcd_client)
    local ret, sub_url = self:get_http_url()
    if not ret then
        return 0
    end
    local url = string.format(self.host_format, etcd_client:get_host(), sub_url)
    local op_id = HttpClient.delete(url,
            Functional.make_closure(self._handle_result_cb, op),
            Functional.make_closure(self._Handle_event_cb, op),
            self.http_heads)
    return op_id;
end

function EtcdClientOpDelete._handle_result_cb(op, op_id, url_str, heads_map, body_str, body_len)
    log_debug("EtcdClientOpDelete._handle_result_cb %s", op_id)
end