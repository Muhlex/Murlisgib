#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <smlib>
#include <dynamic>

#include <murlisgib>

#define HITSOUND_1 "ui/item_drop.wav"
#define HITSOUND_2 "ui/item_drop1_common.wav"
#define HITSOUND_VOLUME 0.88

#define HEADSHOT_1 "commander/train_bodydamageheadshot_01.wav"
#define HEADSHOT_2 "commander/train_bodydamageheadshot_01b.wav"
#define HEADSHOT_3 "commander/train_bodydamageheadshot_02.wav"
#define HEADSHOT_VOLUME 1.0

ConVar g_cv_gib_killsound_generic;
ConVar g_cv_gib_killsound_headshot;
ConVar g_cv_gib_killsound_headshot_railgun_only;

public Plugin myinfo =
{
	name = "Murlisgib Killsound",
	author = "murlis",
	description = "Audible Hit-Feedback on Kill.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

/*
 *
 * Public Forwards
 */

public void OnPluginStart()
{
	g_cv_gib_killsound_generic  = CreateConVar("gib_killsound_generic", "1", "Enable Hitsounds on Kill.");
	g_cv_gib_killsound_headshot = CreateConVar("gib_killsound_headshot", "1", "Enable Headshot-Announcements on Kill.");
	g_cv_gib_killsound_headshot_railgun_only = CreateConVar("gib_killsound_headshot_railgun_only", "1", "Whether to play Headshot-Announcements on Railgun-Kill only.");

	HookEvent("player_death", GameEvent_PlayerDeath);
}

public void OnMapStart()
{
	PrecacheSound(HITSOUND_1);
	PrecacheSound(HITSOUND_2);

	PrecacheSound(HEADSHOT_1);
	PrecacheSound(HEADSHOT_2);
	PrecacheSound(HEADSHOT_3);
}

/*
 *
 * Game-Event Hooks
 */

public Action GameEvent_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int  iAttacker = GetClientOfUserId(GetEventInt(eEvent, "attacker"));
	int  iVictim   = GetClientOfUserId(GetEventInt(eEvent, "userid"));
	bool bHeadshot = GetEventBool(eEvent, "headshot");

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

	// Provide Variable to store a randomly selected Sound
	char szSound[65];

	// Check if generic Killsounds are enabled
	if (g_cv_gib_killsound_generic.BoolValue)
	{
		// Play Generic Killsound
		switch (GetRandomInt(1, 2))
		{
			case 1: szSound = HITSOUND_1;
			case 2: szSound = HITSOUND_2;
		}

		Sound_PlayUIClient(iAttacker, szSound, HITSOUND_VOLUME);
	}

	// Check if Headshot-Announcements are enabled and if Kill was a Headshot
	if (g_cv_gib_killsound_headshot.BoolValue && bHeadshot)
	{
		char szWeaponName[32];
		GetEventString(eEvent, "weapon", szWeaponName, 32);
		// Add "_weapon"-Prefix
		Format(szWeaponName, 32, "weapon_%s", szWeaponName);

		Dynamic dGibSettings = Dynamic.GetSettings().GetDynamic("gib_settings");

		char szRailgun[33];
		dGibSettings.GetString("szRailgun", szRailgun, sizeof(szRailgun));

		// Check if only the Railgun should trigger the Sound and check for the Railgun being used on Kill
		if (!g_cv_gib_killsound_headshot_railgun_only.BoolValue || StrEqual(szWeaponName, szRailgun))
		{
			// Play Headshot Announcer
			switch (GetRandomInt(1, 3))
			{
				case 1: szSound = HEADSHOT_1;
				case 2: szSound = HEADSHOT_2;
				case 3: szSound = HEADSHOT_2;
			}

			Sound_PlayUIClient(iAttacker, szSound, HEADSHOT_VOLUME);
		}
	}
}