#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>

#include <smlib>

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
	HookEvent("player_connect_full", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("cs_match_end_restart", Event_MatchRestart, EventHookMode_Pre);
	AddCommandListener(Command_JoinTeam, "jointeam");
}

public Action Event_PlayerConnect(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	CreateTimer(0.1, Timer_PlayerConnect, eEvent.GetInt("userid"));
}
Action Timer_PlayerConnect(Handle hTimer, int iUserID)
{
	int iClient = GetClientOfUserId(iUserID);

	if (iClient && IsClientInGame(iClient))
	{
		ChangeClientTeam(iClient, CS_TEAM_CT);
	}
}

public Action Event_MatchRestart(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	RequestFrame(RequestFrame_MatchRestart, eEvent.GetInt("userid"));
}
void RequestFrame_MatchRestart(int iUserID)
{
	LOOP_CLIENTS(iClient, CLIENTFILTER_NOSPECTATORS)
	{
		if (iClient && IsClientInGame(iClient))
		{
			ChangeClientTeam(iClient, CS_TEAM_CT);
		}
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
