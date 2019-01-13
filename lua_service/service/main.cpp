extern "C" 
{
	#include "lua.h"
	#include "lauxlib.h"
	#include "lualib.h"
}

#include "sol/sol.hpp"
#include <signal.h>
#include <memory>

#if WIN32
#include <WinSock2.h>
#include <direct.h>
#else
#include <arpa/inet.h>
#include <unistd.h>
#endif


#define LUA_EXIT_FAILURE -1
#define lUA_EXIT_SUCCESS 0
#define LUA_SCRIPT_IDX 1

static int lua_status_report(lua_State *L, int status) 
{
	if (status != LUA_OK) 
	{
		const char *msg = lua_tostring(L, -1);
		printf(msg);
		lua_pop(L, 1);
	}
	return status;
}

static int lua_error_handler(lua_State *L) 
{
	const char *msg = lua_tostring(L, 1);
	if (msg == NULL) 
	{
		if (luaL_callmeta(L, 1, "__tostring") && lua_type(L, -1) == LUA_TSTRING)
		{
			return 1;
		}
		else
		{
			msg = lua_pushfstring(L, "(error object is a %s value)",luaL_typename(L, 1));
		}
	}
	luaL_traceback(L, L, msg, 1);  /* append a standard traceback */
	return 1;  /* return the traceback */
}

#ifdef WIN32
#include <direct.h>
#define chdir _chdir
#else
#include <unistd.h>
#endif

/*
static void change_dir(std::string dir_path)
{
	if (dir_path.length() <= 0)
	{
		printf("chdir: not accept dir_path length which is 0 \n");
		return;
	}
	int ret = chdir(dir_path.c_str());
	if (0 != ret)
	{
		printf("chdir to dir %s fail, errno is %d \n", dir_path.c_str(), ret);
	}
}

#define NATIVE "native"

static void register_native_fns(lua_State *L)
{
	sol::state_view sv(L);
	sol::table t = sv.create_named_table(NATIVE);
	t.set_function("chdir", change_dir);
}
*/

#include "iengine.h"
class PureLuaService : public IService
{

};

class LsHandler;
class CnnHandler;
static std::shared_ptr<LsHandler> ls_handler = nullptr;
std::set<NetId> cnn_ids;
static std::vector<std::shared_ptr<INetConnectHander>> net_handlers;

class CnnHandler : public INetConnectHander
{
public:
	CnnHandler() : INetConnectHander() {}
	virtual ~CnnHandler() {}

	virtual void OnClose(int err_num) 
	{
		cnn_ids.erase(m_netid);
		log_debug("ls CnnHandler OnClose netid:{0} err_num {1} cnn_ids.size={2}", m_netid, err_num, cnn_ids.size());
	}
	virtual void OnOpen(int err_num) 
	{
		if (0 == err_num)
		{
			cnn_ids.insert(m_netid);
			net_handlers.push_back(this->GetSharedPtr());
		}
		log_debug("ls CnnHandler OnOpen netid:{0} err_num {1} cnn_ids.size()={2}", m_netid, err_num, cnn_ids.size());
	}
	virtual void OnRecvData(char *data, uint32_t len)
	{
		log_debug("ls CnnHandler OnRecvData netid:{0} len {1}", m_netid, len);
	}
};

class LsHandler : public INetListenHander
{
public:
	LsHandler() : INetListenHander() {}
	virtual ~LsHandler() {}

	virtual void OnClose(int err_num)
	{
		log_debug("ls handler OnClose netid:{0} errnu{1}", m_netid, err_num);
	}
	virtual void OnOpen(int err_num)
	{
		log_debug("ls handler OnOpen netid:{0} errnu{1}", m_netid, err_num);
	}
	virtual std::shared_ptr<INetConnectHander> GenConnectorHandler()
	{
		log_debug("ls handler GenConnectorHandler netid:{0} ", m_netid);
		return std::make_shared<CnnHandler>();
	}
};

static std::string ip = "127.0.0.1";
static int port = 2233;
static bool first_tick = true;

void OnTick()
{
	if (first_tick)
	{
		first_tick = false;
		ls_handler = std::make_shared<LsHandler>();
		NetId netid = net_listen("0.0.0.0", port, nullptr, ls_handler);
		if (netid == INVALID_NET_ID)
		{
			printf("Listen fail\n");
			exit(-1);
		}
	}

	log_debug("OnTick cnn_ids.size()  {}!", cnn_ids.size());

	if (cnn_ids.size() <= 1)
	{
		auto cnn_handler = std::make_shared<CnnHandler>();
		NetId netid = net_connect(ip, port, nullptr, cnn_handler);
		if (netid > 0)
		{
			net_handlers.push_back(cnn_handler);
			char xxx[1280];
			// net_send(cnn_handler->GetNetId(), xxx, sizeof(xxx));
		}
	}

	for (auto v : cnn_ids)
	{
		char xxx[128];
		net_send(v, xxx, sizeof(xxx));
	}
}

void QuitGame(int signal)
{
	log_debug("QuitGame");
	engine_stop();
	// exit(0);
}

int main (int argc, char **argv) 
{
#ifdef WIN32
	WSADATA wsa_data;
	WSAStartup(0x0201, &wsa_data);
	signal(SIGINT, QuitGame);
	signal(SIGBREAK, QuitGame);
#else
	signal(SIGINT, QuitGame);
	signal(SIGPIPE, SIG_IGN);
#endif

	PureLuaService xxx;
	engine_init();
	engine_loop_span(100);
	start_log(ELogLevel_Debug);
	setup_service(&xxx);
	add_firm_timer(OnTick, 100, EXECUTE_UNLIMIT_TIMES);
	engine_loop();
	engine_destroy();
	return 0;

	lua_State *L = luaL_newstate();
	if (L == NULL) 
	{
		printf("cannot create state: not enough memory");
		return LUA_EXIT_FAILURE;
	}

	{
		// open libs
		luaL_openlibs(L);
		register_native_fns(L);
	}

	lua_newtable(L);
	int top = lua_gettop(L);
	int status = LUA_OK;

	do 
	{
		for (int i = LUA_SCRIPT_IDX + 1; i < argc; i++) 
		{
			lua_pushstring(L, argv[i]);
			lua_rawseti(L, -2, i - LUA_SCRIPT_IDX);
			// printf("argv[%d]=%s\n", i, argv[i]);
		}
		lua_setglobal(L, "arg");
		char *lua_file = argv[LUA_SCRIPT_IDX];
		int status = luaL_loadfile(L, lua_file);
		if (LUA_OK != status)
		{
			lua_status_report(L, status);
			break;
		}
		int base = lua_gettop(L);
		lua_pushcfunction(L, lua_error_handler);
		lua_insert(L, base);
		status = lua_pcall(L, 0, LUA_MULTRET, base);
		lua_remove(L, base);
		if (LUA_OK != status)
		{
			printf("%s", lua_tostring(L, -1));
			break;
		}
	} while (false);

	lua_settop(L, top);
	lua_close(L);
	return status;
}

