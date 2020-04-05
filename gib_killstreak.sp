#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <smlib>
#include <dynamic>

#include <murlisgib>

#define COLOR_BASE "\x0D"
#define COLOR_NAME "\x01"
#define COLOR_HIGHLIGHT "\x10"
#define COLOR_LOWLIGHT "\x0F"

#define SND_KILLSTREAK_1 "ui/xp_milestone_01.wav"
#define SND_KILLSTREAK_2 "ui/xp_milestone_02.wav"
#define SND_KILLSTREAK_3 "ui/xp_milestone_03.wav"
#define SND_KILLSTREAK_4 "ui/xp_milestone_04.wav"
#define SND_KILLSTREAK_5 "ui/xp_milestone_05.wav"
#define SND_KILLSTREAK_VOLUME 0.35

#define SND_KILLSTREAK_MILESTONE "ui/xp_levelup.wav"
#define SND_KILLSTREAK_MILESTONE_VOLUME 0.5

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

void InitializeServer()
{
	Dynamic dGibData       = Dynamic.GetSettings().GetDynamic("gib_data");

	// Hook Changes of Server gib_data Object
	dGibData.HookChanges(DynamicChange_GibData);
}

void InitializePlayer(int iClient)
{
	Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iClient).GetDynamic("gib_data");

	// Create Member for current Killstreak-Count
	dGibPlayerData.SetInt("iKillstreak", 0);
	// Create Member for highest Killstreak-Count
	dGibPlayerData.SetInt("iHighestKillstreak", 0);

	// Hook Changes of Player gib_data Object
	dGibPlayerData.HookChanges(DynamicChange_GibPlayerData);
}

void PrintKillstreak(int iClient, int iKillstreak)
{
	if (iKillstreak < 5)
	{
		return;
	}

	if (1 <= g_cv_gib_killstreaks_announce_text.IntValue <= 2)
	{
		if (iKillstreak % 5 == 0)
		{
			// Get Client's Name
			char szClientName[33];
			GetClientName(iClient, szClientName, sizeof(szClientName));

			// Display Killstreak-Announcement
			if (g_cv_gib_killstreaks_announce_text.IntValue == 1)
			{
				PrintToChat(iClient, " %s%s%s is on a %s%i %sKillstreak!",
				COLOR_NAME, szClientName, COLOR_BASE, COLOR_HIGHLIGHT, iKillstreak, COLOR_BASE);
			}
			else if (g_cv_gib_killstreaks_announce_text.IntValue == 2)
			{
				PrintToChatAll(" %s%s%s is on a %s%i %sKillstreak!",
				COLOR_NAME, szClientName, COLOR_BASE, COLOR_HIGHLIGHT, iKillstreak, COLOR_BASE);
			}
		}
	}

	if (1 <= g_cv_gib_killstreaks_announce_sound.IntValue <= 2)
	{
		switch (iKillstreak % 5)
		{
			case 1:
			{
				Sound_PlayUIClient(iClient, SND_KILLSTREAK_1, SND_KILLSTREAK_VOLUME);
			}
			case 2:
			{
				Sound_PlayUIClient(iClient, SND_KILLSTREAK_2, SND_KILLSTREAK_VOLUME);
			}
			case 3:
			{
				Sound_PlayUIClient(iClient, SND_KILLSTREAK_3, SND_KILLSTREAK_VOLUME);
			}
			case 4:
			{
				Sound_PlayUIClient(iClient, SND_KILLSTREAK_4, SND_KILLSTREAK_VOLUME);
			}
			case 0:
			{
				if (g_cv_gib_killstreaks_announce_sound.IntValue == 1)
				{
					Sound_PlayUIClient(iClient, SND_KILLSTREAK_MILESTONE, SND_KILLSTREAK_MILESTONE_VOLUME);
				}
				else
				{
					Sound_PlayUIAll(SND_KILLSTREAK_MILESTONE, SND_KILLSTREAK_MILESTONE_VOLUME);
				}

				if (iKillstreak != 5)
				{
					Sound_PlayUIClient(iClient, SND_KILLSTREAK_5, SND_KILLSTREAK_VOLUME);
				}
			}
		}
	}
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	g_cv_gib_killstreaks_announce_text =
	CreateConVar("gib_killstreaks_announce_text", "2", "Print Killstreak-Milestones to Chat. 0 = None; 1 = Local; 2 = Global");
	g_cv_gib_killstreaks_announce_sound =
	CreateConVar("gib_killstreaks_announce_sound", "2", "Play Sound on Killstreak-Milestone. 0 = None; 1 = Local; 2 = Global");

	HookEvent("player_death", GameEvent_PlayerDeath);
}

public void OnAllPluginsLoaded()
{
	// After Dynamic is initialised, hook the Server Data
	InitializeServer();

	// After Dynamic is initialised, hook the Player-Data of every connected Player
	LOOP_CLIENTS (iClient, CLIENTFILTER_INGAME)
	{
		InitializePlayer(iClient);
	}
}

public void OnMapStart()
{
	PrecacheSound(SND_KILLSTREAK_1);
	PrecacheSound(SND_KILLSTREAK_2);
	PrecacheSound(SND_KILLSTREAK_3);
	PrecacheSound(SND_KILLSTREAK_4);
	PrecacheSound(SND_KILLSTREAK_5);
	PrecacheSound(SND_KILLSTREAK_MILESTONE);
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

	Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iVictim).GetDynamic("gib_data");
	int iOldKillstreak = dGibPlayerData.GetInt("iKillstreak", 0);

	// Reset Killstreak on Death
	dGibPlayerData.SetInt("iKillstreak", 0);

	// Get Client's Name
	char szVictimName[33];
	GetClientName(iVictim, szVictimName, sizeof(szVictimName));

	// If Killstreak was higher than 5 and Announcements are on
	if (iOldKillstreak >= 5 && g_cv_gib_killstreaks_announce_text.BoolValue)
	{
		// Display Killstreak-End
		PrintToChatAll(" %s%s%s's %s%i %sKillstreak ended.",
		COLOR_NAME, szVictimName, COLOR_BASE, COLOR_LOWLIGHT, iOldKillstreak, COLOR_BASE);
	}
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
	static int iKillsPre[MAXPLAYERS + 1] = {0,...};

	int iClient = view_as<int>(Dynamic_GetParent(dGibPlayerData));
	int iKills  = dGibPlayerData.GetInt("iKills");

	if (iKills > iKillsPre[iClient])
	{
		// Increase Killstreak by one
		int iKillstreak  = dGibPlayerData.GetInt("iKillstreak");
		dGibPlayerData.SetInt("iKillstreak", ++iKillstreak);

		PrintKillstreak(iClient, iKillstreak);

		// Check if Killstreak is higher than any other previously achieved (in the current round)
		if (dGibPlayerData.GetInt("iHighestKillstreak", 0) < iKillstreak)
		{
			dGibPlayerData.SetInt("iHighestKillstreak", iKillstreak);
		}
	}

	iKillsPre[iClient] = iKills;
}

public void DynamicChange_GibData(Dynamic dGibData, DynamicOffset doOffset, const char[] szMember, Dynamic_MemberType dmtType)
{
	// Only Hook Changes to Round State
	if (StrEqual(szMember, "bRoundInProgress"))
	{
		// If Round started
		if (dGibData.GetBool(szMember))
		{
			LOOP_CLIENTS (iClient, CLIENTFILTER_INGAME)
			{
				Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iClient).GetDynamic("gib_data");
				dGibPlayerData.SetInt("iKillstreak", 0);
				dGibPlayerData.SetInt("iHighestKillstreak", 0);
			}
		}
	}
}
