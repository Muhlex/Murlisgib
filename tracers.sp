#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#define TASER "weapon_tracers_taser_1"
#define TASER2 "weapon_tracers_taser_2"
#define TASER3 "weapon_tracers_taser_3"
//#define GLOW "weapon_taser_glow_impact_1"
//#define GLOW2 "weapon_taser_glow_impact_2"
//#define GLOW3 "weapon_taser_glow_impact_3"
#define HIT "weapon_taser_flash_impact_1"
#define HIT2 "weapon_taser_flash_impact_2"
#define HIT3 "weapon_taser_flash_impact_3"

#define SOUND_SHOOT "survival/select_drop_location.wav"

float g_fLastAngles[MAXPLAYERS + 1][3];
float g_muzzleSound = 1.0;

public Plugin myinfo = 
{
	name = "Zeus Tracers (Simplified)",
	author = "Tak (Chaosxk), murlis",
	description = "Creates the zeus tracer effect on weapon fire.",
	version = "1.0",
	url = "https://github.com/xcalvinsz/zeustracerbullets"
};

public void OnPluginStart()
{
	AddTempEntHook("Shotgun Shot", Hook_BulletShot);
	HookEvent("bullet_impact", Event_BulletImpact);
	HookEvent("player_death", Event_PlayerDeath);
}

public void OnMapStart()
{
	// ALSO REQUIRES THESE FILES TO BE DOWNLOADED AND PRECACHED:
	// * particles/murlisgib.pcf

	PrecacheSound(SOUND_SHOOT);
}
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	// Spawn an impact effect on player death.
	int victimClient = GetClientOfUserId(event.GetInt("userid"));
	int attackerClient = GetClientOfUserId(GetEventInt(event, "attacker"));

	char weaponname[32];
	GetEventString(event, "weapon", weaponname, 32); // does NOT return "weapon_" prefix

	if ((attackerClient != victimClient) && (1 <= attackerClient <= MaxClients) && IsClientInGame(attackerClient))
	{
		float position[3];
		GetClientAbsOrigin(victimClient, position);

		// Slightly adjust Position
		position[2] = position[2] - 20;

		char particle[64];

		if			(StrEqual(weaponname, "usp_silencer"))
		{
			particle = HIT;
		}
		else if	(StrEqual(weaponname, "mag7"))
		{
			particle = HIT2;
		}
		else
		{
			particle = HIT3;
		}

		TE_DispatchEffect(particle, position, position);
		TE_SendToAll();
	}
}

public Action Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	char weaponname[32];
	GetClientWeapon(client, weaponname, 32);

	//if (!(StrEqual(weaponname, "weapon_usp_silencer") || StrEqual(weaponname, "weapon_mag7") || StrEqual(weaponname, "weapon_m4a1_silencer")))
	//	return Plugin_Continue;
	
	float impact_pos[3];
	impact_pos[0] = event.GetFloat("x");
	impact_pos[1] = event.GetFloat("y");
	impact_pos[2] = event.GetFloat("z");
	
	float muzzle_pos[3], camera_pos[3];
	GetWeaponAttachmentPosition(client, "muzzle_flash", muzzle_pos);
	GetWeaponAttachmentPosition(client, "camera_buymenu", camera_pos);
	
	//Create an offset for first person
	float pov_pos[3];
	pov_pos[0] = muzzle_pos[0] - camera_pos[0];
	pov_pos[1] = muzzle_pos[1] - camera_pos[1];
	pov_pos[2] = muzzle_pos[2] - camera_pos[2] + 0.1;
	ScaleVector(pov_pos, 0.4);
	SubtractVectors(muzzle_pos, pov_pos, pov_pos);
	
	//Move the beam a bit forward so it isn't too close for first person
	float distance = GetVectorDistance(pov_pos, impact_pos);
	float percentage = 0.2 / (distance / 100);
	pov_pos[0] = pov_pos[0] + ((impact_pos[0] - pov_pos[0]) * percentage);
	pov_pos[1] = pov_pos[1] + ((impact_pos[1] - pov_pos[1]) * percentage);
	pov_pos[2] = pov_pos[2] + ((impact_pos[2] - pov_pos[2]) * percentage);

	char particle[64];
	//char particleGlow[64];

	if			(StrEqual(weaponname, "weapon_usp_silencer"))
	{
		particle = TASER;
		//particleGlow = GLOW;
	}
	else if	(StrEqual(weaponname, "weapon_mag7"))
	{
		particle = TASER2;
		//particleGlow = GLOW2;
	}
	else
	{
		particle = TASER3;
		//particleGlow = GLOW3;
	}

	//Display the particle to first person 
	TE_DispatchEffect(particle, pov_pos, impact_pos, g_fLastAngles[client]);
	TE_SendToClient(client);

	//Display the particle to everyone else under the normal position
	TE_DispatchEffect(particle, muzzle_pos, impact_pos, g_fLastAngles[client]);
	
	int[] clients = new int[MaxClients];
	int client_count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || i == client || IsFakeClient(i))
			continue;
		clients[client_count++] = i;
	}
	TE_Send(clients, client_count);

	/*
	//Move the impact glow a bit out so it doesn't clip the wall
	impact_pos[0] = impact_pos[0] + ((pov_pos[0] - impact_pos[0]) * percentage);
	impact_pos[1] = impact_pos[1] + ((pov_pos[1] - impact_pos[1]) * percentage);
	impact_pos[2] = impact_pos[2] + ((pov_pos[2] - impact_pos[2]) * percentage);
	
	TE_DispatchEffect(particleGlow, impact_pos, impact_pos);
	TE_SendToAll();
	*/
	
	return Plugin_Continue;
}

public Action Hook_BulletShot(const char[] te_name, const int[] Players, int numClients, float delay)
{
	int client = TE_ReadNum("m_iPlayer") + 1;

	float origin[3];
	TE_ReadVector("m_vecOrigin", origin);
	g_fLastAngles[client][0] = TE_ReadFloat("m_vecAngles[0]");
	g_fLastAngles[client][1] = TE_ReadFloat("m_vecAngles[1]");
	g_fLastAngles[client][2] = 0.0;
	
	float impact_pos[3];
	Handle trace = TR_TraceRayFilterEx(origin, g_fLastAngles[client], MASK_SHOT, RayType_Infinite, TR_DontHitSelf, client);
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(impact_pos, trace);
	}
	delete trace;
	// Play the taser sounds
	char weaponname[32];
	GetClientWeapon(client, weaponname, 32);

	if (StrEqual(weaponname, "weapon_usp_silencer"))
		g_muzzleSound = 2.0;

	if (StrEqual(weaponname, "weapon_mag7"))
		g_muzzleSound = 1.2;
	
	if (StrEqual(weaponname, "weapon_m4a1_silencer"))
		g_muzzleSound = 0.6;

	//EmitAmbientSound(SOUND_IMPACT, impact_pos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, g_impactSound, SNDPITCH_LOW);
	EmitAmbientSound(SOUND_SHOOT, origin, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, g_muzzleSound, SNDPITCH_LOW);
	return Plugin_Continue;
}

public bool TR_DontHitSelf(int entity, int mask, any data)
{
	if (entity == data) 
		return false;
	return true;
}

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

void TE_DispatchEffect(const char[] particle, const float pos[3], const float endpos[3], const float angles[3] = NULL_VECTOR)
{
	TE_Start("EffectDispatch");
	TE_WriteFloatArray("m_vOrigin.x", pos, 3);
	TE_WriteFloatArray("m_vStart.x", endpos, 3);
	TE_WriteVector("m_vAngles", angles);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(particle));
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
	TE_WriteNum("m_fFlags", 0);
}

int GetParticleEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX) {
		return iIndex;}

	return 0;
}

int GetEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX){
		return iIndex;}

	return 0;
}