#if defined _murlisgib_included
	#endinput
#endif
#define _murlisgib_included

#include <sourcemod>
#include <sdktools>
#include <dynamic>

/*
 *
 * All-Purpose Functions
 */

stock void Sound_PlayUIClient(int iClient, char[] szSound, float fVolume)
{
	EmitSoundToClient(iClient, szSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, fVolume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

stock void Sound_PlayUIAll(char[] szSound, float fVolume)
{
	EmitSoundToAll(szSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, fVolume, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
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