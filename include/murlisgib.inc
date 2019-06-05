#if defined _murlisgib_included
	#endinput
#endif
#define _murlisgib_included

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <dynamic>

/*
 *
 * Entity Functions
 */

stock bool Entity_GetWeaponName(int iEntity, char[] szWeaponName, int iMaxlength)
{
	if (!Weapon_IsValid(iEntity))
	{
		return false;
	}

	int iItemDefIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");

	CS_WeaponIDToAlias(CS_ItemDefIndexToID(iItemDefIndex), szWeaponName, iMaxlength);

	Format(szWeaponName, iMaxlength, "weapon_%s", szWeaponName);

	return true;
}

stock bool Entity_CreateForClientByName(int iClient, const char[] szEntityName)
{
	// This function spawns a weapon at the specified Client's Position. Might be possible to do this in a cleaner way.
	float fPos[3];
	GetClientAbsOrigin(iClient, fPos);

	int iEntity = CreateEntityByName(szEntityName);
	if (iEntity != INVALID_ENT_REFERENCE)
	{
		Entity_SetOwner(iEntity, iClient);
		TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iEntity);
		return true;
	}
	else
	{
		return false;
	}
}

/*
 *
 * Sound Functions
 */

stock void Sound_PlayUIClient(int iClient, const char[] szSound, float fVolume)
{
	EmitSoundToClient(iClient, szSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, fVolume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

stock void Sound_PlayUIAll(const char[] szSound, float fVolume)
{
	EmitSoundToAll(szSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, fVolume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

/*
 *
 * Temp-Ent Functions
 */

stock void TE_EffectDispatch(const char[] szEffect, const float vOrigin[3], const float vStart[3], const float vAngles[3] = NULL_VECTOR)
{
	TE_Start("EffectDispatch");
	TE_WriteFloatArray("m_vOrigin.x", vOrigin, 3);
	TE_WriteFloatArray("m_vStart.x", vStart, 3);
	TE_WriteVector("m_vAngles", vAngles);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(szEffect));
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
	TE_WriteNum("m_fFlags", 0);
}

stock int GetParticleEffectIndex(const char[] szEffectName)
{
	static int iTable = INVALID_STRING_TABLE;

	if (iTable == INVALID_STRING_TABLE)
		iTable = FindStringTable("ParticleEffectNames");

	int iIndex = FindStringIndex(iTable, szEffectName);

	if (iIndex != INVALID_STRING_INDEX)
	{
		return iIndex;
	}

	return 0;
}

stock int GetEffectIndex(const char[] szEffectName)
{
	static int iTable = INVALID_STRING_TABLE;

	if (iTable == INVALID_STRING_TABLE)
		iTable = FindStringTable("EffectDispatch");

	int iIndex = FindStringIndex(iTable, szEffectName);

	if (iIndex != INVALID_STRING_INDEX)
	{
		return iIndex;
	}

	return 0;
}

/*
 *
 * Debugging Functions
 */

stock void SerialiseDynamic(Dynamic dynamic)
{
	PrintToServer("GETTING ALL DYNAMIC OBJECT MEMBERS");
	PrintToServer(" > dynamic.MemberCount=%d", dynamic.MemberCount);

	int count = dynamic.MemberCount;
	DynamicOffset memberoffset;
	char membername[DYNAMIC_MEMBERNAME_MAXLEN];
	int someint; bool somebool; float somefloat; char somestring[1024]; Dynamic anotherobj; Handle somehandle; float somevec[3];

	for (int i = 0; i < count; i++)
	{
		memberoffset = dynamic.GetMemberOffsetByIndex(i);
		dynamic.GetMemberNameByIndex(i, membername, sizeof(membername));

		switch (dynamic.GetMemberType(memberoffset))
		{
			case DynamicType_Int:
			{
				someint = dynamic.GetIntByOffset(memberoffset);
				PrintToServer("[%d] <int>dynamic.%s = %d", memberoffset, membername, someint);
			}
			case DynamicType_Bool:
			{
				somebool = dynamic.GetBoolByOffset(memberoffset);
				PrintToServer("[%d] <bool>dynamic.%s = %d", memberoffset, membername, somebool);
			}
			case DynamicType_Float:
			{
				somefloat = dynamic.GetFloatByOffset(memberoffset);
				PrintToServer("[%d] <float>dynamic.%s = %f", memberoffset, membername, somefloat);
			}
			case DynamicType_String:
			{
				dynamic.GetStringByOffset(memberoffset, somestring, sizeof(somestring));
				PrintToServer("[%d] <string>dynamic.%s = '%s'", memberoffset, membername, somestring);
			}
			case DynamicType_Object:
			{
				anotherobj = dynamic.GetDynamicByOffset(memberoffset);
				someint = anotherobj.GetInt("someint");
				PrintToServer("[%d] <dynamic>.<int>dynamic.%s.someint = %d", memberoffset, membername, someint);
			}
			case DynamicType_Handle:
			{
				somehandle = dynamic.GetHandleByOffset(memberoffset);
				PrintToServer("[%d] <Handle>.dynamic.%s = %d", memberoffset, membername, somehandle);
			}
			case DynamicType_Vector:
			{
				dynamic.GetVectorByOffset(memberoffset, somevec);
				PrintToServer("[%d] <Vector>.dynamic.%s = {%f, %f, %f}", memberoffset, membername, somevec[0], somevec[1], somevec[2]);
			}
		}
	}
}