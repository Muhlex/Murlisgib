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

void GetHighestValues(const values[], int numValues, output[], int numOutputValues)
{
	for (int i = 0; i < numOutputValues; i++)
	{
		for (int j = 0; j < numValues; j++)
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

void StatsTest()
{
	int playerKills[MAXPLAYERS + 1];

	int topKills[3];

	LOOP_CLIENTS (iClient, CLIENTFILTER_NOSPECTATORS)
	{
		Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iClient).GetDynamic("gib_data");

		playerKills[iClient] = dGibPlayerData.GetInt("iKills", 0);
	}

	int test[] = {12, 24, 21, 6, 21};

	GetHighestValues(test, 5, topKills, 3);

	PrintToServer("%i, %i, %i", topKills[0], topKills[1], topKills[2]);


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