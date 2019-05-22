#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <smlib>

#include <murlisgib>

#define SND_HEAL "items/healthshot_success_01.wav"
#define SND_HEAL_VOLUME 0.30

#define PARTICLES_BASE "particles/murlisgib/base.pcf"

ConVar g_cv_gib_railgun;

ConVar g_cv_gib_regen_time;
ConVar g_cv_gib_regen_time_static;
ConVar g_cv_gib_regen_railgun_only;

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

bool RegenerateHealth(int iClient)
{
	int iHealth = GetClientHealth(iClient);
	int iHealthMax = Entity_GetMaxHealth(iClient);

	if (iHealth >= iHealthMax)
	{
		return false;
	}

	int   iHealthMissing = iHealthMax - iHealth; //40
	float fIncrementInterval = 0.1;
	float fIncrementCount = g_cv_gib_regen_time.FloatValue / fIncrementInterval; //25
	float fIncrementAmount = iHealthMissing / fIncrementCount; //1.6

	DataPack dTimer_Heal;
	CreateDataTimer(fIncrementInterval, Timer_Heal, dTimer_Heal, TIMER_REPEAT);
	dTimer_Heal.WriteCell(GetClientUserId(iClient));
	dTimer_Heal.WriteCell(fIncrementAmount);

	return true;
}

public Action Timer_Heal(Handle hTimer, DataPack dData)
{
	dData.Reset();
	int iClient = GetClientOfUserId(dData.ReadCell());
	float fIncrementAmount = dData.ReadCell();

	if (Client_IsIngame(iClient))
	{
		Entity_AddHealth(iClient, RoundFloat(fIncrementAmount));

		if (GetClientHealth(iClient) < Entity_GetMaxHealth(iClient))
		{
			return Plugin_Continue;
		}
		else
		{
			return Plugin_Stop;
		}
	}
	else
	{
		return Plugin_Stop;
	}
}

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	g_cv_gib_regen_time  =
	CreateConVar("gib_regen_time", "1.0", "Time it takes to fully restore Player Health (in seconds).");
	g_cv_gib_regen_time_static =
	CreateConVar("gib_regen_time_static", "0", "When enabled, Health Regeneration will always take the same Time, regardless of remaining HP.");
	g_cv_gib_regen_railgun_only =
	CreateConVar("gib_regen_railgun_only", "0", "Whether to regenerate Health on Railgun-Kill only.");

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
		AddFileToDownloadsTable(PARTICLES_BASE);
		PrecacheGeneric(PARTICLES_BASE, true);
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

		// Check if only the Railgun should trigger the Regen and check for the Railgun being used on Kill
		if (!g_cv_gib_regen_railgun_only.BoolValue || StrEqual(szWeaponName, szRailgunName))
		{
			// Restore Health and check for success
			if (RegenerateHealth(iAttacker))
			{
				Sound_PlayUIClient(iAttacker, SND_HEAL, SND_HEAL_VOLUME);
			}
		}
	}
}