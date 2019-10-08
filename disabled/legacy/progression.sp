// CAREFUL THIS VERSION OF THE PLUGIN MAY OVERWRITE DATA WHEN THE DATABASE IS SLOW!

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define SOUND_RANK_UP "ui/panorama/gameover_newskillgroup_01.wav"
#define SOUND_RANK_UP_VOL 0.4

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

int   g_iClientXp[MAXPLAYERS + 1];
int   g_iClientRank[MAXPLAYERS + 1];

float g_fClientPlaytimeTimestamp[MAXPLAYERS + 1];
int   g_iClientOtherKills[MAXPLAYERS + 1];
int   g_iClientHeadshotKills[MAXPLAYERS + 1];
int   g_iClientKnifeKills[MAXPLAYERS + 1];
int   g_iClientShotgunKills[MAXPLAYERS + 1];
int   g_iWinningClient;

ConVar g_cvXPNotifications;
Handle g_hTimer_XPBase = INVALID_HANDLE;
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
native int Murlisgib_GetStatDelay();


// STOCK FUNCTIONS
// ---------------

stock void PlayClientSound(int iClient, char[] sound, float volume)
{
	EmitSoundToClient(iClient, sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

stock void ApplyMVPs(int iClient)
{
	if ((iClient >= 1) && (IsClientInGame(iClient)) && (iClient <= MaxClients))
	{
		CS_SetMVPCount(iClient, g_iClientRank[iClient]);
	}
}

stock void ResetClient(int iClient, bool bResetXP = false)
{
	if (bResetXP)
	{
		if (!IsFakeClient(iClient))
		{
			g_iClientRank[iClient] = 1;
		}
		else
		{
			g_iClientRank[iClient] = 0;
		}
	}

	g_fClientPlaytimeTimestamp[iClient] = GetGameTime();
	g_iClientOtherKills[iClient] = 0;
	g_iClientHeadshotKills[iClient] = 0;
	g_iClientKnifeKills[iClient] = 0;
	g_iClientShotgunKills[iClient] = 0;
}

stock void PrintXPReport(int iClient)
{
	DataPack dpClientInfo;

	// Get round_restart_delay as set by Instagib Plugin
	float fStatDelay = view_as<float>(Murlisgib_GetStatDelay());

	CreateDataTimer(fStatDelay, Timer_PrintXPReport, dpClientInfo);

	float fClientPlaytime = GetGameTime() - g_fClientPlaytimeTimestamp[iClient];

	dpClientInfo.WriteCell(GetClientUserId(iClient));
	dpClientInfo.WriteFloat(fClientPlaytime);
	dpClientInfo.WriteCell(g_iClientOtherKills[iClient]);
	dpClientInfo.WriteCell(g_iClientHeadshotKills[iClient]);
	dpClientInfo.WriteCell(g_iClientKnifeKills[iClient]);
	dpClientInfo.WriteCell(g_iClientShotgunKills[iClient]);
}

public Action Timer_PrintXPReport(Handle hTimer, DataPack dpClientInfo)
{
	int iClient, iClientOtherKills, iClientHeadshotKills, iClientKnifeKills, iClientShotgunKills;
	float fClientPlaytime;

	dpClientInfo.Reset();
	iClient = GetClientOfUserId(dpClientInfo.ReadCell());
	fClientPlaytime = dpClientInfo.ReadFloat();
	iClientOtherKills = dpClientInfo.ReadCell();
	iClientHeadshotKills = dpClientInfo.ReadCell();
	iClientKnifeKills = dpClientInfo.ReadCell();
	iClientShotgunKills = dpClientInfo.ReadCell();

	// Return if client disconnected
	if (iClient == 0)
	{
		return;
	}

	char szWinner[24], szTimePlayed[8];
	int iTimePlayedXP, iWinnerXP;
	int iHeadshotKillsXP, iKnifeKillsXP, iShotgunKillsXP, iOtherKillsXP;
	int iTotalXP;

	if (g_iWinningClient == iClient)
	{
		iWinnerXP = XP_ON_WIN;
		Format(szWinner, sizeof(szWinner), " \x0A| Winner \x0B[+%iXP]", iWinnerXP);
	}

	FormatTime(szTimePlayed, sizeof(szTimePlayed), "%M:%S", RoundToCeil(fClientPlaytime));

	iTimePlayedXP = RoundToCeil(fClientPlaytime) / 10 * XP_BASE_RATE;

	iHeadshotKillsXP = iClientHeadshotKills * XP_ON_HEADSHOT;
	iKnifeKillsXP    = iClientKnifeKills * XP_ON_KNIFE;
	iShotgunKillsXP  = iClientShotgunKills * XP_ON_SHOTGUN;
	iOtherKillsXP    = iClientOtherKills * XP_ON_KILL;

	iTotalXP = iTimePlayedXP + iWinnerXP + iHeadshotKillsXP + iKnifeKillsXP + iShotgunKillsXP + iOtherKillsXP;

	float fXPPercentage = GetRelativeXPPercentage(iClient);
	char szXPBar[256];
	szXPBar = GenerateProgressBar(fXPPercentage, 20, "\x0C", "\x0A");

	PrintToChat(iClient, " \x0A⸻ \x0CXP Breakdown \x0A⸻");
	PrintToChat(iClient, " \x0ATime Played \x0C(%s) \x0B[+%iXP]%s", szTimePlayed, iTimePlayedXP, szWinner);
	PrintToChat(iClient, " \x0ARailgun-Headshot Kills \x0C(%i) \x0B[+%iXP] \x0A| Knife Kills \x0C(%i) \x0B[+%iXP]",
	iClientHeadshotKills, iHeadshotKillsXP, iClientKnifeKills, iKnifeKillsXP);
	PrintToChat(iClient, " \x0AShotgun Kills \x0C(%i) \x0B[+%iXP] \x0A| Other Kills \x0C(%i) \x0B[+%iXP]",
	iClientShotgunKills, iShotgunKillsXP, iClientOtherKills, iOtherKillsXP);
	PrintToChat(iClient, " \x0CTOTAL EARNED: \x0B%iXP", iTotalXP);
	PrintToChat(iClient, " \x0B%iXP / %iXP  %s  \x0B[%.0f%%]", GetRelativeXP(iClient), GetRelativeNeededXP(iClient), szXPBar, fXPPercentage * 100);
}

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
			SQL_TQuery(g_db, Callback_LoadXP, szQuery, GetClientUserId(iClient));
		}
		else
		{
			ThrowError("Steam ID of client %i could not be retrieved from gameserver!", iClient);
		}
	}
}

stock void Callback_LoadXP(Handle hOwner, Handle hQuery, const char[] szError, any iUser)
{
	int iClient = GetClientOfUserId(iUser);

	if (hQuery == INVALID_HANDLE)
	{
		ThrowError("Error retrieving Client %i XP: %s", iClient, szError);
		return;
	}

	// -1 == No result found
	int iClientXP = -1;

	while (SQL_FetchRow(hQuery))
	{
		iClientXP = SQL_FetchInt(hQuery, 0);
	}

	// Check if same client is still in-game
	if ((iClient >= 1) && (IsClientInGame(iClient)) && (iClient <= MaxClients))
	{
		// If result found in database
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
	for (int i = g_iClientRank[iClient] + 1; i <= sizeof(g_iRankNeededXp) - 1; i++) // Start at next rank, stop at last rank
	{
		if (g_iClientXp[iClient] >= g_iRankNeededXp[i])
		{
			g_iClientRank[iClient] = i;
			ApplyMVPs(iClient);

			if (bAnnounce)
			{
				PrintToChat(iClient, " \x0A⸻ \x0CCongratulations! \x0A⸻");
				PrintToChat(iClient, " \x0BYou reached a new Rank: \x0C%i", i);
				PlayClientSound(iClient, SOUND_RANK_UP, SOUND_RANK_UP_VOL);
			}
		}
		else
		{
			break;
		}
	}
}

stock int GetRelativeXP(int iClient)
{
	int iXPCurrentRank = g_iRankNeededXp[g_iClientRank[iClient]];

	int iXPRelative = g_iClientXp[iClient] - iXPCurrentRank;

	return iXPRelative;
}

stock int GetRelativeNeededXP(int iClient)
{
	// Check for max Rank
	if (g_iClientRank[iClient] >= sizeof(g_iRankNeededXp) - 1)
	{
		return 0;
	}

	int iXPCurrentRank = g_iRankNeededXp[g_iClientRank[iClient]];
	int iXPNextRank = g_iRankNeededXp[g_iClientRank[iClient] + 1];

	int iXPRelativeNeeded = iXPNextRank - iXPCurrentRank;

	return iXPRelativeNeeded;
}

stock float GetRelativeXPPercentage(int iClient)
{
	float fXPRelative = float(GetRelativeXP(iClient));
	float fXPRelativeNeeded = float(GetRelativeNeededXP(iClient));

	// If no XP needed to next rank (usually max Rank)
	if (fXPRelativeNeeded == 0)
	{
		return 1.0;
	}

	float fXPPercentage = fXPRelative / fXPRelativeNeeded;

	return fXPPercentage;
}

stock char[] GenerateProgressBar(float fPercentage, int iBars, char[] szColorFill, char[] szColorEmpty)
{
	// Symbol Reference: █░

	int iFilledBars = RoundToCeil(fPercentage * iBars);

	// Empty Space at the Beginning is necessary for Colors
	char szXPBar[256] = " "; // XP-Bar Symbols take up more than one Character, thus using a large string

	if (iFilledBars == 0)
	{
		StrCat(szXPBar, sizeof(szXPBar), szColorEmpty);
	}
	else
	{
		StrCat(szXPBar, sizeof(szXPBar), szColorFill);
	}

	for (int iBar = 1; iBar <= iBars; iBar++)
	{
		StrCat(szXPBar, sizeof(szXPBar), "█");

		if (iBar == iFilledBars)
		{
			StrCat(szXPBar, sizeof(szXPBar), szColorEmpty);
		}
	}

	return szXPBar;
}



// PUBLIC FUNCTIONS
// ----------------

public void OnPluginStart()
{
	g_cvXPNotifications = CreateConVar("xp_notifications", "0", "Whether to show notifications in chat for every XP-awarding event.");

	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);

	RegConsoleCmd("xp", Command_ShowXP, "xp [#userid|name]");
	RegConsoleCmd("rank", Command_ShowXP, "xp [#userid|name]");
	RegAdminCmd("setrank", Command_SetRank, ADMFLAG_SLAY, "setrank <rank> [#userid|name]");

	ConnectDB();
	LoadXPAll();
}

public void OnPluginEnd()
{
	SaveXPAll();
}

public void OnClientPostAdminCheck(int iClient)
{
	LoadXP(iClient);
}

public void OnMapStart()
{
	PrecacheSound(SOUND_RANK_UP);

	g_hTimer_XPBase = CreateTimer(10.0, Timer_XPBase, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
	if (g_hTimer_XPBase != INVALID_HANDLE)
	{
		KillTimer(g_hTimer_XPBase, false);
		g_hTimer_XPBase = INVALID_HANDLE;
	}

	SaveXPAll();
}

public void OnClientDisconnect(int iClient)
{
	// Prevent saving empty data
	if (g_iClientXp[iClient] > 0)
	{
		SaveXP(iClient);
	}
	ResetClient(iClient, true);
}

public Action Timer_XPBase(Handle hTimer)
{
	for (int iClient = 1; iClient <= MaxClients ; iClient++)
	{
		if (IsClientInGame(iClient) && !IsFakeClient(iClient) && GetClientTeam(iClient) > 1)
		{
			g_iClientXp[iClient] += XP_BASE_RATE;

			if (g_cvXPNotifications.BoolValue)
			{
				PrintToChat(iClient, " \x0DAwarded %iXP for playing.", XP_BASE_RATE);
			}

			UpdateRank(iClient, true);
		}
	}

	// Continue Timer
	return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// For each Client
	for (int iClient = 1; iClient <= MaxClients ; iClient++)
	{
		// Reset Client Kill-Stats only
		ResetClient(iClient, false);
	}
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	// Cancel if warmup ended instead of an actual round
	if (reason == CSRoundEnd_GameStart)
	{
		return;
	}

	// Award Winner XP
	g_iWinningClient = Murlisgib_GetWinner();

	if (g_iWinningClient > 0)
	{
		g_iClientXp[g_iWinningClient] += XP_ON_WIN;

		if (g_cvXPNotifications.BoolValue)
		{
			PrintToChat(g_iWinningClient, " \x0DAwarded %iXP for Winning the Game.", XP_ON_WIN);
		}
	}

	// For each Client
	for (int iClient = 1; iClient <= MaxClients ; iClient++)
	{
		if (IsClientInGame(iClient) && !IsFakeClient(iClient))
		{
			// Overwrite MVP awarded by the Game on Round end
			RequestFrame(ApplyMVPs, iClient);
			// Display XP Report
			PrintXPReport(iClient);
		}
	}
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
		g_iClientShotgunKills[iAttacker]++;

		if (g_cvXPNotifications.BoolValue)
		{
			PrintToChat(iAttacker, " \x0DAwarded %iXP for Shotgun Kill.", XP_ON_SHOTGUN);
		}
	}
	else if (bHeadshot && StrEqual(szWeapon, "weapon_hkp2000"))
	{
		g_iClientXp[iAttacker] += XP_ON_HEADSHOT;
		g_iClientHeadshotKills[iAttacker]++;

		if (g_cvXPNotifications.BoolValue)
		{
			PrintToChat(iAttacker, " \x0DAwarded %iXP for Railgun-Headshot Kill.", XP_ON_HEADSHOT);
		}
	}
	else if (StrEqual(szWeapon, "weapon_knife"))
	{
		g_iClientXp[iAttacker] += XP_ON_KNIFE;
		g_iClientKnifeKills[iAttacker]++;

		if (g_cvXPNotifications.BoolValue)
		{
			PrintToChat(iAttacker, " \x0DAwarded %iXP for Knife Kill.", XP_ON_KNIFE);
		}
	}
	else
	{
		g_iClientXp[iAttacker] += XP_ON_KILL;
		g_iClientOtherKills[iAttacker]++;

		if (g_cvXPNotifications.BoolValue)
		{
			PrintToChat(iAttacker, " \x0DAwarded %iXP for Kill.", XP_ON_KILL);
		}
	}

	UpdateRank(iAttacker, true);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	// Custom MVP-Count will disappear on Spawn. This enforces it on every spawn
	RequestFrame(ApplyMVPs, iClient);
}



// COMMAND FUNCTIONS
// -----------------

public Action Command_ShowXP(int iClient, int iArgs)
{
	// If command executed by server but no Arguments given
	if ((iClient <= 0) && (iArgs < 1))
	{
		ReplyToCommand(iClient, "Usage: xp <#userid|name>");
		return Plugin_Handled;
	}

	// Specifies whose XP to show. Defaults to Client calling the Command
	int iTargetClient = iClient;

	// If a Client Name was given as an Argument
	if (iArgs >= 1)
	{
		char szArg[65];
		GetCmdArg(1, szArg, sizeof(szArg));

		char szTargetName[MAX_TARGET_LENGTH];
		int iTargetList[MAXPLAYERS], iTargetCount;
		bool bTargetIsML;

		iTargetCount = ProcessTargetString(szArg, iClient, iTargetList, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, szTargetName, sizeof(szTargetName), bTargetIsML);

		if (iTargetCount <= 0) // No matching client
		{
			ReplyToCommand(iClient, " \x0B No matching client found");
			return Plugin_Handled;
		}
		else if (iTargetCount > 1) // Multiple matching clients
		{
			ReplyToCommand(iClient, " \x0B Multiple clients found, please specify");
			return Plugin_Handled;
		}
		else // One matching client -> Success
		{
			iTargetClient = iTargetList[0];
		}
	}

	// Prepare Data for Output
	float fXPPercentage = GetRelativeXPPercentage(iTargetClient);
	char szXPBar[256];
	szXPBar = GenerateProgressBar(fXPPercentage, 20, "\x0C", "\x0A");

	char szTargetName[35];
	if (iTargetClient == iClient)
	{
		szTargetName = "Your";
	}
	else
	{
		GetClientName(iTargetClient, szTargetName, sizeof(szTargetName));
		StrCat(szTargetName, sizeof(szTargetName), "'s");
	}

	// Output
	ReplyToCommand(iClient, " \x0B%s current Rank: \x0C%i", szTargetName, g_iClientRank[iTargetClient]);
	ReplyToCommand(iClient, " \x0B%iXP / %iXP  %s  \x0B[%.0f%%]", GetRelativeXP(iTargetClient), GetRelativeNeededXP(iTargetClient), szXPBar, fXPPercentage * 100);

	return Plugin_Handled;
}

public Action Command_SetRank (int iClient, int iArgs)
{
	// If command executed by server but not enough Arguments given
	if ((iClient <= 0) && (iArgs < 2))
	{
		ReplyToCommand(iClient, "Usage: setrank <rank> <#userid|name>");
		return Plugin_Handled;
	}

	// If no Rank was given
	if ((iArgs < 1))
	{
		ReplyToCommand(iClient, " \x03Usage: setrank <rank> [#userid|name]");
		return Plugin_Handled;
	}

	// Get given Rank
	char szArg1[65];
	GetCmdArg(1, szArg1, sizeof(szArg1));

	int iArg1;
	iArg1 = StringToInt(szArg1); // Failure returns 0

	// If invalid Rank was given
	if ((iArg1 < 1) || (iArg1 > sizeof(g_iRankNeededXp) - 1))
	{
		ReplyToCommand(iClient, " \x03Invalid Rank given");
		return Plugin_Handled;
	}

	// Specifies whose Rank to set. Defaults to Client calling the Command
	int iTargetClient = iClient;

	// If a Client Name was given as an Argument
	if (iArgs >= 2)
	{
		char szArg2[65];
		GetCmdArg(2, szArg2, sizeof(szArg2));

		char szTargetName[MAX_TARGET_LENGTH];
		int iTargetList[MAXPLAYERS], iTargetCount;
		bool bTargetIsML;

		iTargetCount = ProcessTargetString(szArg2, iClient, iTargetList, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, szTargetName, sizeof(szTargetName), bTargetIsML);

		if (iTargetCount <= 0) // No matching client
		{
			ReplyToCommand(iClient, " \x03 No matching client found");
			return Plugin_Handled;
		}
		else if (iTargetCount > 1) // Multiple matching clients
		{
			ReplyToCommand(iClient, " \x03 Multiple clients found, please specify");
			return Plugin_Handled;
		}
		else // One matching client -> Success
		{
			iTargetClient = iTargetList[0];
		}
	}

	// Action
	g_iClientXp[iTargetClient] = g_iRankNeededXp[iArg1];
	g_iClientRank[iTargetClient] = iArg1;
	ApplyMVPs(iTargetClient);

	// Prepare Data for Output
	char szClientName[35];
	GetClientName(iClient, szClientName, sizeof(szClientName));

	char szTargetName[35];
	if (iTargetClient == iClient)
	{
		szTargetName = "your";
	}
	else
	{
		GetClientName(iTargetClient, szTargetName, sizeof(szTargetName));
		StrCat(szTargetName, sizeof(szTargetName), "'s");
	}

	// Output
	ReplyToCommand(iClient, " \x03You set \x0E%s \x03Rank to: \x0C%i \x0B[%i Total XP]", szTargetName, g_iClientRank[iTargetClient], g_iClientXp[iTargetClient]);

	if (iTargetClient != iClient)
	{
		PrintToChat(iTargetClient, " \x0E%s \x03set your Rank to: \x0C%i \x0B[%i Total XP]", szClientName, g_iClientRank[iTargetClient], g_iClientXp[iTargetClient]);
	}

	return Plugin_Handled;
}