#pragma once

extern "C"
{
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}

#include "sol/sol.hpp"

extern const int Args_Index_Server_Name;
extern const int Args_Index_WorkDir;
extern const int Args_Index_Data_Dir;
extern const int Args_Index_Config_File;
extern const int Args_Index_Lua_Dir;
extern const int Args_Index_Min_Value;

extern const char *Lua_File_Prepare_Env;
extern const char *Const_Lua_Args_Begin;
extern const char *Const_Opt_Lua_Path;
extern const char *Const_Opt_C_Path;
extern const char *Const_Opt_Data_Dir;
extern const char *Const_Opt_Config_File;
extern const char *Const_Opt_Server_Name;
extern const char *Const_Opt_Native_Other_Params;

extern void * LuaAlloc(void *ud, void *ptr, size_t osize, size_t nsize);
extern int lua_panic_error(lua_State* L);
extern int lua_pcall_error(lua_State* L);
extern bool StartLuaScript(lua_State *L, std::string script_root_dir, int argc, char **argv, const std::vector<std::string> &extra_args);
extern std::vector<std::string> ServiceMakeLuaExtraArgs(int argc, char ** argv);

extern std::string ExtractServiceName(std::string full_name);
extern int ExtractServiceIdx(std::string full_name);
extern void try_quit_game();