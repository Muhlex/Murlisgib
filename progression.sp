#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define XP_BASE_RATE 5
#define XP_ON_KILL 10
#define XP_ON_HEADSHOT 15
#define XP_ON_KNIFE 20
#define XP_ON_SHOTGUN 5
#define XP_ON_WIN 200

int g_iRankNeededXp[] =
{       // RANK:
	0,    // 0 (unused)
	0,    // 1 (0)
	400,  // 2 (400)
	1200, // 3 (800)
	2400, // 4 (1200)
	4000, // 5 (1600)
	6000, 8000, 10000, 12000, 14000, // 6-10 (2000)
	16000, 18000, 20000, 22000, 24000, 26000, 28000, 30000, 32000, 34000,
	36000, 38000, 40000, 42000, 44000, 46000, 48000, 50000, 52000, 54000,
	56000, 58000, 60000, 62000, 64000, 66000, 68000, 70000, 72000, 74000,
	76000, 78000, 80000, 82000, 84000, 86000, 88000, 90000, 92000, 94000,
	96000, 98000, 100000, 102000, 104000, 106000, 108000, 110000, 112000, 114000,
	116000, 118000, 120000, 122000, 124000, 126000, 128000, 130000, 132000, 134000,
	136000, 138000, 140000, 142000, 144000, 146000, 148000, 150000, 152000, 154000,
	156000, 158000, 160000, 162000, 164000, 166000, 168000, 170000, 172000, 174000,
	176000, 178000, 180000, 182000, 184000, 186000, 188000, 190000, 192000, 194000
};

int g_iClientXp[MAXPLAYERS + 1];
int g_iClientRank[MAXPLAYERS + 1];

Handle g_hTimer_XpBase = INVALID_HANDLE;
Database g_db;



public Plugin myinfo =
{
	name = "Murlisgib Progression",
	author = "murlis",
	description = "XP & Rank system for unlockable items.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};



// NATIVE FUNCTIONS
// ----------------
native int Murlisgib_GetWinner();


// STOCK FUNCTIONS
// ---------------

stock void ConnectDB()
{
	char szError[255];
	g_db = SQL_Connect("murlisgib", true, szError, sizeof(szError));

	if (g_db == null)
	{
		SetFailState("Could not connect to Murlisgib database: %s", szError);
	}

	SQL_LockDatabase(g_db);
	SQL_FastQuery(g_db, "CREATE TABLE IF NOT EXISTS player (id INTEGER PRIMARY KEY AUTOINCREMENT, steam_id TEXT UNIQUE, xp INT);");
	SQL_UnlockDatabase(g_db);
}

stock void Callback_Generic(Handle hOwner, Handle hQuery, const char[] szError, any data)
{
	if (hQuery == INVALID_HANDLE)
	{
		ThrowError("SQL Error: %s", szError);
		return;
	}
}

stock void AddPlayerDB(int iClient)
{
	if (IsClientConnected(iClient) && !IsFakeClient(iClient))
	{
		char szSteamId[21];
		char szQuery[200];

		if (GetClientAuthId(iClient, AuthId_Engine, szSteamId, sizeof(szSteamId), true))
		{
			Format(szQuery, sizeof(szQuery), "INSERT INTO player (steam_id, xp) VALUES ('%s', %i)", szSteamId, 0);
			SQL_TQuery(g_db, Callback_Generic, szQuery);
		}
		else
		{
			ThrowError("Steam ID of client %i could not be retrieved from gameserver!", iClient);
		}
	}
}

stock void LoadXP(int iClient)
{
	if (IsClientConnected(iClient) && !IsFakeClient(iClient))
	{
		char szSteamId[21];
		char szQuery[200];

		if (GetClientAuthId(iClient, AuthId_Engine, szSteamId, sizeof(szSteamId), true))
		{
			Format(szQuery, sizeof(szQuery), "SELECT xp FROM player WHERE steam_id='%s' LIMIT 1;", szSteamId);
			SQL_TQuery(g_db, Callback_LoadXP, szQuery, iClient);
		}
		else
		{
			ThrowError("Steam ID of client %i could not be retrieved from gameserver!", iClient);
		}
	}
}

stock void Callback_LoadXP(Handle hOwner, Handle hQuery, const char[] szError, any iClient)
{
	if (hQuery == INVALID_HANDLE)
	{
		ThrowError("Error retrieving Client %i XP: %s", iClient, szError);
		return;
	}

	int iClientXP = -1;

	while (SQL_FetchRow(hQuery))
	{
		iClientXP = SQL_FetchInt(hQuery, 0);
	}

	if (iClientXP < 0)
	{
		AddPlayerDB(iClient);
	}
	else
	{
		g_iClientXp[iClient] = iClientXP;
		UpdateRank(iClient);
	}
}

stock void SaveXP(int iClient)
{
	if (IsClientConnected(iClient) && !IsFakeClient(iClient))
	{
		char szSteamId[21];
		char szQuery[200];

		if (GetClientAuthId(iClient, AuthId_Engine, szSteamId, sizeof(szSteamId), true))
		{
			Format(szQuery, sizeof(szQuery), "UPDATE player SET xp = %i WHERE steam_id='%s';", g_iClientXp[iClient], szSteamId);
			SQL_TQuery(g_db, Callback_Generic, szQuery);
		}
		else
		{
			ThrowError("Steam ID of client %i could not be retrieved from gameserver!", iClient);
		}
	}
}

stock void LoadXPAll()
{
	for (int iClient = 1; iClient <= MaxClients ; iClient++)
	{
		LoadXP(iClient);
	}
}

stock void SaveXPAll()
{
	for (int iClient = 1; iClient <= MaxClients ; iClient++)
	{
		SaveXP(iClient);
	}
}

stock int UpdateRank(int iClient, bool bAnnounce = false)
{
	// If current client has max Rank
	if (g_iClientRank[iClient] >= sizeof(g_iRankNeededXp) - 1)
	{
		return;
	}

	// If current client XP < needed XP for the next rank
	if (g_iClientXp[iClient] < g_iRankNeededXp[g_iClientRank[iClient] + 1])
	{
		return;
	}

	// Loop through XP <-> Rank Definitions
	for (int i = g_iClientRank[iClient] + 1; i <= sizeof(g_iRankNeededXp) - 1; i++)
	{
		if (g_iClientXp[iClient] >= g_iRankNeededXp[i])
		{
			g_iClientRank[iClient] = i;
			ApplyMVPs(iClient);

			if (bAnnounce)
			{
				PrintToChat(iClient, " \x0FYou have reached Rank: %i \x10[%i XP]", i, g_iRankNeededXp[i]);
			}
		}
		else
		{
			break;
		}
	}
}

stock void ApplyMVPs(int iClient)
{
	if (IsClientInGame(iClient))
	{
		CS_SetMVPCount(iClient, g_iClientRank[iClient]);
	}
}



// PUBLIC FUNCTIONS
// ----------------

public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);

	RegConsoleCmd("xp", Command_ShowXP);
	RegAdminCmd("setrank", Command_SetRank, ADMFLAG_SLAY);

	ConnectDB();
	LoadXPAll();
}

public void OnPluginEnd()
{
	SaveXPAll();
}

public void OnClientPostAdminCheck(int iClient)
{
	if (!IsFakeClient(iClient))
	{
		g_iClientRank[iClient] = 1;
	}

	LoadXP(iClient);
}

public void OnMapStart()
{
	g_hTimer_XpBase = CreateTimer(10.0, Timer_XpBase, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
	if (g_hTimer_XpBase != INVALID_HANDLE)
	{
		KillTimer(g_hTimer_XpBase, false);
		g_hTimer_XpBase = INVALID_HANDLE;
	}

	SaveXPAll();
}

public void OnClientDisconnect(int iClient)
{
	SaveXP(iClient);
}

public Action Timer_XpBase(Handle hTimer)
{
	for (int iClient = 1; iClient <= MaxClients ; iClient++)
	{
		if (IsClientInGame(iClient) && !IsFakeClient(iClient) && GetClientTeam(iClient) > 1)
		{
			g_iClientXp[iClient] += XP_BASE_RATE;
			PrintToChat(iClient, " \x0DAwarded %iXP for playing.", XP_BASE_RATE);

			UpdateRank(iClient, true);
		}
	}

	// Continue Timer
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int  iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	int  iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	bool bHeadshot = GetEventBool(event, "headshot");

	// Filter for valid clients only
	if (iAttacker < 1 || iAttacker > GetMaxHumanPlayers())
	{
		return;
	}

	// Filter for humans only
	if (IsFakeClient(iAttacker)) {
		return;
	}

	// Filter out direct suicides
	if (iVictim == iAttacker) {
		return;
	}

	// Get active weapon (returns classname instead of weaponname)
	char szWeapon[32];
	int iWeaponEdict = GetEntPropEnt(iAttacker, Prop_Data, "m_hActiveWeapon");
	GetEdictClassname(iWeaponEdict, szWeapon, sizeof(szWeapon));

	if (StrEqual(szWeapon, "weapon_mag7"))
	{
		g_iClientXp[iAttacker] += XP_ON_SHOTGUN;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Shotgun Kill.", XP_ON_SHOTGUN);
	}
	else if (bHeadshot && StrEqual(szWeapon, "weapon_hkp2000"))
	{
		g_iClientXp[iAttacker] += XP_ON_HEADSHOT;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Railgun-Headshot Kill.", XP_ON_HEADSHOT);
	}
	else if (StrEqual(szWeapon, "weapon_knife"))
	{
		g_iClientXp[iAttacker] += XP_ON_KNIFE;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Knife Kill.", XP_ON_KNIFE);
	}
	else
	{
		g_iClientXp[iAttacker] += XP_ON_KILL;
		PrintToChat(iAttacker, " \x0DAwarded %iXP for Kill.", XP_ON_KILL);
	}

	UpdateRank(iAttacker, true);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	RequestFrame(ApplyMVPs, iClient);
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	// Cancel if warmup ended instead of an actual round
	if (reason == CSRoundEnd_GameStart)
	{
		return;
	}

	// Overwrite MVP set by the game
	for (int iClient = 1; iClient <= MaxClients ; iClient++)
	{
		if (IsClientInGame(iClient) && !IsFakeClient(iClient))
		{
			RequestFrame(ApplyMVPs, iClient);
		}
	}

	// Award Winner XP
	int iWinningClient = Murlisgib_GetWinner();

	g_iClientXp[iWinningClient] += XP_ON_WIN;
	PrintToChat(iWinningClient, " \x0DAwarded %iXP for Winning the game.", XP_ON_WIN);
}



// COMMAND FUNCTIONS
// -----------------

public Action Command_ShowXP(int iClient, int iArgs)
{
	PrintToChat(iClient, " \x0FYour total earned XP: %iXP", g_iClientXp[iClient]);
	PrintToChat(iClient, " \x0FYour Rank: %i", g_iClientRank[iClient]);
}

public Action Command_SetRank (int iClient, int iArgs)
{
	char szArg[65];
	GetCmdArg(1, szArg, sizeof(szArg));

	int iArg;
	iArg = StringToInt(szArg);

	if (iClient < 1)
	{
		return;
	}

	if ((iArg < 1) || (iArg > sizeof(g_iRankNeededXp) - 1))
	{
		PrintToChat(iClient, " \x0FYou did not enter a valid rank.");
		return;
	}

	g_iClientXp[iClient] = g_iRankNeededXp[iArg];
	g_iClientRank[iClient] = iArg;
	ApplyMVPs(iClient);

	PrintToChat(iClient, " \x0FRank set to: %i \x10[%i XP]", g_iClientRank[iClient], g_iClientXp[iClient]);
}