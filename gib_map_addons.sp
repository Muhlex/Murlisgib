#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define MAPNAME_OCTAGON "mg_octagon"

char szCurrentMap[128];

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
 * Functions
 */

void DisableMovement(int iClient)
{
	int iClientFlags = GetEntityFlags(iClient);
	iClientFlags |= FL_ATCONTROLS;
	SetEntityFlags(iClient, iClientFlags);
}

void EnableMovement(int iClient)
{
	int iClientFlags = GetEntityFlags(iClient);
	iClientFlags &= ~FL_ATCONTROLS;
	SetEntityFlags(iClient, iClientFlags);
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	HookEvent("player_spawn", GameEvent_PlayerSpawn);
}

public void OnMapStart()
{
	GetCurrentMap(szCurrentMap, sizeof(szCurrentMap));
}

public Action GameEvent_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(eEvent, "userid"));

	if (!IsClientInGame(iClient))
		return;

	if (StrEqual(szCurrentMap, MAPNAME_OCTAGON))
	{
		DisableMovement(iClient);
		CreateTimer(0.4, Timer_EnableMovement, GetClientUserId(iClient))
	}
}

public Action Timer_EnableMovement(Handle hTimer, int iUserid)
{
	int iClient = GetClientOfUserId(iUserid);
	EnableMovement(iClient);
}
