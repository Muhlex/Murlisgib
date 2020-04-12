#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#include <smlib>
#include <dynamic>

#include <murlisgib>

#define COLOR_HIGHLIGHT_HEX "#E4AE39"
#define COLOR_SHADE1_HEX "#B0C3D9"
#define COLOR_SHADE2_HEX "#75818E"

#define STAT_COUNT 4
#define STAT_DISPLAY_TIME 4.0

bool g_bIsLastRound = false;
int g_iMaxRounds;

ConVar g_cv_mp_maxrounds;
ConVar g_cv_gib_railgun;

ConVar g_cv_gib_stats_enable;
ConVar g_cv_gib_stats_kills;
ConVar g_cv_gib_stats_railgun_headshots;
ConVar g_cv_gib_stats_killstreak;
ConVar g_cv_gib_stats_longest_distance_kill;

public Plugin myinfo =
{
	name = "Murlisgib Stats",
	author = "murlis",
	description = "Display advanced Player-Stats on Round End.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
 *
 * Functions
 */

void InitializePlayer(int iClient)
{
	Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iClient).GetDynamic("gib_data");

	// Create Member for Railgun Headshot-Count
	dGibPlayerData.SetInt("iRailgunHeadshotKills", 0);
	// Create Member for longest Distance Kill
	dGibPlayerData.SetFloat("fLongestDistanceKill", 0.0);
}

void GetHighestValues(const values[], int iNumValues, output[], int iNumOutputValues)
{
	for (int i = 0; i < iNumOutputValues; i++)
	{
		for (int j = 0; j < iNumValues; j++)
		{
			if (i == 0)
			{
				if (output[i] < values[j])
				{
					output[i] = values[j];
				}
			}
			else
			{
				if (output[i] < values[j] < output[i-1])
				{
					output[i] = values[j];
				}
			}
		}
	}
}

int GetPlacementNames(const values[], any checkForValue, char[] szOutput, int iOutputLength)
{
	int iNameCount;

	LOOP_CLIENTS (iClient, CLIENTFILTER_NOSPECTATORS)
	{
		char szClientName[33];
		GetClientName(iClient, szClientName, sizeof(szClientName));

		if (values[iClient] == checkForValue)
		{
			if (!StrEqual(szOutput, ""))
			{
				StrCat(szOutput, iOutputLength, ", ");
			}
			StrCat(szOutput, iOutputLength, szClientName);

			iNameCount++;
		}
	}

	return iNameCount;
}

bool GenerateStatsString(const values[], int iNumValues, char[] szCaption, char[] szSuffix, char[] szOutput, int iOutputLength) // only works with ints for now
{
	int iTopValues[3];
	GetHighestValues(values, iNumValues, iTopValues, 3);

	// Check if nobody made any progress to this stat
	if (iTopValues[0] <= 0)
	{
		return false;
	}

	// Add Caption to Output
	StrCat(szOutput, iOutputLength, szCaption);

	char szSingleLine[512];

	for (int iPlace = 0; iPlace < 3; iPlace++)
	{
		if (iTopValues[iPlace] > 0)
		{
			// Create a single line of the output string

			// Retrieve name list
			GetPlacementNames(values, iTopValues[iPlace], szSingleLine, sizeof(szSingleLine));
			// Add values to name list
			Format(szSingleLine, sizeof(szSingleLine), "<br>[%i%s] %s", iTopValues[iPlace], szSuffix, szSingleLine);

			// Prepend line highlight-HTML (darker 2nd & 3rd Place)
			if (iPlace == 1)
			{
				Format(szSingleLine, sizeof(szSingleLine), "<font color='%s'>%s", COLOR_SHADE1_HEX, szSingleLine);
			}
			else if (iPlace >= 2)
			{
				Format(szSingleLine, sizeof(szSingleLine), "<font color='%s'>%s", COLOR_SHADE2_HEX, szSingleLine);
			}

			// Add single line to the output string
			StrCat(szOutput, iOutputLength, szSingleLine);

			// Clear current line strings
			Format(szSingleLine, sizeof(szSingleLine), "");
		}
	}

	return true;
}

float DisplayStats()
{
	if (!g_cv_gib_stats_enable.BoolValue)
	{
		return 0.0;
	}

	int iPlayerKills[MAXPLAYERS + 1];
	int iPlayerRailgunHeadshotKills[MAXPLAYERS + 1];
	int iPlayerHighestKillstreak[MAXPLAYERS + 1];
	int iPlayerLongestDistanceKillMeters[MAXPLAYERS + 1];

	LOOP_CLIENTS (iClient, CLIENTFILTER_NOSPECTATORS)
	{
		Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iClient).GetDynamic("gib_data");

		iPlayerKills[iClient] = dGibPlayerData.GetInt("iKills", 0);
		iPlayerRailgunHeadshotKills[iClient] = dGibPlayerData.GetInt("iRailgunHeadshotKills", 0);
		iPlayerHighestKillstreak[iClient] = dGibPlayerData.GetInt("iHighestKillstreak", 0);
		iPlayerLongestDistanceKillMeters[iClient] = RoundToFloor(Math_UnitsToMeters(dGibPlayerData.GetFloat("fLongestDistanceKill", 0.0)));
	}

	char szHeadline[128];
	bool bShowStat[STAT_COUNT];
	char szStatsStrings[STAT_COUNT][1024];

	Format(szHeadline, sizeof(szHeadline), "<font color='%s'>MOST KILLS</font>", COLOR_HIGHLIGHT_HEX);
	bShowStat[0] = GenerateStatsString(iPlayerKills, sizeof(iPlayerKills), szHeadline, "", szStatsStrings[0], 1024);
	if (!g_cv_gib_stats_kills.BoolValue)
		bShowStat[0] = false;

	Format(szHeadline, sizeof(szHeadline), "<font color='%s'>LONGEST KILLSTREAK</font>", COLOR_HIGHLIGHT_HEX);
	bShowStat[1] = GenerateStatsString(iPlayerHighestKillstreak, sizeof(iPlayerKills), szHeadline, "", szStatsStrings[1], 1024);
	if (!g_cv_gib_stats_killstreak.BoolValue)
		bShowStat[1] = false;

	Format(szHeadline, sizeof(szHeadline), "<font color='%s'>MOST RAILGUN HEADSHOTS</font>", COLOR_HIGHLIGHT_HEX);
	bShowStat[2] = GenerateStatsString(iPlayerRailgunHeadshotKills, sizeof(iPlayerRailgunHeadshotKills), szHeadline, "", szStatsStrings[2], 1024);
	if (!g_cv_gib_stats_railgun_headshots.BoolValue)
		bShowStat[2] = false;

	Format(szHeadline, sizeof(szHeadline), "<font color='%s'>LONGEST DISTANCE KILL</font>", COLOR_HIGHLIGHT_HEX);
	bShowStat[3] = GenerateStatsString(iPlayerLongestDistanceKillMeters, sizeof(iPlayerLongestDistanceKillMeters), szHeadline, "m", szStatsStrings[3], 1024);
	if (!g_cv_gib_stats_longest_distance_kill.BoolValue)
		bShowStat[3] = false;

	float fStatDisplayDelay = 0.0;

	for (int i = 0; i < STAT_COUNT; i++)
	{
		if (bShowStat[i])
		{
			DataPack dpStatString;
			CreateDataTimer(fStatDisplayDelay, Timer_StatDisplay, dpStatString);
			dpStatString.WriteString(szStatsStrings[i]);

			fStatDisplayDelay += STAT_DISPLAY_TIME;
		}
	}

	return fStatDisplayDelay;
}

public Action Timer_StatDisplay(Handle hTimer, DataPack dpString)
{
	char szString[1024];

	dpString.Reset();
	dpString.ReadString(szString, sizeof(szString));

	PrintHintTextToAll("%s", szString);
}

public Action Timer_EndGame(Handle hTimer, int iMaxrounds)
{
	ConVar_ChangeSilentInt(g_cv_mp_maxrounds, 0);
	CreateTimer(0.5, Timer_EndGame2, iMaxrounds);
}

public Action Timer_EndGame2(Handle hTimer, int iMaxrounds)
{
	ConVar_ChangeSilentInt(g_cv_mp_maxrounds, iMaxrounds);
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	g_cv_gib_stats_enable                = CreateConVar("gib_stats_enable", "1", "Enable Stat-Display on Round End.");
	g_cv_gib_stats_kills                 = CreateConVar("gib_stats_kills", "1", "Display highest Kill-Counts.");
	g_cv_gib_stats_railgun_headshots     = CreateConVar("gib_stats_railgun_headshots", "1", "Display highest Railgun Headshot-Counts.");
	g_cv_gib_stats_killstreak            = CreateConVar("gib_stats_killstreak", "1", "Display highest Killstreaks.");
	g_cv_gib_stats_longest_distance_kill = CreateConVar("gib_stats_longest_distance_kill", "1", "Display longest Distance Kills.");
	//g_cv_gib_stats_relaytime = CreateConVar("gib_stats_relaytime", "1", "Display Times of Players who held the relay Weapon longest.");

	HookEvent("round_start",	GameEvent_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", GameEvent_PlayerDeath);
}

public void OnConfigsExecuted()
{
	g_cv_gib_railgun  = FindConVar("gib_railgun");
	g_cv_mp_maxrounds = FindConVar("mp_maxrounds");
	g_iMaxRounds = g_cv_mp_maxrounds.IntValue;
}

public void OnAllPluginsLoaded()
{
	// After Dynamic is initialised, initialize the Player-Data of every connected Player
	LOOP_CLIENTS (iClient, CLIENTFILTER_INGAME)
	{
		InitializePlayer(iClient);
	}
}

public void OnClientPutInServer(int iClient)
{
	// Once a new Player connects, initialize their Player-Data
	InitializePlayer(iClient);
}

/*
 *
 * Hooks
 */

public Action GameEvent_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	// Reset Client Stats
	LOOP_CLIENTS (iClient, CLIENTFILTER_ALL)
	{
		InitializePlayer(iClient);
	}

	// Check for second last round
	int iRoundsPlayed = GameRules_GetProp("m_totalRoundsPlayed");

	if (iRoundsPlayed + 1 == g_iMaxRounds)
	{
		// Add one Round to prevent instant game end on the next one
		ConVar_ChangeSilentInt(g_cv_mp_maxrounds, g_iMaxRounds + 1);
		g_bIsLastRound = true;
	}
	else
	{
		g_bIsLastRound = false;
	}
}

public Action CS_OnTerminateRound(float &fDelay, CSRoundEndReason &csrReason)
{
	// Check for an actual Round-End; Exclude the Pre-Game ending
	if (csrReason != CSRoundEnd_GameStart)
	{
		fDelay = DisplayStats();

		if (fDelay)
		{
			if (g_bIsLastRound)
			{
				// Force Game End by subtracting from the maxrounds limit.
				CreateTimer(fDelay - 0.5, Timer_EndGame, g_iMaxRounds);
				g_bIsLastRound = false;
			}

			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iAttacker = GetClientOfUserId(GetEventInt(eEvent, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(eEvent, "userid"));
	bool bHeadshot = GetEventBool(eEvent, "headshot");
	char szWeaponName[65];
	eEvent.GetString("weapon", szWeaponName, sizeof(szWeaponName)); // does NOT return "weapon_" prefix
	Format(szWeaponName, sizeof(szWeaponName), "weapon_%s", szWeaponName); // adds the prefix

	// Exclude invalid Cases where Victim is no longer ingame
	if (!Client_IsIngame(iVictim))
	{
		return;
	}

	Dynamic dGibAttackerData = Dynamic.GetPlayerSettings(iAttacker).GetDynamic("gib_data");

	// Check for Suicide
	if (iVictim == iAttacker || iAttacker == 0)
	{
		return;
	}
	else if (Client_IsIngame(iAttacker))
	{
		// If Kill was a Headshot
		if (bHeadshot)
		{
			char szRailgunName[65];
			g_cv_gib_railgun.GetString(szRailgunName, sizeof(szRailgunName));

			// If Headshot-Kill was made using the Railgun
			if (StrEqual(szWeaponName, szRailgunName))
			{
				// Update Attacker's Railgun Headshot Kill-Count
				int iAttackerRailgunHeadshotKills = dGibAttackerData.GetInt("iRailgunHeadshotKills");
				dGibAttackerData.SetInt("iRailgunHeadshotKills", ++iAttackerRailgunHeadshotKills);
			}
		}

		float fDistance = Entity_GetDistance(iVictim, iAttacker);
		if (fDistance > dGibAttackerData.GetFloat("fLongestDistanceKill"))
		{
			dGibAttackerData.SetFloat("fLongestDistanceKill", fDistance);
		}
	}
}
