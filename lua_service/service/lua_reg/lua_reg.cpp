#include "lua_reg.h"

sol::table get_or_create_table(lua_State *L, std::string tb_name)
{
	sol::state_view lsv(L);
	sol::object v = lsv.get<sol::object>(tb_name);
	if (!v.is<sol::table>())
	{
		assert(v.is<sol::nil_t>()); // ���table�����ڣ���ôֻӦ��Ϊnil��������и�����Ч���ݵķ���
		lsv.create_named_table(tb_name);
	}
	return lsv[tb_name];
}

void register_native_libs(lua_State *L)
{
	sol::state_view sv(L);
	sol::table t = get_or_create_table(L, TB_NATIVE);
	lua_reg_net(L);
}