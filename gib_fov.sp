#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define DEFAULT_FOV 90

int g_iFOV = DEFAULT_FOV;
ConVar g_cv_gib_fov;

public Plugin myinfo =
{
	name = "Murlisgib FOV Changer",
	author = "murlis",
	description = "Changes all player's Field Of View.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

public void OnPluginStart()
{
	char szFOV[4];
	IntToString(g_iFOV, szFOV, sizeof(szFOV));

	g_cv_gib_fov = CreateConVar("gib_fov", szFOV, "Sets all Player's FOV on next Spawn.");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookConVarChange(g_cv_gib_fov, ConVarChange_FOV);
}

public void ConVarChange_FOV(ConVar cvConvar, char[] szOldValue, char[] szNewValue)
{
	int iNewFOV = StringToInt(szNewValue);

	if (iNewFOV != 0)
	{
		g_iFOV = iNewFOV;
	}
}

public Action Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(eEvent, "userid"));

	SetEntProp(iClient, Prop_Send, "m_iFOV", g_iFOV);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", g_iFOV);
}