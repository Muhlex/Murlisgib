//TODO:
// Add Death impact effect
// Add sounds
// Optimize Angle Retrieval for Shotgun Shots
// Fix Multiple Tracers

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <smlib>
#include <dynamic>

#include <murlisgib>

#define PATH_CONFIG /* SOURCEMOD PATH/ */ "configs/gib_weapons.cfg"

StringMap g_smWeaponConfig;

public Plugin myinfo =
{
	name = "Murlisgib Weapon Effects",
	author = "murlis, Tak (Chaosxk)",
	description = "Tracers, Impacts and Sounds for Railgun Weapons.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
 *
 * Functions
 */

void GetWeaponAttachmentPosition(int client, const char[] attachment, float pos[3])
{
	if (!attachment[0])
		return;

	int entity = CreateEntityByName("info_target");
	DispatchSpawn(entity);

	int weapon;

	if ((weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")) == -1)
		return;

	if ((weapon = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel")) == -1)
		return;

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", weapon, entity, 0);

	SetVariantString(attachment);
	AcceptEntityInput(entity, "SetParentAttachment", weapon, entity, 0);

	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);
	AcceptEntityInput(entity, "kill");
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	//AddTempEntHook("Shotgun Shot", TEHook_FireBullets);
	HookEvent("bullet_impact", GameEvent_BulletImpact);
	HookEvent("player_death", GameEvent_PlayerDeath);
}

public void OnConfigsExecuted()
{
	char szConfigPath[PLATFORM_MAX_PATH];
	KeyValues kvConfig = new KeyValues("weapons");
	g_smWeaponConfig = new StringMap();

	// Build the path of the Configuration File
	BuildPath(Path_SM, szConfigPath, sizeof(szConfigPath), PATH_CONFIG);

	// Try to import Configuration File
	if (!kvConfig.ImportFromFile(szConfigPath))
		SetFailState("Unable to load config from path: %s", szConfigPath);

	// GOTO First Section (inside root) (first weapon)
	if (!kvConfig.GotoFirstSubKey())
		SetFailState("Plugin Config-File empty or corrupt!");

	// Create Variable to store a single weapon's name
	char szWeaponName[33];

	do // for every Section (inside root) (every weapon)
	{
		// Get the weapon's name
		kvConfig.GetSectionName(szWeaponName, sizeof(szWeaponName));

		// GOTO blastjump Configuration
		if (kvConfig.JumpToKey("weapon_effects"))
		{
			// Store stats for a single Weapon
			StringMap smWeapon = new StringMap();

			char szBuffer[65];

			kvConfig.GetString("tracer_particle", szBuffer, sizeof(szBuffer));
			if (!StrEqual(szBuffer, ""))
				smWeapon.SetString("tracer_particle", szBuffer);

			kvConfig.GetString("kill_impact_particle", szBuffer, sizeof(szBuffer));
			if (!StrEqual(szBuffer, ""))
				smWeapon.SetString("kill_impact_particle", szBuffer);

			kvConfig.GetString("shot_sound", szBuffer, sizeof(szBuffer));
			if (!StrEqual(szBuffer, ""))
				smWeapon.SetString("shot_sound", szBuffer);

			float fShotVolume = kvConfig.GetFloat("shot_sound_volume", 1.0);
			smWeapon.SetValue("shot_sound_volume", fShotVolume);

			g_smWeaponConfig.SetValue(szWeaponName, smWeapon);

			kvConfig.GoBack();
		}
	} while (kvConfig.GotoNextKey());

	delete kvConfig;
}

/*
 *
 * Other Hooks
 */

public Action TEHook_FireBullets(const char[] szTE_Name, const int[] iPlayers, int iNumClients, float fDelay)
{
	int iClient = TE_ReadNum("m_iPlayer") + 1;


}

/*
 *
 * Game-Event Hooks
 */

public Action GameEvent_BulletImpact(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

	// Check for valid player
	if (Client_IsIngame(iClient))
	{
		// Get current Weapon
		char szWeaponName[33];
		GetClientWeapon(iClient, szWeaponName, sizeof(szWeaponName));

		// Check if the weapon is setup for effects
		StringMap smWeapon = new StringMap();

		if (g_smWeaponConfig.GetValue(szWeaponName, smWeapon))
		{
			char szBuffer[65];

			// Tracer Particle
			if (smWeapon.GetString("tracer_particle", szBuffer, sizeof(szBuffer)))
			{
				// Get Bullet Impact Position
				float vImpactPosition[3];
				vImpactPosition[0] = eEvent.GetFloat("x");
				vImpactPosition[1] = eEvent.GetFloat("y");
				vImpactPosition[2] = eEvent.GetFloat("z");

				// Get View Position
				float vPlayerViewPosition[3];
				GetClientEyePosition(iClient, vPlayerViewPosition);

				float vPlayerEyeAngles[3];
				float vPlayerForwardVector[3], vPlayerRightVector[3], vPlayerUpVector[3];
				GetClientEyeAngles(iClient, vPlayerEyeAngles);
				GetAngleVectors(vPlayerEyeAngles, vPlayerForwardVector, vPlayerRightVector, vPlayerUpVector);

				// Offset the Positions to approximate where the viewmodel sits
				float vViewmodelPosition[3];

				vViewmodelPosition = vPlayerViewPosition;

				for (int i = 0; i <= 2; i++)
				{
					// Move forward
					vViewmodelPosition[i] += vPlayerForwardVector[i] * 10;
					// Move down
					vViewmodelPosition[i] -= vPlayerUpVector[i] * 2;
					// Move right
					vViewmodelPosition[i] += vPlayerRightVector[i] * 4;
				}

				// Get Worldmodel Muzzle Position
				float vMuzzlePosition[3];
				GetWeaponAttachmentPosition(iClient, "muzzle_flash", vMuzzlePosition);

				// Send Particles to shooting Client
				TE_EffectDispatch(szBuffer, vViewmodelPosition, vImpactPosition, vPlayerEyeAngles);
				TE_SendToClient(iClient);

				// Send Particles to all other Clients
				TE_EffectDispatch(szBuffer, vMuzzlePosition, vImpactPosition, vPlayerEyeAngles);

				int[] iClients = new int[MaxClients];
				int iClientCount;
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || i == iClient || IsFakeClient(i))
						continue;
					iClients[iClientCount++] = i;
				}
				TE_Send(iClients, iClientCount);
			}
		}
	}
}

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
}