#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <smlib>
#include <dynamic>

#include <murlisgib>

#define KILLSTREAK_COLOR_

#define SND_KILLSTREAK_1 "ui/xp_milestone_01.wav"
#define SND_KILLSTREAK_2 "ui/xp_milestone_02.wav"
#define SND_KILLSTREAK_3 "ui/xp_milestone_03.wav"
#define SND_KILLSTREAK_4 "ui/xp_milestone_04.wav"
#define SND_KILLSTREAK_5 "ui/xp_milestone_05.wav"
#define SND_KILLSTREAK_VOLUME 0.16

#define SND_KILLSTREAK_MILESTONE "ui/xp_levelup.wav"
#define SND_KILLSTREAK_MILESTONE_VOLUME 0.3

ConVar g_cv_gib_killstreaks_enable;
ConVar g_cv_gib_killstreaks_announce_text;
ConVar g_cv_gib_killstreaks_announce_sound;

public Plugin myinfo =
{
	name = "Murlisgib Killstreak",
	author = "murlis",
	description = "Announces Player's Killstreaks.",
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

	// Create Member for current Killstreak-Count
	dGibPlayerData.SetInt("iKillstreak", 0);

	// Hook Changes of Player gib_data Object
	dGibPlayerData.HookChanges(DynamicChange_GibPlayerData);
	SerialiseDynamic(dGibPlayerData);
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	g_cv_gib_killstreaks_enable =
	CreateConVar("gib_killstreaks_enable", "1", "Enable Killstreak-Tracking.");
	g_cv_gib_killstreaks_announce_text =
	CreateConVar("gib_killstreaks_announce_text", "2", "Print Killstreak-Milestones to Chat. 0 = None; 1 = Local; 2 = Global");
	g_cv_gib_killstreaks_announce_sound =
	CreateConVar("gib_killstreaks_announce_sound", "2", "Play Sound on Killstreak-Milestone. 0 = None; 1 = Local; 2 = Global");

	HookEvent("player_death", GameEvent_PlayerDeath);
}

public void OnAllPluginsLoaded()
{
	// After Dynamic is initialised, hook the Player-Data of every connected Player
	LOOP_CLIENTS (iClient, CLIENTFILTER_INGAME)
	{
		InitializePlayer(iClient);
	}
}

public void OnMapStart()
{
	PrecacheSound(KILLSTREAK_1);
	PrecacheSound(KILLSTREAK_2);
	PrecacheSound(KILLSTREAK_3);
	PrecacheSound(KILLSTREAK_4);
	PrecacheSound(KILLSTREAK_5);
	PrecacheSound(KILLSTREAK_MILESTONE);
}

public void OnClientPutInServer(int iClient)
{
	// Once a new Player connects, hook their Player-Data
	InitializePlayer(iClient);
}

/*
 *
 * Game-Event Hooks
 */

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iVictim = GetClientOfUserId(GetEventInt(eEvent, "userid"));

	// Exclude invalid Cases where Victim is no longer ingame
	if (!Client_IsIngame(iVictim))
	{
		return;
	}

	// Reset Killstreak on Death
	Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iVictim).GetDynamic("gib_data");
	dGibPlayerData.SetInt("iKillstreak", 0);
}

/*
 *
 * Other Hooks
 */

public void DynamicChange_GibPlayerData(Dynamic dGibPlayerData, DynamicOffset doOffset, const char[] szMember, Dynamic_MemberType dmtType)
{
	// Only Hook Changes to Kills
	if (!StrEqual(szMember, "iKills"))
	{
		return;
	}

	// Save Kill-Stat from last Call
	static int iKillsPre[MAXPLAYERS + 1];

	int iClient = view_as<int>(Dynamic_GetParent(dGibPlayerData));
	int iKills  = dGibPlayerData.GetInt("iKills");

	if (iKills > iKillsPre[iClient])
	{
		// Increase Killstreak by one
		int iKillstreak  = dGibPlayerData.GetInt("iKillstreak");
		dGibPlayerData.SetInt("iKillstreak", ++iKillstreak);

		PrintToChatAll("Client %i Killstreak: %i", iClient, iKillstreak);
	}

	iKillsPre[iClient] = iKills;
}