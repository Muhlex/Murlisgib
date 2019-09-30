#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <smlib>

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

void SetFOV(int iClient, int iFOV)
{
	SetEntProp(iClient, Prop_Send, "m_iFOV", iFOV);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", iFOV);
}

public void OnPluginStart()
{
	char szFOV[4];
	IntToString(g_iFOV, szFOV, sizeof(szFOV));

	g_cv_gib_fov = CreateConVar("gib_fov", szFOV, "Set Player's FoV.");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookConVarChange(g_cv_gib_fov, ConVarChange_FOV);
}

public void ConVarChange_FOV(ConVar cvConvar, char[] szOldValue, char[] szNewValue)
{
	int iNewFOV = StringToInt(szNewValue);

	// Conversion failed or Value is 0
	if (iNewFOV == 0)
		g_iFOV = DEFAULT_FOV;
	else if (iNewFOV > 120)
		g_iFOV = 120;
	else if (iNewFOV < 60)
		g_iFOV = 60;
	else
		g_iFOV = iNewFOV;

	LOOP_CLIENTS(iClient, CLIENTFILTER_ALIVE)
	{
		SetFOV(iClient, g_iFOV);
	}
}

public Action Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(eEvent, "userid"));
	SetFOV(iClient, g_iFOV);
}