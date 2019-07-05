#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <smlib>
#include <dynamic>

#include <murlisgib>

public Plugin myinfo =
{
	name = "Murlisgib Debugging Plugin",
	author = "murlis",
	description = "Provides Debugging Commands to Admins.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
  RegAdminCmd("dynshow", Command_DynShow, ADMFLAG_ROOT);
}

/*
 *
 * Command Hooks
 */

public Action Command_DynShow(int iClient, int iArgs)
{
  if (1 <= iArgs <= 2)
  {
    char szArg1[65];
    GetCmdArg(1, szArg1, sizeof(szArg1));

    char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));
    int iTarget = StringToInt(szArg2);

    if (StrEqual(szArg1, "s"))
    {
      Dynamic dGibPlayerSettings = Dynamic.GetPlayerSettings(iTarget).GetDynamic("gib_settings");
      SerialiseDynamic(dGibPlayerSettings);
    }
    if (StrEqual(szArg1, "d"))
    {
      Dynamic dGibPlayerData     = Dynamic.GetPlayerSettings(iTarget).GetDynamic("gib_data");
      SerialiseDynamic(dGibPlayerData);
    }
  }
}