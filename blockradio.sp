#include <sourcemod>

public Plugin myinfo =
{
	name = "Block Radio",
	author = "murlis",
	description = "Blocks all radio commands.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

char szRadioCommands [][] = {
	"cheer",
	"compliment",
	"coverme",
	"enemydown",
	"enemyspot",
	"fallback",
	"followme",
	"getinpos",
	"getout",
	"go",
	"go_a",
	"go_b",
	"holdpos",
	"inposition",
	"needbackup",
	"needrop",
	"negative",
	"regroup",
	"report",
	"reportingin",
	"roger",
	"sectorclear",
	"sorry",
	"sticktog",
	"stormfront",
	"takepoint",
	"takingfire",
	"thanks"
};

public void OnPluginStart()
{
	for (int i = 0; i < sizeof(szRadioCommands); i++)
	{
		AddCommandListener(CommandListener_RadioCommands, szRadioCommands[i]);
	}
}

public Action CommandListener_RadioCommands(int iClient, const char[] szCommand, int iNumArgs)
{
	return Plugin_Handled;
}
