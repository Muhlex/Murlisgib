#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <murlisgib>

#define PATH_CONFIG /* SOURCEMOD PATH/ */ "configs/gib_messages.cfg"
#define MESSAGE_MAX_LENGTH 512
#define FALLBACK_DEFAULT_COLOR "\x01" // white

StringMap g_smMessages;
StringMap g_smColors;

public Plugin myinfo =
{
	name = "Murlisgib Messages",
	author = "murlis",
	description = "Messages on game events, timed messages and help menues.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

void ColorKeysToValues(char[] szString, const int iStrLen, const StringMap smColorDefinitions)
{
	while (StrContains(szString, "%{") != -1)
	{
		char szStringPartBefore[MESSAGE_MAX_LENGTH]; // value up until a color definition
		char szStringPartColor[MESSAGE_MAX_LENGTH]; // value after (including) color key and }
		char szStringPartAfter[MESSAGE_MAX_LENGTH]; // value after color key
		char szColorKey[32]; // key used to define the color in the config file
		char szColor[5]; // actual color value

		int iColStartPos = SplitString(szString, "%{", szStringPartBefore, sizeof(szStringPartBefore));
		Substring(szStringPartColor, sizeof(szStringPartColor), szString, iStrLen, iColStartPos, iStrLen - 1);
		int iColEndPos = SplitString(szStringPartColor, "}", szColorKey, sizeof(szColorKey));
		Substring(szStringPartAfter, sizeof(szStringPartAfter), szStringPartColor, sizeof(szStringPartColor), iColEndPos, sizeof(szStringPartColor) - 1);

		smColorDefinitions.GetString(szColorKey, szColor, sizeof(szColor));
		Format(szString, iStrLen, "%s%s%s", szStringPartBefore, szColor, szStringPartAfter);
	}
}

void LoadConfig()
{
	char szConfigPath[PLATFORM_MAX_PATH];
	KeyValues kvConfig = new KeyValues("messages");

	g_smMessages = new StringMap();
	g_smColors = new StringMap();

	// Build the path of the Configuration File
	BuildPath(Path_SM, szConfigPath, sizeof(szConfigPath), PATH_CONFIG);

	// Try to import Configuration File
	if (!kvConfig.ImportFromFile(szConfigPath))
		SetFailState("Unable to load config from path: %s", szConfigPath);

	char szKey[128];
	char szValue[MESSAGE_MAX_LENGTH];
	char szColor[5];

	if (kvConfig.JumpToKey("colors"))
	{
		if (!kvConfig.GotoFirstSubKey(false))
			SetFailState("Color section exists but no colors were defined.");

		// Save default color (first color definition)
		kvConfig.GetString(NULL_STRING, szValue, sizeof(szValue));

		ConvertColorCode(szValue, szColor, sizeof(szColor));
		g_smColors.SetString("default", szColor);

		// Loop and save all colors (including default)
		do {
			kvConfig.GetSectionName(szKey, sizeof(szKey));
			kvConfig.GetString(NULL_STRING, szValue, sizeof(szValue));

			ConvertColorCode(szValue, szColor, sizeof(szColor));
			g_smColors.SetString(szKey, szColor);

		} while (kvConfig.GotoNextKey(false));

		kvConfig.Rewind(); // go back to root
	}
	else // no colors defined
	{
		g_smColors.SetString("default", FALLBACK_DEFAULT_COLOR);
	}

	if (kvConfig.JumpToKey("messages"))
	{
		if (!kvConfig.GotoFirstSubKey(false))
			SetFailState("Messages section exists but no messages were defined.");

		// Loop and save all message strings
		do {
			kvConfig.GetSectionName(szKey, sizeof(szKey));

			if (kvConfig.GotoFirstSubKey(false)) // check if message is actually an array of messages
			{
				// Import array of messages
				ArrayList szValues = new ArrayList(MESSAGE_MAX_LENGTH);
				do {
					kvConfig.GetString(NULL_STRING, szValue, sizeof(szValue));
					PrintToServer("<%s> %s", szKey, szValue);

					// Convert color keys to chat color values (mutates szValue)
					ColorKeysToValues(szValue, sizeof(szValue), g_smColors);

					szValues.PushString(szValue);

				} while (kvConfig.GotoNextKey(false));

				g_smMessages.SetValue(szKey, szValues);
			}
			else
			{
				// Import single message
				kvConfig.GetString(NULL_STRING, szValue, sizeof(szValue));
				PrintToServer("<%s> %s", szKey, szValue);

				// Convert color keys to chat color values (mutates szValue)
				ColorKeysToValues(szValue, sizeof(szValue), g_smColors);

				g_smMessages.SetString(szKey, szValue);
			}

		} while (kvConfig.GotoNextKey(false));
	}
}

void PrintMessageToChatFormatted(int iClient, const char[] szFormattedMessage, const int iMsgLen)
{
	char[] szCurrLine    = new char[iMsgLen];
	char[] szMessageRest = new char[iMsgLen];
	char szColor[5];
	int iCurrPos;
	strcopy(szMessageRest, iMsgLen, szFormattedMessage);

	while (iCurrPos != -1)
	{
		// Apply default color to beginning of message rest
		g_smColors.GetString("default", szColor, sizeof(szColor));
		Format(szMessageRest, iMsgLen, " %s%s", szColor, szMessageRest);

		iCurrPos = SplitString(szMessageRest, "\\n", szCurrLine, iMsgLen);

		if (iCurrPos != -1)
		{
			Substring(szMessageRest, iMsgLen, szMessageRest, iMsgLen, iCurrPos, iMsgLen - 1);

			if (iClient == -1)
				PrintToChatAll(szCurrLine);
			else
				PrintToChat(iClient, szCurrLine);
		}
		else
		{
			if (iClient == -1)
				PrintToChatAll(szMessageRest);
			else
				PrintToChat(iClient, szMessageRest);
		}
	}
}

void PrintMessageToChat(int iClient, const char[] szMessageInput, const int iMsgLen, any ...)
{
	char szMessage[MESSAGE_MAX_LENGTH];
	VFormat(szMessage, iMsgLen, szMessageInput, 4);
	PrintMessageToChatFormatted(iClient, szMessage, iMsgLen);
}

void PrintMessageToChatAll(const char[] szMessageInput, const int iMsgLen, any ...)
{
	char szMessage[MESSAGE_MAX_LENGTH];
	VFormat(szMessage, iMsgLen, szMessageInput, 3);
	PrintMessageToChatFormatted(-1, szMessage, iMsgLen);
}

void GetClientIdentifier(char[] szMessage, int iMsgLen, int iClient)
{
	if (IsFakeClient(iClient))
		g_smMessages.GetString("global.player.identifier.bot", szMessage, iMsgLen);
	else
		g_smMessages.GetString("global.player.identifier.player", szMessage, iMsgLen);
}

public void OnPluginStart()
{
	HookEvent("player_connect_full", Event_PlayerConnect);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);

	RegConsoleCmd("sm_help", Command_Help, "Show Murlisgib quick help.");

	LoadConfig();
}

public Action Event_PlayerConnect(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

	char szMessage[MESSAGE_MAX_LENGTH];
	g_smMessages.GetString("local.player.connect", szMessage, sizeof(szMessage));
	PrintMessageToChat(iClient, szMessage, sizeof(szMessage));
}

public Action Event_PlayerDisconnect(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	char szReason[256];
	eEvent.GetString("reason", szReason, sizeof(szReason)); //add default value maybe?

	char szMessage[MESSAGE_MAX_LENGTH];
	char szClientIdentifier[16];
	GetClientIdentifier(szClientIdentifier, sizeof(szClientIdentifier), iClient);

	if (StrContains(szReason, "disconnect", false) != -1)
	{
		g_smMessages.GetString("global.player.disconnect.self", szMessage, sizeof(szMessage));
		PrintMessageToChatAll(szMessage, sizeof(szMessage), szClientIdentifier, iClient);
	}
	else if (StrContains(szReason, "kick", false) != -1)
	{
		g_smMessages.GetString("global.player.disconnect.kick", szMessage, sizeof(szMessage));
		PrintMessageToChatAll(szMessage, sizeof(szMessage), szClientIdentifier, iClient);
	}
	else
	{
		g_smMessages.GetString("global.player.disconnect.other", szMessage, sizeof(szMessage));
		PrintMessageToChatAll(szMessage, sizeof(szMessage), szClientIdentifier, iClient, szReason);
	}

	eEvent.BroadcastDisabled = true;
	return Plugin_Changed;
}

public Action Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	if (
		bDontBroadcast
		|| eEvent.GetBool("disconnect")
		|| eEvent.GetBool("silent")
	) return Plugin_Continue;

	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	int iTeam = eEvent.GetInt("team");

	eEvent.SetBool("silent", true);

	char szMessage[MESSAGE_MAX_LENGTH];
	char szClientIdentifier[16];
	GetClientIdentifier(szClientIdentifier, sizeof(szClientIdentifier), iClient);

	if (iTeam == CS_TEAM_SPECTATOR)
		g_smMessages.GetString("global.player.join.spec", szMessage, sizeof(szMessage));
	else
		g_smMessages.GetString("global.player.join.team", szMessage, sizeof(szMessage));

	PrintMessageToChatAll(szMessage, sizeof(szMessage), szClientIdentifier, iClient);

	return Plugin_Changed;
}

public Action Command_Help(int iClient, int iArgs)
{
	ArrayList szMessageArray = new ArrayList(MESSAGE_MAX_LENGTH);
	g_smMessages.GetValue("menu.help", szMessageArray);

	char szHelpPage[2];
	GetCmdArg(1, szHelpPage, sizeof(szHelpPage));
	int iHelpPage = StringToInt(szHelpPage) - 1;
	if (!(0 < iHelpPage < szMessageArray.Length))
		iHelpPage = 0;

	char szMessage[MESSAGE_MAX_LENGTH];
	szMessageArray.GetString(iHelpPage, szMessage, sizeof(szMessage));
	PrintMessageToChat(iClient, szMessage, sizeof(szMessage));
}
