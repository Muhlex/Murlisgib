#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <smlib>
#include <dynamic>

#include <cstrike>

ConVar g_cv_mp_round_restart_delay;
ConVar g_cv_gib_relay_prefix;

ConVar g_cv_gib_stats_enable;
ConVar g_cv_gib_stats_kills;
ConVar g_cv_gib_stats_headshots;
ConVar g_cv_gib_stats_killstreak;
ConVar g_cv_gib_stats_relaytime;

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
				PrintToServer("this happened");
			}
			StrCat(szOutput, iOutputLength, szClientName);

			iNameCount++;
		}
	}

	return iNameCount;
}

void GenerateStatsString(const values[], int iNumValues, char[] szCaption, char[] szOutput, int iOutputLength) // only works with ints for now
{
	// Add Caption to Output
	StrCat(szOutput, iOutputLength, szCaption);

	int iTopValues[3];
	GetHighestValues(values, iNumValues, iTopValues, 3);

	char szSingleLine[512];
	char szSingleLineNames[512];

	for (int iPlace = 0; iPlace < 3; iPlace++)
	{
		if (iTopValues[iPlace] > 0)
		{
			// Create a single line of the output string

			// Add line highlights (darker 2nd & 3rd Place)
			if (iPlace == 1)
			{
				StrCat(szSingleLine, sizeof(szSingleLine), "<font color='#B2B2B2'>");
			}
			else if (iPlace >= 2)
			{
				StrCat(szSingleLine, sizeof(szSingleLine), "<font color='#8C8C8C'>");
			}

			// Retrieve name list
			GetPlacementNames(values, iTopValues[iPlace], szSingleLineNames, sizeof(szSingleLineNames));
			// Concatenate values and names
			Format(szSingleLine, sizeof(szSingleLine), "<br>[%i] %s", iTopValues[iPlace], szSingleLineNames);

			// Add single line to the output string
			StrCat(szOutput, iOutputLength, szSingleLine);

			// Clear current line strings
			Format(szSingleLine, sizeof(szSingleLine), "");
			Format(szSingleLineNames, sizeof(szSingleLineNames), "");
		}
	}
}

void StatsTest()
{
	int iPlayerKills[MAXPLAYERS + 1];

	LOOP_CLIENTS (iClient, CLIENTFILTER_NOSPECTATORS)
	{
		Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iClient).GetDynamic("gib_data");

		iPlayerKills[iClient] = dGibPlayerData.GetInt("iKills", 0);
	}

	char test[1024];

	GenerateStatsString(iPlayerKills, sizeof(iPlayerKills), "<font color='#A3FC85'>KILLS</font>", test, sizeof(test));
	PrintToServer("%s", test);
	PrintHintTextToAll("%s", test);
}

/*
 *
 * Public Forwards
 */

//wrong place this is
public Action Command_Stats(int iClient, int iArgs)
{
	StatsTest();
}

public void OnPluginStart()
{
	RegAdminCmd("sss", Command_Stats, ADMFLAG_ROOT);

	g_cv_gib_stats_enable     = CreateConVar("gib_stats_enable", "1", "Enable Stat-Display on Round End.");
	g_cv_gib_stats_kills      = CreateConVar("gib_stats_kills", "1", "Display highest Kill-Counts.");
	g_cv_gib_stats_headshots  = CreateConVar("gib_stats_headshots", "1", "Display highest Railgun Headshot-Counts.");
	g_cv_gib_stats_killstreak = CreateConVar("gib_stats_killstreak", "1", "Display highest Killstreaks.");
	g_cv_gib_stats_relaytime  = CreateConVar("gib_stats_relaytime", "1", "Display Times of Players who held the relay Weapon longest.");
}

public void OnConfigsExecuted()
{
  g_cv_mp_round_restart_delay = FindConVar("mp_round_restart_delay");
  g_cv_gib_relay_prefix       = FindConVar("gib_relay_prefix");
}

/*
 *
 * Other Hooks
 */

public Action CS_OnTerminateRound(float &fDelay, CSRoundEndReason &csrReason)
{
	// Check for an actual Round-End; Exclude the Pre-Game ending
	if (csrReason != CSRoundEnd_GameStart)
	{
		fDelay = 1.0;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}