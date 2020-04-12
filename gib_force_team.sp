#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <cstrike>

public Plugin myinfo =
{
	name = "Murlisgib Force Team",
	author = "murlis",
	description = "Forces all players to join the same team.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	HookEvent("player_connect_full", Event_PlayerConnectFull);
	AddCommandListener(Command_JoinTeam, "jointeam");
}

public Action Event_PlayerConnectFull(Handle event, const char[] name, bool dontBroadcast)
{
	RequestFrame(RequestFrame_PlayerConnectFull, GetEventInt(event, "userid"));
}

public void RequestFrame_PlayerConnectFull(int iUserID)
{
	int iClient = GetClientOfUserId(iUserID);

	if (iClient && IsClientInGame(iClient))
	{
		ChangeClientTeam(iClient, CS_TEAM_CT);
	}
}

public Action Command_JoinTeam(int iClient, const char[] szCommand, int iArgCount)
{
	if (IsFakeClient(iClient))
		return Plugin_Continue;

	char szNewTeam[4];
	GetCmdArg(1, szNewTeam, sizeof(szNewTeam));

	int iTeam = StringToInt(szNewTeam); // 0 Random | 1 Spec | 2 T | 3 CT

	if (!(iTeam == CS_TEAM_SPECTATOR || iTeam == CS_TEAM_CT))
	{
		ChangeClientTeam(iClient, CS_TEAM_CT);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}
