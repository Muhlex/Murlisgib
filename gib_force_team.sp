#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>

#include <smlib>

#define COLOR_BASE "\x01"
#define COLOR_HIGHLIGHT "\x10"

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
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
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

public Action Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	if (
		bDontBroadcast
		|| eEvent.GetBool("disconnect")
		|| eEvent.GetBool("silent")
	) return Plugin_Continue;

	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	int iTeam = eEvent.GetInt("team");

	eEvent.SetBool("silent", true);

	char szClientName[33];
	GetClientName(iClient, szClientName, sizeof(szClientName));

	char szClientIdentifier[16];
	if (IsFakeClient(iClient))
		szClientIdentifier = "BOT";
	else
		szClientIdentifier = "Player";

	if (iTeam == CS_TEAM_SPECTATOR)
		PrintToChatAll(" %s%s %s%s %sis now spectating", COLOR_BASE, szClientIdentifier, COLOR_HIGHLIGHT, szClientName, COLOR_BASE);
	else
		PrintToChatAll(" %s%s %s%s %shas joined the Arena", COLOR_BASE, szClientIdentifier, COLOR_HIGHLIGHT, szClientName, COLOR_BASE);

	return Plugin_Changed;
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
