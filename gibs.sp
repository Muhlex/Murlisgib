#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

public Plugin myinfo = 
{
	name = "Fruit Gibs",
	author = "murlis",
	description = "Player gib effects on death. Headshots spawn additional/different effects.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

char	g_gibs[128] = "fruit";
float g_clientPosition[MAXPLAYERS + 1][3];
bool	g_isClientPositionSaved[MAXPLAYERS + 1] = false;
int		g_particleHelperId = 0;

public void OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);

	RegAdminCmd("gibs", Command_DebugGibs, ADMFLAG_CHEATS, "gibs <name>");
}

public void OnMapStart()
{
	// ALSO REQUIRES THESE FILES TO BE DOWNLOADED AND PRECACHED:
	// * particles/murlisgib.pcf

	AddFileToDownloadsTable("sound/murlisgib/gibs/fruit.wav");
	AddFileToDownloadsTable("sound/murlisgib/gibs/fruit_trail.wav");

	PrecacheSound("murlisgib/gibs/fruit.wav");
	PrecacheSound("murlisgib/gibs/fruit_trail.wav");
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	GetClientAbsOrigin(client, g_clientPosition[client]);
	g_isClientPositionSaved[client] = true;

	RequestFrame(ResetIsClientPositionSaved, client);
}

public void ResetIsClientPositionSaved(int client)
{
	g_isClientPositionSaved[client] = false;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	bool headshot = GetEventBool(event, "headshot");

	if (!IsValidEntity(client))
		return;
	
	// Remove Ragdoll
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");

	if (ragdoll < 0)
		return;

	AcceptEntityInput(ragdoll, "kill");

	// Check if player_hurt Event was called and the player's position saved
	if (!g_isClientPositionSaved[client])
	{
		// Player Height Reference: 72 Standing. 54 Crouching. 64 (Eyes) Standing. 46 (Eyes) Crouching

		GetClientAbsOrigin(client, g_clientPosition[client]); // As the player is dead, this is not at their feet but at camera (eye)-height.
		g_clientPosition[client][2] = g_clientPosition[client][2] - 46; // Change Z-position to be around target's feet.
	}

	// SOUND

	//EmitSoundToAll("murlisgib/gibs/fruit.wav", SOUND_FROM_WORLD, SNDCHAN_WEAPON, 70, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, -1, g_clientPosition[client], NULL_VECTOR, true, 0.0);
	//EmitSoundToAll("murlisgib/gibs/fruit_trail.wav", SOUND_FROM_WORLD, SNDCHAN_WEAPON, 70, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, -1, g_clientPosition[client], NULL_VECTOR, true, 0.0);
	EmitAmbientSound("murlisgib/gibs/fruit.wav", g_clientPosition[client], SOUND_FROM_WORLD, 70, SND_NOFLAGS, 0.5, SNDPITCH_NORMAL);
	EmitAmbientSound("murlisgib/gibs/fruit_trail.wav", g_clientPosition[client], SOUND_FROM_WORLD, 55, SND_NOFLAGS, 0.75, SNDPITCH_NORMAL);

	// PARTICLES
	// Particle to dispatch:
	char particleName[128];
	Format(particleName, sizeof(particleName), "gibs_%s", g_gibs);

	if (headshot) // Different Effect is displayed if the player was headshot
		Format(particleName, sizeof(particleName), "%s_headshot", particleName);

	int particle = CreateEntityByName("info_particle_system");

	DispatchKeyValue(particle, "start_active", "0");

	DispatchKeyValue(particle, "effect_name", particleName);

	DispatchSpawn(particle);

	TeleportEntity(particle, g_clientPosition[client], NULL_VECTOR, NULL_VECTOR);



	// CONTROL POINT HELPER ENTITIES
	char helperParticleName[128];
	Format(helperParticleName, sizeof(helperParticleName), "particle_helper_%i", g_particleHelperId);

	if (g_particleHelperId < 255)
		g_particleHelperId++;
	else
		g_particleHelperId = 0;

	// RGB COLOR (CP 20)
	// Used by: paint
	if (StrEqual(g_gibs, "paint"))
	{
		float color[3];
		switch(GetRandomInt(1, 8))
		{
			case 1: color = {153.0, 121.0, 177.0};
			case 2: color = {222.0, 136.0, 183.0};
			case 3: color = {245.0, 152.0, 169.0};
			case 4: color = {249.0, 180.0, 141.0};
			case 5: color = {182.0, 215.0, 139.0};
			case 6: color = {129.0, 203.0, 182.0};
			case 7: color = {106.0, 202.0, 221.0};
			case 8: color = {113.0, 172.0, 219.0};
		}

		int cpoint20 = CreateEntityByName("info_particle_system");
		
		DispatchKeyValue(cpoint20, "start_active", "0");

		DispatchKeyValue(cpoint20, "targetname", helperParticleName);

		TeleportEntity(cpoint20, color, NULL_VECTOR, NULL_VECTOR);

		// Set Control Points for "real" particle
		DispatchKeyValue(particle, "cpoint20", helperParticleName);

		CreateTimer(10.0, KillEntity, cpoint20);
	}

	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");

	CreateTimer(10.0, KillEntity, particle);



	// SPECIAL PARTICLES (EASTER EGGS)
	char	steamId[20];
	char	effect[64];
	GetClientAuthId(client, AuthId_Engine, steamId, 20, true);

	if			(StrEqual(steamId, "STEAM_1:0:34295497")) // murlis
		effect = "gib_special_coffee";
	else if (StrEqual(steamId, "STEAM_1:1:39836386")) // PdH
		effect = "gib_special_antlers";
	else if (StrEqual(steamId, "STEAM_1:0:32739930")) // melvin
		effect = "gib_special_coke";
	else if (StrEqual(steamId, "STEAM_1:1:111699471")) // Cute Goat 
		effect = "gib_special_sheep";

	if (effect[0]) // if effect is not empty
	{
		int specialParticle = CreateEntityByName("info_particle_system");
		DispatchKeyValue(specialParticle, "start_active", "0");
		DispatchKeyValue(specialParticle, "effect_name", effect);
		DispatchSpawn(specialParticle);
		TeleportEntity(specialParticle, g_clientPosition[client], NULL_VECTOR, NULL_VECTOR);
		ActivateEntity(specialParticle);
		AcceptEntityInput(specialParticle, "start");

		CreateTimer(10.0, KillEntity, specialParticle);
	}
}

public Action KillEntity(Handle timer, int entity)
{
	if (IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public Action Command_DebugGibs(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, " \x0F[Murlisgib]\x01 Usage: gibs <name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	g_gibs = arg;

	return Plugin_Handled;
}