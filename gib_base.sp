#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>

#include <smlib>
#include <dynamic>

#define RAILGUN_CYCLETIME 1.0

ConVar g_cv_mp_t_default_secondary;
ConVar g_cv_mp_ct_default_secondary;
ConVar g_cv_mp_teamname_1;
ConVar g_cv_mp_teamname_2;
ConVar g_cv_mp_default_team_winner_no_objective;

ConVar g_cv_gib_score_suicide_penalty;

public Plugin myinfo =
{
	name = "Murlisgib Base Plugin",
	author = "murlis",
	description = "Provides basic functionality for Murlisgib.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

// Fix for Dynamic not resetting Client Objects on Disconnect
public void OnClientDisconnect_Post(int iClient)
{
	Dynamic_ResetObject(iClient);
}

/*
 *
 * Functions
 */

void InitializeServer()
{
	// Get global Server Settings Object
	Dynamic dSettings = Dynamic.GetSettings();

	// Create Murlisgib-Settings
	Dynamic dGibSettings = Dynamic();
	Dynamic dGibData     = Dynamic();

	// Initialize Server Object Members
	dGibData.SetBool("bRoundInProgress", true);
	dGibData.SetInt("iWinner", 0);

	// Store Murlisgib Settings in Settings Object
	dSettings.SetDynamic("gib_settings", dGibSettings);
	dSettings.SetDynamic("gib_data",     dGibData);
}

void InitializePlayer(int iClient)
{
	// Get each Client's Settings Object
	Dynamic dPlayerSettings = Dynamic.GetPlayerSettings(iClient);

	// Create Murlisgib-PlayerSettings
	Dynamic dGibPlayerSettings = Dynamic();
	Dynamic dGibPlayerData     = Dynamic();

	// Initialize Client Object Members
	dGibPlayerData.SetInt("iKills", 0);

	// Store Murlisgib Settings in PlayerSettings Object
	dPlayerSettings.SetDynamic("gib_settings", dGibPlayerSettings);
	dPlayerSettings.SetDynamic("gib_data",     dGibPlayerData);
}

int FindWinner()
{
	int iWinner = 0;

	LOOP_CLIENTS (iCurrClient, CLIENTFILTER_INGAME)
	{
		Dynamic dGibWinnerData = Dynamic.GetPlayerSettings(iWinner).GetDynamic("gib_data");
		Dynamic dGibCurrPlayerData = Dynamic.GetPlayerSettings(iCurrClient).GetDynamic("gib_data");

		if (dGibCurrPlayerData.GetInt("iKills") > dGibWinnerData.GetInt("iKills", 0))
		{
			iWinner = iCurrClient;
		}
	}

	return iWinner;
}

void SetWinnerScoreboard(int iClient)
{
	// Reset Winner
	if (iClient == 0)
	{
		g_cv_mp_teamname_1.SetString(" ");
		g_cv_mp_teamname_2.SetString(" ");
		g_cv_mp_default_team_winner_no_objective.SetInt(CS_TEAM_NONE);
	}
	else
	{
		char szClientName[33];
		GetClientName(iClient, szClientName, sizeof(szClientName));

		g_cv_mp_teamname_1.SetString(szClientName);
		g_cv_mp_teamname_2.SetString(szClientName);
		g_cv_mp_default_team_winner_no_objective.SetInt(GetClientTeam(iClient));
	}
}

void ResetRound()
{
	// Reset Winner
	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");
	dGibData.SetInt("iWinner", 0);
	SetWinnerScoreboard(0);
}

void ResetPlayer(int iClient)
{
	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");

	// Find new Winner (if Client was the winning Player)
	int iWinner = FindWinner();
	dGibData.SetInt("iWinner", iWinner);
	SetWinnerScoreboard(iWinner);

	// Reset Kill-Count
	Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iClient).GetDynamic("gib_data");
	dGibPlayerData.SetInt("iKills", 0);
}

void UpdateScore(int iClient, int iKills)
{
	Client_SetScore(iClient, iKills);
	CS_SetClientContributionScore(iClient, iKills);
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	g_cv_gib_score_suicide_penalty = CreateConVar("gib_score_suicide_penalty", "0", "Value to decrease/increase Player Kill-Count on suicide.");

	HookEvent("round_start",  GameEvent_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end",    GameEvent_RoundEnd);
	HookEvent("weapon_fire",  GameEvent_WeaponFire);
	HookEvent("player_death", GameEvent_PlayerDeath);
	HookEvent("player_spawn", GameEvent_PlayerSpawn);

	InitializeServer();

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		InitializePlayer(iClient);
	}
}

public void OnConfigsExecuted()
{
	// Hook Teamnames and Winner-Team
	g_cv_mp_teamname_1                       = FindConVar("mp_teamname_1");
	g_cv_mp_teamname_2                       = FindConVar("mp_teamname_2");
	g_cv_mp_default_team_winner_no_objective = FindConVar("mp_default_team_winner_no_objective");

	// Set these to the default Value
	SetWinnerScoreboard(0);

	// The default Secondary defines the Weapon to be used as Railgun
	g_cv_mp_t_default_secondary  = FindConVar("mp_t_default_secondary");
	g_cv_mp_ct_default_secondary = FindConVar("mp_ct_default_secondary");

	// Hook whenever one of these change, to also force the Other to the same Value
	g_cv_mp_t_default_secondary.AddChangeHook(ConVarChange_mp_default_secondary);
	g_cv_mp_ct_default_secondary.AddChangeHook(ConVarChange_mp_default_secondary);

	// Always grab and save T default Secondary as Railgun first
	char szDefault[33];
	g_cv_mp_t_default_secondary.GetString(szDefault, sizeof(szDefault));

	Dynamic dGibSettings = Dynamic.GetSettings().GetDynamic("gib_settings");
	dGibSettings.SetString("szRailgun", szDefault, 33);
}

public void OnClientConnected(int iClient)
{
	// Re-Initialize Client Settings
	InitializePlayer(iClient);
}

/*
 *
 * ConVar Hooks
 */

public void ConVarChange_mp_default_secondary(ConVar cvConvar, char[] szOldValue, char[] szNewValue)
{
	char szTDefault[33], szCTDefault[33];

	g_cv_mp_t_default_secondary.GetString(szTDefault, sizeof(szTDefault));
	g_cv_mp_ct_default_secondary.GetString(szCTDefault, sizeof(szCTDefault));

	Dynamic dGibSettings = Dynamic.GetSettings().GetDynamic("gib_settings");

	// On Change of a default Secondary, also change the default Secondary of the other Team
	if (!StrEqual(szTDefault, szCTDefault))
	{
		if (cvConvar == g_cv_mp_t_default_secondary)
		{
			g_cv_mp_ct_default_secondary.SetString(szTDefault);
			dGibSettings.SetString("szRailgun", szTDefault, 33);
		}
		else
		{
			g_cv_mp_t_default_secondary.SetString(szCTDefault);
			dGibSettings.SetString("szRailgun", szCTDefault, 33);
		}
	}
}

/*
 *
 * Game-Event Hooks
 */

public Action GameEvent_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	// Reset round-based Variables and Objects
	ResetRound();

	// Reset round-based Client Variables and Objects
	LOOP_CLIENTS (iClient, CLIENTFILTER_ALL)
	{
		ResetPlayer(iClient);
	}

	// Save if Round is in Progress to Server Data Object
	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");

	dGibData.SetBool("bRoundInProgress", true);
}

public Action GameEvent_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	// Get Reason for the Round ending
	int iReason = GetEventInt(eEvent, "reason");
	// Define GameStart Reason
	int iReason_GameStart = view_as<int>(CSRoundEnd_GameStart) + 1;

	// Check for an actual Round-End; Exclude the Pre-Game ending
	if (iReason != iReason_GameStart)
	{
		// Save if Round is no longer in Progress to Server Data Object
		Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");

		dGibData.SetBool("bRoundInProgress", false);
	}
}

public Action GameEvent_WeaponFire(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(eEvent, "userid"));
	int iWeapon = Client_GetActiveWeapon(iClient);

	char szWeaponName[33];
	GetEventString(eEvent, "weapon", szWeaponName, sizeof(szWeaponName));

	// Get Railgun Weapon-Type
	char szRailgun[33];
	Dynamic dGibSettings = Dynamic.GetSettings().GetDynamic("gib_settings");
	dGibSettings.GetString("szRailgun", szRailgun, sizeof(szRailgun));

	// Check if the Railgun was used; If so, refill the Magazine
	if (StrEqual(szWeaponName, szRailgun))
	{
		CreateTimer(RAILGUN_CYCLETIME - 0.25, Timer_RefillRailgun, iWeapon);
	}
}

public Action Timer_RefillRailgun(Handle hTimer, int iWeapon)
{
	if (Weapon_IsValid(iWeapon))
	{
		Weapon_SetPrimaryClip(iWeapon, 1);
	}
}

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iAttacker = GetClientOfUserId(GetEventInt(eEvent, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(eEvent, "userid"));

	// Exclude invalid Cases where Victim is no longer ingame
	if (!Client_IsIngame(iVictim))
	{
		return;
	}

	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");
	Dynamic dGibVictimData = Dynamic.GetPlayerSettings(iVictim).GetDynamic("gib_data");
	Dynamic dGibAttackerData = Dynamic.GetPlayerSettings(iAttacker).GetDynamic("gib_data");

	// Check for Suicide
	if (iVictim == iAttacker || iAttacker == 0)
	{
		int iVictimKills = dGibVictimData.GetInt("iKills");

		// Check if Suicide Penalty is enabled
		int iSuicidePenalty = g_cv_gib_score_suicide_penalty.IntValue;
		if (iSuicidePenalty != 0)
		{
			// Apply Suicide Penalty
			iVictimKills += iSuicidePenalty;
			dGibVictimData.SetInt("iKills", iVictimKills);

			// Find new Winner
			int iWinner = FindWinner();
			dGibData.SetInt("iWinner", iWinner);
			SetWinnerScoreboard(iWinner);
		}

		// Send current Kills and Points to the Scoreboard
		// This needs to be done instantly after death, as well as on Respawn
		UpdateScore(iVictim, iVictimKills);
	}
	else if (Client_IsIngame(iAttacker))
	{
		// Update Attacker's Kill-Count
		int iAttackerKills = dGibAttackerData.GetInt("iKills");
		dGibAttackerData.SetInt("iKills", ++iAttackerKills);

		// Get currently winning Player
		int iWinner = dGibData.GetInt("iWinner", 0);
		int iWinnerKills;

		// Check if a Winner exists
		if (Client_IsIngame(iWinner))
		{
			// Get Winner's Kills
			Dynamic dGibWinnerData = Dynamic.GetPlayerSettings(iWinner).GetDynamic("gib_data");
			iWinnerKills = dGibWinnerData.GetInt("iKills");
			// Get Attacker's Kills
			iAttackerKills = dGibAttackerData.GetInt("iKills");
		}

		// Check if there was no Winner or if the current Kill made the Attacker the new winning Player
		if (dGibData.GetBool("bRoundInProgress"))
		{
			if (iWinner == 0)
			{
				// Find new Winner
				iWinner = FindWinner();
				dGibData.SetInt("iWinner", FindWinner());
				SetWinnerScoreboard(iWinner);
			}
			else if (iAttackerKills > iWinnerKills)
			{
				// Set Attacker as Winner
				dGibData.SetInt("iWinner", iAttacker);
				SetWinnerScoreboard(iAttacker);
			}
		}
	}
}

public Action GameEvent_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(eEvent, "userid"));

	RequestFrame(RequestFrame_PlayerSpawn, GetClientUserId(iClient)); // NOTICE: This might leave open a single Frame on which Kills are decremented by one
}

void RequestFrame_PlayerSpawn(int iUserID)
{
	int iClient = GetClientOfUserId(iUserID);

	if (Client_IsIngame(iClient))
	{
		// Update Scoreboard to reflect current Kills (prevents negative Kills)
		Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iClient).GetDynamic("gib_data");
		UpdateScore(iClient, dGibPlayerData.GetInt("iKills"));
	}
}