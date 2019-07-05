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
 * Public Forwards
 */

public void OnPluginStart()
{
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