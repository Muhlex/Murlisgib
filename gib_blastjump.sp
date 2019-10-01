#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#include <smlib>
#include <dynamic>

#define PATH_CONFIG /* SOURCEMOD PATH/ */ "configs/gib_weapons.cfg"

bool g_bPluginLoadedLate;
StringMap g_smWeaponConfig;

// Blast-jumps are executed on the next tick after being calculated.
// A Jump is queued for the next tick and the last calculated velocity used to propel them.
bool g_bPlayerHasBlastJumpQueued[MAXPLAYERS + 1];
float g_vPlayerBlastJumpVelocity[MAXPLAYERS + 1][3];

// Whether the player jumped jumped in the last milliseconds
bool g_bPlayerJustJumped[MAXPLAYERS + 1];

// Track the trail effect under the player.
int g_iPlayerBlastJumpingTrail[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public Plugin myinfo =
{
	name = "Murlisgib Blastjump",
	author = "murlis, Nyuu",
	description = "Allows players to blast-jump with configured weapons.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrorMaxLength)
{
	g_bPluginLoadedLate = bLate;
	return APLRes_Success;
}

void PluginLateLoad()
{
	// Process the clients already on the server
	for (int iClient = 1 ; iClient <= MaxClients ; iClient++)
	{
		// Check if the client is connected
		if (IsClientConnected(iClient))
		{
			// Call the client connected forward
			OnClientConnected(iClient);

			// Check if the client is in game
			if (IsClientInGame(iClient))
			{
				// Call the client put in server forward
				OnClientPutInServer(iClient);
			}
		}
	}
}

public void OnPluginStart()
{
	HookEvent("bullet_impact", GameEvent_BulletImpact);
	HookEvent("player_death", GameEvent_PlayerDeath);

	if (g_bPluginLoadedLate)
		PluginLateLoad();
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
		if (kvConfig.JumpToKey("blastjump"))
		{
			// Store stats for a single Weapon
			StringMap smWeapon = new StringMap();

			float fForce = kvConfig.GetFloat("force", 0.0);
			smWeapon.SetValue("force", fForce);

			char szBuffer[65];

			kvConfig.GetString("blast_particle", szBuffer, sizeof(szBuffer));
			if (!StrEqual(szBuffer, ""))
				smWeapon.SetString("blast_particle", szBuffer);

			kvConfig.GetString("trail_particle", szBuffer, sizeof(szBuffer));
			if (!StrEqual(szBuffer, ""))
				smWeapon.SetString("trail_particle", szBuffer);

			kvConfig.GetString("blast_sound", szBuffer, sizeof(szBuffer));
			if (!StrEqual(szBuffer, ""))
				smWeapon.SetString("blast_sound", szBuffer);

			float fBlastVolume = kvConfig.GetFloat("blast_sound_volume", 1.0);
			smWeapon.SetValue("blast_sound_volume", fBlastVolume);

			g_smWeaponConfig.SetValue(szWeaponName, smWeapon);

			kvConfig.GoBack();
		}
	} while (kvConfig.GotoNextKey());

	delete kvConfig;
}

public void OnClientConnected(int iClient)
{
	g_bPlayerHasBlastJumpQueued[iClient] = false;
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_PostThinkPost, OnPlayerPostThinkPost);
}

public void OnClientDisconnect(int iClient)
{
	g_bPlayerHasBlastJumpQueued[iClient] = false;

	RemovePlayerTrail(iClient);
}

public Action GameEvent_BulletImpact(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

	// Check for valid player, who does not have a Jump queued for the current tick already
	if (Client_IsIngame(iClient) && !g_bPlayerHasBlastJumpQueued[iClient])
	{
		// Get current Weapon
		char szWeaponName[33];
		GetClientWeapon(iClient, szWeaponName, sizeof(szWeaponName));

		// Check if the weapon is setup for blast-jumping
		StringMap smWeapon = new StringMap();

		if (g_smWeaponConfig.GetValue(szWeaponName, smWeapon))
		{
			// If a force is set, calculate player velocity change
			float fForce;
			smWeapon.GetValue("force", fForce);
			if (fForce > 0.0)
			{
				float vImpactPosition[3];
				float vPlayerPosition[3];
				float fDistance;
				float fMaxDistance = 160.0;

				// Get Bullet Impact Position
				vImpactPosition[0] = eEvent.GetFloat("x");
				vImpactPosition[1] = eEvent.GetFloat("y");
				vImpactPosition[2] = eEvent.GetFloat("z");

				// Get Player Position
				GetClientAbsOrigin(iClient, vPlayerPosition);
				vPlayerPosition[2] += 12; // Slightly elevate the position to check the distance from

				fDistance = GetVectorDistance(vImpactPosition, vPlayerPosition);

				if (fDistance <= fMaxDistance)
				{
					float fForceMultiplier; // Between 0.00 - 1.00; Creates smooth force falloff when getting away from the epicenter of the blast

					// Linear Multiplier Calculation
					fForceMultiplier = 1 - (fDistance * (1 / fMaxDistance));

					// Exponential Multiplier Calculation
					fForceMultiplier = (-1 * Exponential(-4 * fForceMultiplier)) + 1;

					float vPlayerVelocity[3];
					float vPlayerEyeAngles[3];
					float vPlayerForwardVector[3];

					GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vPlayerVelocity);

					GetClientEyeAngles(iClient, vPlayerEyeAngles);
					GetAngleVectors(vPlayerEyeAngles, vPlayerForwardVector, NULL_VECTOR, NULL_VECTOR);

					for (int i = 0; i <= 2; i++)
					{
						g_vPlayerBlastJumpVelocity[iClient][i] = vPlayerVelocity[i] - vPlayerForwardVector[i] * fForce * fForceMultiplier;
					}

					g_bPlayerHasBlastJumpQueued[iClient] = true;

					// Visual Effects
					char szBuffer[65];

					// Blast Particle Effect
					smWeapon.GetString("blast_particle", szBuffer, sizeof(szBuffer));
					if (!StrEqual(szBuffer, ""))
					{
						int iBlastParticle = CreateEntityByName("info_particle_system");
						DispatchKeyValue(iBlastParticle, "start_active", "0");
						DispatchKeyValue(iBlastParticle, "effect_name", szBuffer);
						DispatchSpawn(iBlastParticle);
						TeleportEntity(iBlastParticle, vImpactPosition, NULL_VECTOR, NULL_VECTOR);
						ActivateEntity(iBlastParticle);
						AcceptEntityInput(iBlastParticle, "start");

						szBuffer = "";
					}

					// Player Trail Particle Effect
					smWeapon.GetString("trail_particle", szBuffer, sizeof(szBuffer));
					if (!StrEqual(szBuffer, ""))
					{
						// Delete Trail if one already exists
						RemovePlayerTrail(iClient);

						int iTrailParticle = CreateEntityByName("info_particle_system");
						DispatchKeyValue(iTrailParticle, "start_active", "0");
						DispatchKeyValue(iTrailParticle, "effect_name", szBuffer);
						DispatchSpawn(iTrailParticle);
						TeleportEntity(iTrailParticle, vPlayerPosition, NULL_VECTOR, NULL_VECTOR);

						// Make Player Parent of the Particle
						SetVariantString("!activator");
						AcceptEntityInput(iTrailParticle, "SetParent", iClient, iTrailParticle, 0);

						ActivateEntity(iTrailParticle);
						AcceptEntityInput(iTrailParticle, "start");

						g_iPlayerBlastJumpingTrail[iClient] = EntIndexToEntRef(iTrailParticle);

						szBuffer = "";
					}

					// Auditory Effects
					smWeapon.GetString("blast_sound", szBuffer, sizeof(szBuffer));
					if (!StrEqual(szBuffer, ""))
					{
						float fBlastVolume;
						smWeapon.GetValue("blast_sound_volume", fBlastVolume);

						EmitAmbientSound(szBuffer, vImpactPosition, SOUND_FROM_WORLD, 85, SND_NOFLAGS, fBlastVolume, SNDPITCH_NORMAL);

						szBuffer = "";
					}
				}
			}
		}
	}
}

bool RemovePlayerTrail(int iClient)
{
	int iTrailParticle = EntRefToEntIndex(g_iPlayerBlastJumpingTrail[iClient]);

	if (iTrailParticle != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(iTrailParticle, "stop");
		AcceptEntityInput(iTrailParticle, "kill");
	}
}

public void OnPlayerPostThinkPost(int iClient)
{
	// Check if the player has a blast-jump queued
	if (g_bPlayerHasBlastJumpQueued[iClient])
	{
		// Check if the player is still alive
		if (IsPlayerAlive(iClient))
		{
			// Apply force to the player
			TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, g_vPlayerBlastJumpVelocity[iClient]);
			g_bPlayerJustJumped[iClient] = true;
			CreateTimer(0.1, Timer_PlayerJustJumpedReset, GetClientUserId(iClient));
		}

		// Reset blast-jump Queue
		g_bPlayerHasBlastJumpQueued[iClient] = false;
	}

	if (g_iPlayerBlastJumpingTrail[iClient] != INVALID_ENT_REFERENCE && !g_bPlayerJustJumped[iClient])
	{
		if (GetEntityFlags(iClient) & FL_ONGROUND)
		{
			RemovePlayerTrail(iClient);
		}
	}
}

public Action Timer_PlayerJustJumpedReset(Handle hTimer, int iUserid)
{
	int iClient = GetClientOfUserId(iUserid);

	g_bPlayerJustJumped[iClient] = false;
}

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

	RemovePlayerTrail(iClient);
}