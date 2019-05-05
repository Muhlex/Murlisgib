/*
default				\x01
teamcolor			\x03
red						\x07
lightred			\x0F
darkred				\x02
bluegrey			\x0A
blue					\x0B
darkblue			\x0C
purple				\x03
orchid				\x0E
yellow				\x09
gold					\x10
lightgreen		\x05
green					\x04
lime					\x06
grey					\x08
grey2					\x0D
https://raw.githubusercontent.com/PremyslTalich/ColorVariables/master/csgo%20colors.png
*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

public Plugin myinfo =
{
	name = "Murlisgib",
	author = "murlis",
	description = "Handles Murlisgib gameplay logic.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};


// Round / Player States
bool	gl_matchInProgress													= true; // Match is considered in-progress from map load or round start until round end

int		gl_playerWithShotgun												= 0; // By default, nobody has the Shotgun

bool	gl_playerHasM4[MAXPLAYERS + 1]							= false; // Keeps track of players currently equipped with the admin-only M4


// Stat-Tracking Variables
int		gl_winningPlayer														= 0;

int 	gl_playerKills[MAXPLAYERS + 1];
int		gl_playerKillstreak[MAXPLAYERS + 1];
int 	gl_playerHighestKillstreak[MAXPLAYERS + 1];
int 	gl_playerUspHeadshots[MAXPLAYERS + 1];
float gl_playerShotgunTime[MAXPLAYERS + 1];
float gl_playerShotgunTimeSplit[MAXPLAYERS + 1];

char	gl_statStrings[4][940];
float gl_statDelay 																= 0.0;

// Expose Variables to other plugins
public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrorMaxLength)
{
	CreateNative("Murlisgib_GetWinner", Native_GetWinner);
	CreateNative("Murlisgib_GetStatDelay", Native_GetStatDelay);
	return APLRes_Success;
}

public int Native_GetWinner(Handle hPlugin, int iNumParams)
{
	return gl_winningPlayer;
}

public int Native_GetStatDelay(Handle hPlugin, int iNumParams)
{
	return view_as<int>(gl_statDelay);
}

public void OnPluginStart()
{
	HookEvent("round_announce_match_start", Event_RoundAnnounceMatchStart, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("round_mvp", Event_RoundMvp, EventHookMode_Pre);

	RegAdminCmd("m4", Command_M4, ADMFLAG_SLAY, "m4 <#userid|name>");
}

public void OnMapStart()
{
	// Headshot Announcer
	PrecacheSound("commander/train_bodydamageheadshot_01.wav");
	PrecacheSound("commander/train_bodydamageheadshot_01b.wav");
	PrecacheSound("commander/train_bodydamageheadshot_02.wav");

	// Health Restored
	PrecacheSound("items/healthshot_success_01.wav");

	// Hitsounds
	PrecacheSound("ui/item_drop.wav");
	PrecacheSound("ui/item_drop1_common.wav");

	// Killstreak-Sounds
	PrecacheSound("ui/xp_milestone_01.wav");
	PrecacheSound("ui/xp_milestone_02.wav");
	PrecacheSound("ui/xp_milestone_03.wav");
	PrecacheSound("ui/xp_milestone_04.wav");
	PrecacheSound("ui/xp_milestone_05.wav");
	PrecacheSound("ui/xp_levelup.wav");

	// Shotgun receive/lose Sounds
	PrecacheSound("ui/panorama/inventory_new_item_01.wav");
	PrecacheSound("ui/xp_rankdown_02.wav");
}

public void OnClientPostAdminCheck(int client)
{
	// Player joins
	ResetPlayerStats(client);
	gl_playerHasM4[client] = false;
}

public void OnClientDisconnect(int client)
{
	// Player disconnects
	ResetPlayerStats(client);
	gl_playerHasM4[client] = false;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	// Only proceed if actual round ended, not warmup
	if (reason != CSRoundEnd_GameStart)
	{
		gl_matchInProgress = false;

		for (int client = 1; client <= MaxClients ; client++)
		{
			CountShotgunTimeSplit(client);
			gl_playerHasM4[client] = false;
		}

		CalcAndDisplayPlayerStats();
		// Force Match End by AFTER all stats have been displayed
		CreateTimer(gl_statDelay, EndMap);

		// Also disable respawns until new match or map starts
		ServerCommand("sm_cv mp_respawn_on_death_t 0");
		ServerCommand("sm_cv mp_respawn_on_death_ct 0");
	}
}

public Action EndMap(Handle timer)
{
	// Force instant Match-End screen
	ServerCommand("sm_cv mp_maxrounds 0");

	for (int client = 1; client <= MaxClients ; client++)
	{
		if (IsClientInGame(client))
			ForcePlayerSuicide(client);
	}

	CreateTimer(1.0, EndMapReset);
}

public Action EndMapReset(Handle timer)
{
	ServerCommand("sm_cv mp_maxrounds 2");
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	gl_matchInProgress = true;

	for (int client = 1; client <= MaxClients ; client++)
	{
		ResetPlayerStats(client);
	}

	gl_playerWithShotgun = 0;
	gl_winningPlayer = 0;

	UpdateWinner(0); // Resets Winner

	// Reset spawning
	ServerCommand("sm_cv mp_respawn_on_death_t 1");
	ServerCommand("sm_cv mp_respawn_on_death_ct 1");
}

// Disable "MATCH START"-Message if it's actually the end of the map (when forced by EndMap())
public Action Event_RoundAnnounceMatchStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!gl_matchInProgress)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attackerClient = GetClientOfUserId(GetEventInt(event, "attacker"));
	char attackerName[32];
	GetClientName(attackerClient, attackerName, 32);

	int victimClient = GetClientOfUserId(GetEventInt(event, "userid"));
	char victimName[32];
	GetClientName(victimClient, victimName, 32);

	char weaponName[32];
	GetEventString(event, "weapon", weaponName, 32); // does NOT return "weapon_" prefix
	Format(weaponName, 32, "weapon_%s", weaponName); // adds the prefix

	bool headshot = GetEventBool(event, "headshot");

	char sound[255] = "none";
	char soundGlobal[255] = "none";
	float volume = 1.0;
	float volumeGlobal = 1.0;

	if (victimClient < 1 || victimClient > GetMaxHumanPlayers())
	{
		return;
	}
	else
	{
		// Reset Victim Killstreak
		gl_playerKillstreak[victimClient] = 0;

		// Counts time shotgun was held for on death (if victim had the shotgun)
		CountShotgunTimeSplit(victimClient);

		// If suicide (either with self or with world)
		if ((attackerClient == victimClient) || (attackerClient < 1 || attackerClient > GetMaxHumanPlayers()))
		{
			if (victimClient == gl_playerWithShotgun)
			{
				gl_playerWithShotgun = 0;

				// Print Message
				// Player lost Shotgun. Shotgun no longer exists.
				if (gl_matchInProgress)
				{
					PrintHintTextToAll("<span class='fontSize-xs'>ุ</span><br>[<font color='#ECE37A'>SHOTGUN</font>]<span> </span><span> </span><font color='#EA4B4B'>✖</font> <font color='#AAAEB3'>%s</font>", victimName);

					volume = 0.5;
					sound = "ui/xp_rankdown_02.wav";
					EmitSoundToAll(sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
				}
			}
		}

		// If another player gets kill credit
		if ((attackerClient != victimClient) && (1 <= attackerClient <= MaxClients) && IsClientInGame(attackerClient))
		{
			// Replenish Health on Kill
			if (GetEntProp(attackerClient, Prop_Send, "m_iHealth") < 100)
			{
				SetEntityHealth(attackerClient, 100);
				EmitHealParticles(attackerClient);
				EmitSoundToClient(attackerClient, "items/healthshot_success_01.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.35, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
			}

			// Increase Player Killstreak and Killcount-Stat
			gl_playerKills[attackerClient]++;
			gl_playerKillstreak[attackerClient]++;

			// Update Player Highest Killstreak
			if (gl_playerHighestKillstreak[attackerClient] < gl_playerKillstreak[attackerClient])
				gl_playerHighestKillstreak[attackerClient] = gl_playerKillstreak[attackerClient];

			// Increase USP Headshots-Stat
			if (StrEqual(weaponName, "weapon_usp_silencer") && headshot)
				gl_playerUspHeadshots[attackerClient]++;

			// Update new Winning Player
			if ((gl_matchInProgress) && ((gl_playerKills[gl_winningPlayer] < gl_playerKills[attackerClient]) || (gl_winningPlayer == 0)))
			{
				gl_winningPlayer = attackerClient;
				UpdateWinner(gl_winningPlayer);
			}

			// Adds back the 1 used Bullet if using Mag7
			if (StrEqual(weaponName, "weapon_mag7"))
			{
				int weapon_index = GetEntPropEnt(attackerClient, Prop_Send, "m_hActiveWeapon");
				int currentAmmo = GetEntProp(weapon_index, Prop_Send, "m_iClip1");
				SetEntProp(weapon_index, Prop_Send, "m_iClip1", currentAmmo + 1);
			}

			// Awards Mag7 on Kill
			if ((victimClient == gl_playerWithShotgun) || (gl_playerWithShotgun == 0))
			{
				if (GetPlayerWeaponSlot(attackerClient, 0) == -1) // Makes sure the player does not already have a primary weapon
				{
					RequestFrame(GiveShotgun, attackerClient);

					// Keep track of when Shotgun was given
					gl_playerShotgunTimeSplit[attackerClient] = GetGameTime();

					// Print Messages. Symbol reference: ⭆ ➜ ➟ ➠ ➔ ➞ ➥ ➡ ➨ ✔ ✖
					if (victimClient == gl_playerWithShotgun)
					{
						// Player got the Shotgun by killing another Player
						if (gl_matchInProgress)
							PrintHintTextToAll("<span class='fontSize-xs'>ุ</span><br>[<font color='#ECE37A'>SHOTGUN</font>]<span> </span><span> </span><font color='#AAAEB3'>%s</font> <font color='#40FE40'>➡</font> <font color='#FFFFFF'>%s</font>", victimName, attackerName);
					}
					else
					{
						// Player got Shotgun otherwise (usually first kill of the round)
						if (gl_matchInProgress)
							PrintHintTextToAll("<span class='fontSize-xs'>ุ</span><br>[<font color='#ECE37A'>SHOTGUN</font>]<span> </span><span> </span><font color='#40FE40'>✔</font> <font color='#FFFFFF'>%s</font>", attackerName);
					}

					gl_playerWithShotgun = attackerClient;

					volume = 0.08;
					sound = "ui/panorama/inventory_new_item_01.wav";
					EmitSoundToAll(sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
				}
				else if (victimClient == gl_playerWithShotgun)
				{
					// THIS COPIES THE CODE ABOVE. SHOULD BE MADE INTO A FUNCTION AT SOME POINT.
					gl_playerWithShotgun = 0;

					// Print Message
					// Player lost Shotgun. Shotgun no longer exists.
					if (gl_matchInProgress)
					{
						PrintHintTextToAll("<span class='fontSize-xs'>ุ</span><br>[<font color='#ECE37A'>SHOTGUN</font>]<span> </span><span> </span><font color='#EA4B4B'>✖</font> <font color='#AAAEB3'>%s</font>", victimName);

						volume = 0.5;
						sound = "ui/xp_rankdown_02.wav";
						EmitSoundToAll(sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
					}
				}
			}

			// Hitsound
			volume = 0.85;
			switch(GetRandomInt(1, 2))
			{
				case 1: sound = "ui/item_drop.wav";
				case 2: sound = "ui/item_drop1_common.wav";
			}

			EmitSoundToClient(attackerClient, sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

			sound = "none";
			volume = 1.0;

			if (gl_playerKillstreak[attackerClient] >= 5)
			{
				switch(gl_playerKillstreak[attackerClient] % 10)
				{
					case 1:
					{
						volume = 0.16;
						sound = "ui/xp_milestone_01.wav";
					}
					case 2:
					{
						volume = 0.16;
						sound = "ui/xp_milestone_02.wav";
					}
					case 3:
					{
						volume = 0.16;
						sound = "ui/xp_milestone_03.wav";
					}
					case 4:
					{
						volume = 0.16;
						sound = "ui/xp_milestone_04.wav";
					}
					case 5:
					{
						if (!(gl_playerKillstreak[attackerClient] == 5))
						{
							volume = 0.16;
							sound = "ui/xp_milestone_05.wav";
						}
						volumeGlobal = 0.3;
						soundGlobal = "ui/xp_levelup.wav";
						PrintToChatAll("[\x09%d KILLSTREAK\x01] ุ %s", gl_playerKillstreak[attackerClient], attackerName);
					}
					case 6:
					{
						volume = 0.16;
						sound = "ui/xp_milestone_01.wav";
					}
					case 7:
					{
						volume = 0.16;
						sound = "ui/xp_milestone_02.wav";
					}
					case 8:
					{
						volume = 0.16;
						sound = "ui/xp_milestone_03.wav";
					}
					case 9:
					{
						volume = 0.16;
						sound = "ui/xp_milestone_04.wav";
					}
					case 0:
					{
						volume = 0.16;
						sound = "ui/xp_milestone_05.wav";
						volumeGlobal = 0.3;
						soundGlobal = "ui/xp_levelup.wav";
						PrintToChatAll("[\x0F%d KILLSTREAK\x01] ุ %s", gl_playerKillstreak[attackerClient], attackerName);
					}
				}
			}

			if (!StrEqual(sound, "none")) {
				EmitSoundToClient(attackerClient, sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
			}
			if (!StrEqual(soundGlobal, "none"))
			{
				EmitSoundToAll(soundGlobal, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volumeGlobal, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
			}



			if (StrEqual(weaponName, "weapon_usp_silencer") && headshot)
			{
				volume = 1.0;
				switch(GetRandomInt(1, 3))
				{
					case 1: sound = "commander/train_bodydamageheadshot_01.wav";
					case 2: sound = "commander/train_bodydamageheadshot_01b.wav";
					case 3: sound = "commander/train_bodydamageheadshot_02.wav";
				}

				EmitSoundToClient(attackerClient, sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
			}
		}
	}
}

public void GiveShotgun(int client)
{
	GivePlayerItem(client, "weapon_mag7");
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client_index = GetClientOfUserId(GetEventInt(event, "userid"));
	int weapon_index = GetEntPropEnt(client_index, Prop_Send, "m_hActiveWeapon");

	char weaponName[32];
	GetEventString(event, "weapon", weaponName, 32); // already has "weapon_" prefix

	if (StrEqual(weaponName, "weapon_usp_silencer"))
	{
		// Use USP Cycle-Time -0.2sec!
		CreateTimer(0.7, ReloadUsp, weapon_index);
	}
}

public Action ReloadUsp(Handle timer, any weapon_index)
{
	if (IsValidEdict(weapon_index))
	{
		// USP-Clip-Size == 1
		SetEntProp(weapon_index, Prop_Send, "m_iClip1", 1);
	}
}

public void EmitHealParticles(int client)
{
	// Particles visible to OTHER players
	char effectName[64] = "player_heal";

	if (GetEntityFlags(client) & FL_DUCKING)
		effectName = "player_heal_crouch";

	int particle = CreateEntityByName("info_particle_system");

	float pos[3];
	GetClientAbsOrigin(client, pos);
	TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);

	DispatchKeyValue(particle, "start_active", "0");
	DispatchKeyValue(particle, "effect_name", effectName);
	//DispatchKeyValue(particle, "cpoint1", "!activator");
	DispatchSpawn(particle);

	SetVariantString("!activator");
	AcceptEntityInput(particle, "SetParent", client, particle, 0);

	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");

	SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", client);
	RemoveEdictAlwaysFlag(particle);
	SDKHook(particle, SDKHook_SetTransmit, OnSetTransmitEmitHealParticles);

	// Particles for local client
	TE_Start("EffectDispatch");
	TE_WriteFloatArray("m_vOrigin.x", pos, 3);
	TE_WriteFloatArray("m_vStart.x", pos, 3);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex("player_heal_viewmodel"));
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
	TE_WriteNum("m_fFlags", 0);

	TE_SendToClient(client);
}

public void RemoveEdictAlwaysFlag(int edict)
{
	if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
	}
}

public Action OnSetTransmitEmitHealParticles(int entity, int client)
{
	RemoveEdictAlwaysFlag(entity);
	if (GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") != client)
	{
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

stock int GetParticleEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX) {
		return iIndex;}

	return 0;
}

stock int GetEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX){
		return iIndex;}

	return 0;
}



// STATS

stock void UpdateWinner(int client)
{
	if (client == 0) // World is winner (Nobody has a kill)
	{
		ServerCommand("sm_cv mp_teamname_1 \" \"");
		ServerCommand("sm_cv mp_teamname_2 \" \"");
		ServerCommand("sm_cv mp_default_team_winner_no_objective 0");
	}
	else
	{
		char clientName[32];
		GetClientName(client, clientName, 32);

		ServerCommand("sm_cv mp_teamname_1 \"%s\"", clientName);
		ServerCommand("sm_cv mp_teamname_2 \"%s\"", clientName);
		ServerCommand("sm_cv mp_default_team_winner_no_objective %i", GetClientTeam(client));
	}
}

stock void CountShotgunTimeSplit(int client)
{
	if (gl_playerShotgunTimeSplit[client] > 0.0)
	{
		gl_playerShotgunTime[client] = gl_playerShotgunTime[client] + ( GetGameTime() -	gl_playerShotgunTimeSplit[client] );
		gl_playerShotgunTimeSplit[client] = 0.0;
	}
}

stock void ResetPlayerStats(int client)
{
	gl_playerKills[client] = 0;
	gl_playerKillstreak[client] = 0;
	gl_playerHighestKillstreak[client] = 0;
	gl_playerUspHeadshots[client] = 0;
	gl_playerShotgunTime[client] = 0.0;
	gl_playerShotgunTimeSplit[client] = 0.0;

	if (client == gl_winningPlayer)
	{
		gl_winningPlayer = 0;

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (gl_playerKills[gl_winningPlayer] < gl_playerKills[i])
					gl_winningPlayer = i;
			}
		}

		UpdateWinner(gl_winningPlayer);
	}
}

stock void CalcAndDisplayPlayerStats()
{
	int		statKills[3]							= 0;
	int		statHighestKillstreak[3]	= 0;
	int		statUspHeadshots[3]				= 0;
	float statShotgunTime[3]				= 0.0;

	char	statNamesKills[3][128];
	char	statNamesHighestKillstreak[3][128];
	char	statNamesUspHeadshots[3][128];
	char	statNamesShotgunTime[3][128];

	// Get 1st Place Stats
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (statKills[0]							< gl_playerKills[client])
				statKills[0]								= gl_playerKills[client];

			if (statHighestKillstreak[0]	< gl_playerHighestKillstreak[client])
				statHighestKillstreak[0]		= gl_playerHighestKillstreak[client];

			if (statUspHeadshots[0]				< gl_playerUspHeadshots[client])
				statUspHeadshots[0]					= gl_playerUspHeadshots[client];

			if (statShotgunTime[0]				< gl_playerShotgunTime[client])
				statShotgunTime[0]					= gl_playerShotgunTime[client];
		}
	}

	// Get 2nd & 3rd Place Stats
	for (int i = 1; i <= 2; i++)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				if (statKills[i]							< gl_playerKills[client]							< statKills[i-1])
					statKills[i]								= gl_playerKills[client];

				if (statHighestKillstreak[i]	< gl_playerHighestKillstreak[client]	< statHighestKillstreak[i-1])
					statHighestKillstreak[i]		= gl_playerHighestKillstreak[client];

				if (statUspHeadshots[i]				< gl_playerUspHeadshots[client]				< statUspHeadshots[i-1])
					statUspHeadshots[i]					= gl_playerUspHeadshots[client];

				if (statShotgunTime[i]				< gl_playerShotgunTime[client]				< statShotgunTime[i-1])
					statShotgunTime[i]					= gl_playerShotgunTime[client];
			}
		}
	}

	for (int i = 0; i <= 2; i++)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				char clientName[32];
				GetClientName(client, clientName, 32);

				if (statKills[i] == gl_playerKills[client])
				{
					if (!StrEqual(statNamesKills[i], ""))
						StrCat(statNamesKills[i], 128, ", ");
					StrCat(statNamesKills[i], 128, clientName);
				}

				if (statHighestKillstreak[i] == gl_playerHighestKillstreak[client])
				{
					if (!StrEqual(statNamesHighestKillstreak[i], ""))
						StrCat(statNamesHighestKillstreak[i], 128, ", ");
					StrCat(statNamesHighestKillstreak[i], 128, clientName);
				}

				if (statUspHeadshots[i] == gl_playerUspHeadshots[client])
				{
					if (!StrEqual(statNamesUspHeadshots[i], ""))
						StrCat(statNamesUspHeadshots[i], 128, ", ");
					StrCat(statNamesUspHeadshots[i], 128, clientName);
				}

				if (statShotgunTime[i] == gl_playerShotgunTime[client])
				{
					if (!StrEqual(statNamesShotgunTime[i], ""))
						StrCat(statNamesShotgunTime[i], 128, ", ");
					StrCat(statNamesShotgunTime[i], 128, clientName);
				}
			}
		}
	}

	char buffer[12][512];

	// Color Reference: Gold: #EEBD63; Silver: #D7CDCD; Bronze: #C08667
	if (statKills[0] > 0)
		Format(buffer[0], 512, "<br>[%i] %s", statKills[0], statNamesKills[0]);
	if (statKills[1] > 0)
		Format(buffer[1], 512, "<br><font color='#B2B2B2'>[%i] %s", statKills[1], statNamesKills[1]);
	if (statKills[2] > 0)
		Format(buffer[2], 512, "<br><font color='#8C8C8C'>[%i] %s", statKills[2], statNamesKills[2]);

	if (statHighestKillstreak[0] > 0)
		Format(buffer[3], 512, "<br>[%i] %s", statHighestKillstreak[0], statNamesHighestKillstreak[0]);
	if (statHighestKillstreak[1] > 0)
		Format(buffer[4], 512, "<br><font color='#B2B2B2'>[%i] %s", statHighestKillstreak[1], statNamesHighestKillstreak[1]);
	if (statHighestKillstreak[2] > 0)
		Format(buffer[5], 512, "<br><font color='#8C8C8C'>[%i] %s", statHighestKillstreak[2], statNamesHighestKillstreak[2]);

	if (statUspHeadshots[0] > 0)
		Format(buffer[6], 512, "<br>[%i] %s", statUspHeadshots[0], statNamesUspHeadshots[0]);
	if (statUspHeadshots[1] > 0)
		Format(buffer[7], 512, "<br><font color='#B2B2B2'>[%i] %s", statUspHeadshots[1], statNamesUspHeadshots[1]);
	if (statUspHeadshots[2] > 0)
		Format(buffer[8], 512, "<br><font color='#8C8C8C'>[%i] %s", statUspHeadshots[2], statNamesUspHeadshots[2]);

	char timestamp[64];
	if (statShotgunTime[0] > 0)
	{
		FormatTime(timestamp, 64, "%M:%S", RoundToCeil(statShotgunTime[0]));
		Format(buffer[9],	512, "<br>[%s] %s", timestamp, statNamesShotgunTime[0]);
	}
	if (statShotgunTime[1] > 0)
	{
		FormatTime(timestamp, 64, "%M:%S", RoundToCeil(statShotgunTime[1]));
		Format(buffer[10], 512, "<br><font color='#B2B2B2'>[%s] %s", timestamp, statNamesShotgunTime[1]);
	}
	if (statShotgunTime[2] > 0)
	{
		FormatTime(timestamp, 64, "%M:%S", RoundToCeil(statShotgunTime[2]));
		Format(buffer[11], 512, "<br><font color='#8C8C8C'>[%s] %s", timestamp, statNamesShotgunTime[2]);
	}



	Format(gl_statStrings[0], 940, "<font color='#A3FC85'>KILLS</font>%s%s%s",
	buffer[0], buffer[1], buffer[2]);

	Format(gl_statStrings[1], 940, "<font color='#A3FC85'>HIGHEST KILLSTREAK</font>%s%s%s",
	buffer[3], buffer[4], buffer[5]);

	Format(gl_statStrings[2], 940, "<font color='#A3FC85'>RAILGUN HEADSHOTS</font>%s%s%s",
	buffer[6], buffer[7], buffer[8]);

	Format(gl_statStrings[3], 940, "<font color='#A3FC85'>SHOTGUN HELD FOR</font>%s%s%s",
	buffer[9], buffer[10], buffer[11]);

	float delay_add = 3.4;
	gl_statDelay = 0.0;

	if (statKills[0] > 0)
	{
		CreateTimer(gl_statDelay, DisplayStats, 0);
		gl_statDelay += delay_add;
	}
	if (statHighestKillstreak[0] > 0)
	{
		CreateTimer(gl_statDelay, DisplayStats, 1);
		gl_statDelay += delay_add;
	}
	if (statUspHeadshots[0] > 0)
	{
		CreateTimer(gl_statDelay, DisplayStats, 2);
		gl_statDelay += delay_add;
	}
	if (statShotgunTime[0] > 0)
	{
		CreateTimer(gl_statDelay, DisplayStats, 3);
		gl_statDelay += delay_add;
	}
}

public Action DisplayStats(Handle timer, int stat)
{
	PrintHintTextToAll("%s", gl_statStrings[stat]);
}

public Action Event_RoundMvp(Event event, const char[] name, bool dontBroadcast)
{
	// Disable MVPs
	SetEventInt(event, "userid", 0);
	return Plugin_Continue;
}

public Action Command_M4(int client, int args)
{
	if (args < 1)
	{
		if (client == 0) // Command executed by console (can't execute on self)
		{
			ReplyToCommand(client, " \x0F[Murlisgib]\x01 Usage: m4 <#userid|name>");
			return Plugin_Handled;
		}

		ToggleM4(client);

		if (gl_playerHasM4[client])
		{
			ReplyToCommand(client, " \x0F[Murlisgib]\x01 M4 received");
		}
		else
			ReplyToCommand(client, " \x0F[Murlisgib]\x01 M4 removed");

		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			0, // No Filters
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToCommand(client, " \x0F[Murlisgib]\x01 No matching client found");
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		ToggleM4(target_list[i]);

		char targetName[32];
		char clientName[32];
		GetClientName(target_list[i], targetName, 32);
		GetClientName(client, clientName, 32);

		if (gl_playerHasM4[target_list[i]])
		{
			ReplyToCommand(client, " \x0F[Murlisgib]\x01 M4 given to %s", targetName);
			PrintToChat(target_list[i], " \x0F[Murlisgib]\x01 M4 received from %s", clientName);
		}
		else
		{
			ReplyToCommand(client, " \x0F[Murlisgib]\x01 M4 removed from %s", targetName);
			PrintToChat(target_list[i], " \x0F[Murlisgib]\x01 M4 removed by %s", clientName);
		}
	}

	return Plugin_Handled;
}

void ToggleM4(int target)
{
	// Strip current Primary Weapon
	int weapon;
	weapon = GetPlayerWeaponSlot(target, 0);
	if (weapon >= 0)
		RemovePlayerItem(target, weapon);

	if (!gl_playerHasM4[target])
	{
		// Give M4
		GivePlayerItem(target, "weapon_m4a1_silencer");

		gl_playerHasM4[target] = true;

		if (target == gl_playerWithShotgun)
		{
			gl_playerWithShotgun = 0;
			CountShotgunTimeSplit(target);
		}

	}
	else
	{
		// Switch back to USP if M4 was selected
		if (GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon") == GetPlayerWeaponSlot(target, 0))
			ClientCommand(target, "slot%d", 2);

		gl_playerHasM4[target] = false;
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (gl_playerHasM4[client])
	{
		// Strip current Primary Weapon
		int weapon;
		weapon = GetPlayerWeaponSlot(client, 0);
		if (weapon >= 0)
			RemovePlayerItem(client, weapon);

		GivePlayerItem(client, "weapon_m4a1_silencer");
	}
}