#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#include <smlib>

#include <murlisgib>

#define SND_HEAL "items/healthshot_success_01.wav"
#define SND_HEAL_VOLUME 0.30

#define PCF_BASE "particles/murlisgib/base.pcf"
#define EFFECT_HEAL_VIEW "player_heal_viewmodel"
#define EFFECT_HEAL_WORLD "player_heal"
#define EFFECT_HEAL_WORLD_CROUCHED "player_heal_crouch"

ConVar g_cv_gib_railgun;

ConVar g_cv_gib_health_railgun_only;

public Plugin myinfo =
{
	name = "Murlisgib Regeneration",
	author = "murlis",
	description = "Health Regeneration on Kill.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
 *
 * Functions
 */

bool RestoreHealth(int iClient)
{
	int iHealth = GetClientHealth(iClient);
	int iHealthMax = Entity_GetMaxHealth(iClient);

	if (iHealth < iHealthMax)
	{
		SetEntityHealth(iClient, iHealthMax);
		return true;
	}
	else
	{
		return false;
	}
}

void EmitHealParticles(int iClient)
{
	float vClientPos[3];
	GetClientAbsOrigin(iClient, vClientPos);

	// Emit VIEW Particles
	TE_EffectDispatch(EFFECT_HEAL_VIEW, vClientPos, vClientPos);
	TE_SendToClient(iClient);

	// Emit WORLD Particles
	int iParticleSystem = CreateEntityByName("info_particle_system");

	TeleportEntity(iParticleSystem, vClientPos, NULL_VECTOR, NULL_VECTOR);

	DispatchKeyValue(iParticleSystem, "start_active", "0");

	if (GetEntityFlags(iClient) & FL_DUCKING)
	{
		DispatchKeyValue(iParticleSystem, "effect_name", EFFECT_HEAL_WORLD_CROUCHED);
	}
	else
	{
		DispatchKeyValue(iParticleSystem, "effect_name", EFFECT_HEAL_WORLD);
	}

	DispatchSpawn(iParticleSystem);

	SetVariantString("!activator");
	AcceptEntityInput(iParticleSystem, "SetParent", iClient, iParticleSystem, 0);

	ActivateEntity(iParticleSystem);
	AcceptEntityInput(iParticleSystem, "start");

	SetEntPropEnt(iParticleSystem, Prop_Send, "m_hOwnerEntity", iClient);

	RemoveEdictFlags(iParticleSystem, FL_EDICT_ALWAYS);

	SDKHook(iParticleSystem, SDKHook_SetTransmit, OnSetTransmit_HealParticles);
}

void RemoveEdictFlags(int iEdict, int iFlags)
{
	if (GetEdictFlags(iEdict) & iFlags)
	{
		SetEdictFlags(iEdict, (GetEdictFlags(iEdict) ^ iFlags));
	}
}

public Action OnSetTransmit_HealParticles(int iEntity, int iClient)
{
	RemoveEdictFlags(iEntity, FL_EDICT_ALWAYS);
	if (GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity") != iClient)
	{
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	g_cv_gib_health_railgun_only =
	CreateConVar("gib_health_railgun_only", "0", "Whether to restore Health on Railgun-Kill only.");

	HookEvent("player_death", GameEvent_PlayerDeath);
}

public void OnConfigsExecuted()
{
	g_cv_gib_railgun = FindConVar("gib_railgun");
}

public void OnMapStart()
{
	PrecacheSound(SND_HEAL);

	if (!IsParticleSystemPrecached("player_heal"))
	{
		PrintToServer("particle sys not precached; precaching now");
		AddFileToDownloadsTable(PCF_BASE);
		PrecacheGeneric(PCF_BASE, true);
	}
}

/*
 *
 * Game-Event Hooks
 */

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int  iAttacker = GetClientOfUserId(GetEventInt(eEvent, "attacker"));
	int  iVictim   = GetClientOfUserId(GetEventInt(eEvent, "userid"));

	// Exclude invalid Cases where Victim is no longer ingame
	if (!Client_IsIngame(iVictim))
	{
		return;
	}
	// Check for Suicide
	if (iVictim == iAttacker || iAttacker == 0)
	{
		return;
	}

	// Check if Attacker is valid and ingame
	if (Client_IsIngame(iAttacker))
	{
		// Get Name of used Weapon
		char szWeaponName[33];
		GetEventString(eEvent, "weapon", szWeaponName, sizeof(szWeaponName));
		// Add "_weapon"-Prefix
		Format(szWeaponName, sizeof(szWeaponName), "weapon_%s", szWeaponName);

		// Get Railgun-Weapon
		char szRailgunName[33];
		g_cv_gib_railgun.GetString(szRailgunName, sizeof(szRailgunName));

		// Check if only the Railgun should trigger the Health-Restore and check for the Railgun being used on Kill
		if (!g_cv_gib_health_railgun_only.BoolValue || StrEqual(szWeaponName, szRailgunName))
		{
			// Restore Health and check for success
			if (RestoreHealth(iAttacker))
			{
				// Provide Feedback to Players
				Sound_PlayUIClient(iAttacker, SND_HEAL, SND_HEAL_VOLUME);
				EmitHealParticles(iAttacker);
			}
		}
	}
}