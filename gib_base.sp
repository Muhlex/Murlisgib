#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>

#include <smlib>
#include <dynamic>

#include <murlisgib>

ConVar g_cv_mp_t_default_secondary;
ConVar g_cv_mp_ct_default_secondary;
ConVar g_cv_mp_respawn_on_death_t;
ConVar g_cv_mp_respawn_on_death_ct;

ConVar g_cv_gib_railgun;
ConVar g_cv_gib_score_suicide_penalty;

public Plugin myinfo =
{
	name = "Murlisgib",
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
	dGibData.SetBool("bRoundInProgress", false);
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

void ResetRound()
{
	// Reset Winner
	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");
	dGibData.SetInt("iWinner", 0);
}

void ResetPlayer(int iClient)
{
	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");

	// Find new Winner (if Client was the winning Player)
	int iWinner = FindWinner();
	dGibData.SetInt("iWinner", iWinner);

	// Reset Kill-Count
	Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iClient).GetDynamic("gib_data");
	dGibPlayerData.SetInt("iKills", 0);
}

void UpdateScore(int iClient, int iKills)
{
	Client_SetScore(iClient, iKills); // sets Kills on Scoreboard
	CS_SetClientContributionScore(iClient, iKills); // sets actual Score on Scoreboard
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	g_cv_gib_railgun = CreateConVar("gib_railgun", "weapon_usp_silencer", "Secondary Weapon to be used as the Railgun.");
	g_cv_gib_score_suicide_penalty = CreateConVar("gib_score_suicide_penalty", "0", "Value to decrease/increase Player Kill-Count on suicide.");

	HookEvent("round_start",  GameEvent_RoundStart, EventHookMode_PostNoCopy);
	//HookEvent("round_end",    GameEvent_RoundEnd); // Using CS_OnTerminateRound instead
	HookEvent("player_death", GameEvent_PlayerDeath);
	HookEvent("player_spawn", GameEvent_PlayerSpawn);
	AddTempEntHook("Shotgun Shot", TEHook_FireBullets);

	InitializeServer();

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		InitializePlayer(iClient);
	}
}

public void OnConfigsExecuted()
{
	g_cv_mp_respawn_on_death_t               = FindConVar("mp_respawn_on_death_t");
	g_cv_mp_respawn_on_death_ct              = FindConVar("mp_respawn_on_death_ct");

	// The default Secondary defines the Weapon to be used as Railgun
	g_cv_mp_t_default_secondary  = FindConVar("mp_t_default_secondary");
	g_cv_mp_ct_default_secondary = FindConVar("mp_ct_default_secondary");

	// Hook whenever one of these change, to also force the Other to the same Value
	// Also update them when the Railgun is changed via the Plugin's ConVar
	g_cv_mp_t_default_secondary.AddChangeHook(ConVarChange_gib_railgun);
	g_cv_mp_ct_default_secondary.AddChangeHook(ConVarChange_gib_railgun);
	g_cv_gib_railgun.AddChangeHook(ConVarChange_gib_railgun);

	// Always set default Secondaries to the Railgun first
	char szRailgun[33];
	g_cv_gib_railgun.GetString(szRailgun, sizeof(szRailgun));

	g_cv_mp_t_default_secondary.SetString(szRailgun);
	g_cv_mp_ct_default_secondary.SetString(szRailgun);
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

public void ConVarChange_gib_railgun(ConVar cvConvar, char[] szOldValue, char[] szNewValue)
{
	// Update default Secondaries and Railgun if any of them are changed
	char szRailgun[33];
	cvConvar.GetString(szRailgun, sizeof(szRailgun));

	if (cvConvar != g_cv_gib_railgun)
		g_cv_gib_railgun.SetString(szRailgun);

	if (cvConvar != g_cv_mp_t_default_secondary)
		g_cv_mp_t_default_secondary.SetString(szRailgun);

	if (cvConvar != g_cv_mp_ct_default_secondary)
		g_cv_mp_ct_default_secondary.SetString(szRailgun);

	// Give Players new Railgun-Weapon whenever it changes
	if (cvConvar == g_cv_gib_railgun)
	{
		LOOP_CLIENTS (iClient, CLIENTFILTER_ALIVE)
		{
			int iWeapon = GetPlayerWeaponSlot(iClient, 1);
			char szWeaponName[33];

			// Get Weapon's Name if the Weapon exists
			if (Entity_GetWeaponName(iWeapon, szWeaponName, sizeof(szWeaponName)))
			{
				if (StrEqual(szOldValue, szWeaponName))
				{
					RemovePlayerItem(iClient, iWeapon);
					Entity_CreateForClientByName(iClient, szNewValue);
				}
			}
		}
	}

	return;
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

	// Enable Respawning
	g_cv_mp_respawn_on_death_t.BoolValue = true;
	g_cv_mp_respawn_on_death_ct.BoolValue = true;
}

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iAttacker = GetClientOfUserId(GetEventInt(eEvent, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(eEvent, "userid"));

	// Exclude invalid Cases where Victim is no longer ingame
	if (!Client_IsIngame(iVictim)) return;

	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");
	Dynamic dGibVictimData = Dynamic.GetPlayerSettings(iVictim).GetDynamic("gib_data");
	Dynamic dGibAttackerData = Dynamic.GetPlayerSettings(iAttacker).GetDynamic("gib_data");

	// Check for Suicide
	if (iVictim == iAttacker || iAttacker == 0)
	{
		int iVictimKills = dGibVictimData.GetInt("iKills");

		// Check if Suicide Penalty is enabled
		int iSuicidePenalty = g_cv_gib_score_suicide_penalty.IntValue;
		if (dGibData.GetBool("bRoundInProgress") && iSuicidePenalty != 0)
		{
			// Apply Suicide Penalty
			iVictimKills += iSuicidePenalty;
			dGibVictimData.SetInt("iKills", iVictimKills);

			// Find new Winner
			int iWinner = FindWinner();
			dGibData.SetInt("iWinner", iWinner);
		}

		// Send current Kills and Points to the Scoreboard
		// This needs to always be done on death, as well as on Respawn
		UpdateScore(iVictim, iVictimKills);
	}
	else if (Client_IsIngame(iAttacker))
	{
		// Update Attacker's Kill-Count
		int iAttackerKills = dGibAttackerData.GetInt("iKills");

		if (dGibData.GetBool("bRoundInProgress"))
		{
			dGibAttackerData.SetInt("iKills", ++iAttackerKills);
			PrintToServer("Killcount increased");

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
			if (iWinner == 0)
			{
				// Find new Winner
				iWinner = FindWinner();
				dGibData.SetInt("iWinner", iWinner);
			}
			else if (iAttackerKills > iWinnerKills)
			{
				// Set Attacker as Winner
				dGibData.SetInt("iWinner", iAttacker);
			}
		}

		// RequestFrame to update scoreboard kill count on next tick
		PrintToServer("Sent to scoreboard");
		RequestFrame(RequestFrame_PlayerGetKill, GetClientUserId(iAttacker));
	}
}

void RequestFrame_PlayerGetKill(int iUserID)
{
	int iClient = GetClientOfUserId(iUserID);
	if (!iClient || !IsClientInGame(iClient)) return;

	// Update Scoreboard
	Dynamic dGibPlayerData = Dynamic.GetPlayerSettings(iClient).GetDynamic("gib_data");
	UpdateScore(iClient, dGibPlayerData.GetInt("iKills"));
}

public Action GameEvent_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(eEvent, "userid"));

	RequestFrame(RequestFrame_PlayerSpawn, GetClientUserId(iClient)); // NOTICE: This might leave open a single tick on which Kills appear decremented by one

	// Check if a replacement Weapon was given at Spawn. (E.g. USP-S instead of P2000)
	// If so, equip the Player with the correct Weapon
	char szWeaponName[33], szRailgunName[33];
	int iWeapon = GetPlayerWeaponSlot(iClient, 1); // Secondary Slot

	if (Weapon_IsValid(iWeapon))
	{
		Entity_GetWeaponName(iWeapon, szWeaponName, sizeof(szWeaponName));
		g_cv_gib_railgun.GetString(szRailgunName, sizeof(szRailgunName));

		if (!StrEqual(szWeaponName, szRailgunName))
		{
			RemovePlayerItem(iClient, iWeapon);
			Entity_CreateForClientByName(iClient, szRailgunName);
		}
	}
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

/*
 *
 * Other Hooks
 */

public Action TEHook_FireBullets(const char[] szTE_Name, const int[] iPlayers, int iNumClients, float fDelay)
{
	int iClient = TE_ReadNum("m_iPlayer") + 1;

	int iWeapon = Client_GetActiveWeapon(iClient);
	// Get Weapon Name
	char szWeaponName[33];
	GetClientWeapon(iClient, szWeaponName, sizeof(szWeaponName));

	// Get Railgun-Weapon Name
	char szRailgun[33];
	g_cv_gib_railgun.GetString(szRailgun, sizeof(szRailgun));

	// Check if Railgun was shot
	if (StrEqual(szWeaponName, szRailgun))
	{
		if (Weapon_IsValid(iWeapon))
		{
			// Restore Bullet
			int iClip = Weapon_GetPrimaryClip(iWeapon);
			Weapon_SetPrimaryClip(iWeapon, ++iClip);
		}
	}

	return Plugin_Continue;
}

public Action CS_OnTerminateRound(float &fDelay, CSRoundEndReason &csrReason)
{
	// Check for an actual Round-End; Exclude the Pre-Game ending
	if (csrReason != CSRoundEnd_GameStart)
	{
		// Save if Round is no longer in Progress to Server Data Object
		Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");

		dGibData.SetBool("bRoundInProgress", false);

		// Disable Respawning
		g_cv_mp_respawn_on_death_t.BoolValue = false;
		g_cv_mp_respawn_on_death_ct.BoolValue = false;
	}

	return Plugin_Continue;
}
