#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define UPDATE_INTERVAL 60.0
#define FILEPATH /* SOURCEMOD PATH/ */ "serverinfo" /* /hostname.txt */

char g_szHostname[128];
ConVar g_sv_hibernate_when_empty;
ConVar g_sv_visiblemaxplayers;
bool g_bHibernateOnPluginEnd = false;

public Plugin myinfo =
{
	name = "Murlisgib Server Info",
	author = "murlis",
	description = "Provides current server metadata to be fetched by other services.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

public void OnPluginStart()
{
	g_sv_visiblemaxplayers = FindConVar("sv_visiblemaxplayers");

	// Disable hibernation to keep serverinfo up to date
	g_sv_hibernate_when_empty = FindConVar("sv_hibernate_when_empty");
	if (g_sv_hibernate_when_empty.BoolValue)
	{
		g_sv_hibernate_when_empty.BoolValue = false;
		g_bHibernateOnPluginEnd = true; // mark ConVar to be reset on plugin end
	}
	g_sv_hibernate_when_empty.AddChangeHook(ConVarChanged_Hibernate);

	ConVar cvHostname = FindConVar("hostname");
	cvHostname.GetString(g_szHostname, sizeof(g_szHostname));

	CreateTimer(UPDATE_INTERVAL, Timer_Update, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	CreateTimer(1.0, Timer_Update);
}

void ConVarChanged_Hibernate(ConVar convar, const char[] oldValue, const char[] newValue)
{
	// whenever anything else changes the ConVar, leave it like that on plugin end
	g_bHibernateOnPluginEnd = false;
}

public void OnPluginEnd()
{
	if (g_bHibernateOnPluginEnd)
		g_sv_hibernate_when_empty.BoolValue = true;
}

public Action Timer_Update(Handle timer)
{
	int iTimestamp[2];
	char szTimestamp[32];
	GetTime(iTimestamp);
	if (iTimestamp[1] == 0)
		Format(szTimestamp, sizeof(szTimestamp), "%i", iTimestamp[0]);
	else
		Format(szTimestamp, sizeof(szTimestamp), "%i%i", iTimestamp[0], iTimestamp[1]);

	int iNumClients = GetClientCount(false); // false gets connecting clients as well;
	int iMaxClients = GetMaxHumanPlayers();

	char szMap[256], szMapDisplayName[256];
	GetCurrentMap(szMap, sizeof(szMap));
	GetMapDisplayName(szMap, szMapDisplayName, sizeof(szMap));

	char szFilePath[256];
	Format(szFilePath, sizeof(szFilePath), "%s/%s.txt", FILEPATH, g_szHostname);
	BuildPath(Path_SM, szFilePath, sizeof(szFilePath), szFilePath);

	File fFile = OpenFile(szFilePath, "wb");
	char szContents[1024];

	Format(szContents, sizeof(szContents), "%s\n%i\n%i\n%s",
	       szTimestamp, iNumClients, iMaxClients, szMapDisplayName);
	fFile.WriteString(szContents, false);
	fFile.Close();

	return Plugin_Continue;
}
