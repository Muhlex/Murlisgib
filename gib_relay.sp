#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <smlib>
#include <dynamic>

#include <murlisgib>

#define SND_RELAY_PASSED "ui/panorama/inventory_new_item_01.wav"
#define SND_RELAY_PASSED_VOLUME 0.1

#define SND_RELAY_LOST "ui/xp_rankdown_02.wav"
#define SND_RELAY_LOST_VOLUME 0.5


ConVar g_cv_gib_relay_weapon;
ConVar g_cv_gib_relay_replenish_ammo;

public Plugin myinfo =
{
	name = "Murlisgib Relay-Weapon",
	author = "murlis",
	description = "A primary Weapon, that is relayed to Attacker on Kill.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
 *
 * Functions
 */

void InitializeServer()
{
	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");

	// Create Member which tracks who has the Relay-Weapon
	dGibData.SetInt("iRelayWeaponClient", 0);

	// Hook changes to Round Status to reset the Relay-Weapon Holder
	dGibData.HookChanges(DynamicChange_GibData);
}

void ResetRound()
{
	// Reset Relay-Weapon Holder
	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");
	dGibData.SetInt("iRelayWeaponClient", 0);
}

void GiveRelayWeapon(int iClient)
{
	char szRelayWeapon[33];
	g_cv_gib_relay_weapon.GetString(szRelayWeapon, sizeof(szRelayWeapon));
	GivePlayerItem(iClient, szRelayWeapon);
}

void DisplayRelay(int iVictim = 0, int iAttacker = 0)
{
	char szVictimName[33];
	char szAttackerName[33];

	if (Client_IsIngame(iVictim))
	{
		// Get Victim Name
		GetClientName(iVictim, szVictimName, sizeof(szVictimName));
	}

	if (Client_IsIngame(iAttacker))
	{
		// Get Attacker Name
		GetClientName(iAttacker, szAttackerName, sizeof(szAttackerName));
	}

	if (iVictim > 0 && iAttacker == 0)
	{
		PrintToChatAll("%s LOST the Relay.", szVictimName);
	}
	else if (iVictim == 0 && iAttacker > 0)
	{
		PrintToChatAll("%s GOT the Relay FIRST.", szAttackerName);
	}
	else if (iVictim > 0 && iAttacker > 0)
	{
		PrintToChatAll("%s RELAYED the Weapon to %s.", szVictimName, szAttackerName);
	}
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	g_cv_gib_relay_weapon =
  CreateConVar("gib_relay_weapon", "weapon_mag7", "Primary weapon to relay between Players.");
	g_cv_gib_relay_replenish_ammo =
  CreateConVar("gib_relay_replenish_ammo", "1", "How many Rounds to replenish on Kill with Relay-Weapon.");

	HookEvent("player_death", GameEvent_PlayerDeath);

	InitializeServer();
}

public void OnMapStart()
{
	PrecacheSound(SND_RELAY_PASSED);
	PrecacheSound(SND_RELAY_LOST);
}

/*
 *
 * Game-Event Hooks
 */

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iAttacker = GetClientOfUserId(GetEventInt(eEvent, "attacker"));
	int iVictim   = GetClientOfUserId(GetEventInt(eEvent, "userid"));

	Dynamic dGibData = Dynamic.GetSettings().GetDynamic("gib_data");
	int iRelayWeaponClient = dGibData.GetInt("iRelayWeaponClient", 0);

	char szWeaponName[33];
	GetEventString(eEvent, "weapon", szWeaponName, sizeof(szWeaponName));
	// Add "_weapon"-Prefix
	Format(szWeaponName, sizeof(szWeaponName), "weapon_%s", szWeaponName);

	char szRelayWeaponName[33];
	g_cv_gib_relay_weapon.GetString(szRelayWeaponName, sizeof(szRelayWeaponName));

	// Exclude invalid Cases where Victim is no longer ingame
	if (!Client_IsIngame(iVictim))
	{
		return;
	}

	// Check for Suicide
	if (iVictim == iAttacker || iAttacker == 0)
	{
		// Check if Victim had the Relay-Weapon
		if (iVictim == iRelayWeaponClient)
		{
			dGibData.SetInt("iRelayWeaponClient", 0);
			DisplayRelay(iVictim);
		}

		return;
	}

	// Check if Attacker is valid and ingame
	if (Client_IsIngame(iAttacker))
	{
		// Replenish Ammo if Attacker used Relay-Weapon
		if (g_cv_gib_relay_replenish_ammo.IntValue >= 1 && StrEqual(szWeaponName, szRelayWeaponName))
		{
			int iWeapon = Client_GetWeapon(iAttacker, szWeaponName);

			int iClip = Weapon_GetPrimaryClip(iWeapon);
			Weapon_SetPrimaryClip(iWeapon, iClip + g_cv_gib_relay_replenish_ammo.IntValue);
		}


		// Check if Attacker already has a Primary Weapon
		bool iAttackerHasPrimary = false;

		int iPrimaryWeapon = GetPlayerWeaponSlot(iAttacker, 0); // 0 = Primary Slot
		if (iPrimaryWeapon != -1)
		{
			iAttackerHasPrimary = true;
		}

		// Check if Victim had the Relay-Weapon
		if (iVictim == iRelayWeaponClient)
		{
			if (iAttackerHasPrimary)
			{
				dGibData.SetInt("iRelayWeaponClient", 0);
				DisplayRelay(iVictim);
			}
			else
			{
				// Relay from Victim to Attacker
				dGibData.SetInt("iRelayWeaponClient", iAttacker);
				RequestFrame(GiveRelayWeapon, iAttacker);
				DisplayRelay(iVictim, iAttacker);
			}
		}
		else if (iRelayWeaponClient == 0) // Relay-Weapon not owned by anyone
		{
			if (!iAttackerHasPrimary)
			{
				// Relay (Give) to Attacker
				dGibData.SetInt("iRelayWeaponClient", iAttacker);
				RequestFrame(GiveRelayWeapon, iAttacker);
				DisplayRelay(_, iAttacker);
			}
		}
	}
}

/*
 *
 * Other Hooks
 */

public void DynamicChange_GibData(Dynamic dGibPlayerData, DynamicOffset doOffset, const char[] szMember, Dynamic_MemberType dmtType)
{
	// Only Hook Changes to Round State
	if (StrEqual(szMember, "bRoundInProgress"))
	{
		if (dGibPlayerData.GetBool("bRoundInProgress"))
		ResetRound();
	}
}