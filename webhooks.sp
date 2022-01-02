#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <smlib>
#include <discordWebhookAPI>

ConVar cvWebhookUrl;
ConVar cvHostname;
ConVar cvHostport;
ConVar cvNetPublicAdr;

ArrayList connectedUserIDs;

public Plugin myinfo =
{
	name = "Webhooks",
	author = "murlis",
	description = "Provides Discord Webhook integration for server events.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

public void OnPluginStart()
{
	cvWebhookUrl = CreateConVar("gib_webhook_url", "", "Discord Webhook URL to post status updates to.", FCVAR_PROTECTED);
	cvHostname = FindConVar("hostname");
	cvHostport = FindConVar("hostport");
	cvNetPublicAdr = FindConVar("net_public_adr");

	connectedUserIDs = new ArrayList();

	HookEvent("player_connect_full", OnPlayerConnect);
	HookEvent("player_disconnect", OnPlayerDisconnect);
}

public Action OnPlayerConnect(Event event, const char[] sName, bool dontBroadcast)
{
	if (event.GetBool("bot")) return;
	int userID = event.GetInt("userid");
	int client = GetClientOfUserId(userID);

	if (connectedUserIDs.FindValue(userID) > -1) return;

	connectedUserIDs.Push(userID);
	SendWebhookPlayerConnect(client);
}

public Action OnPlayerDisconnect(Event event, const char[] sName, bool dontBroadcast)
{
	if (event.GetBool("bot")) return;
	int userID = event.GetInt("userid");

	int index = connectedUserIDs.FindValue(userID);
	if (index > -1)
		connectedUserIDs.Erase(index);

	if (connectedUserIDs.Length == 0)
		SendWebhookServerEmpty();
}

void SendWebhookPlayerConnect(int newClient)
{
	char sWebhookURL[1024];
	cvWebhookUrl.GetString(sWebhookURL, sizeof sWebhookURL);

	if (sWebhookURL[0] == '\0') return;

	Webhook webhook = new Webhook("");

	char sDescription[512];
	char sIP[256];
	int port;
	cvNetPublicAdr.GetString(sIP, sizeof sIP);
	port = cvHostport.IntValue;
	Format(sDescription, sizeof sDescription, "🔌 steam://connect/%s:%d", sIP, port);

	Embed embed = new Embed("Player joined", sDescription);
	embed.SetColor(7430060);
	embed.SetTimeStampNow();

	EmbedThumbnail thumbnail = new EmbedThumbnail();
	thumbnail.SetURL("https://gib.murl.is/static/embed.png");
	embed.SetThumbnail(thumbnail);
	delete thumbnail;

	char sHostname[256];
	cvHostname.GetString(sHostname, sizeof sHostname);

	EmbedFooter footer = new EmbedFooter(sHostname);
	embed.SetFooter(footer);
	delete footer;

	EmbedField fieldPlayers = new EmbedField();
	fieldPlayers.SetName("Players");
	char sPlayerList[4096];
	LOOP_CLIENTS(client, CLIENTFILTER_NOBOTS)
	{
		char sSteamID64[24];
		GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof sSteamID64);
		Format(
			sPlayerList, sizeof sPlayerList, "%s%s[%N](https://steamcommunity.com/profiles/%s)\n",
			sPlayerList,
			client == newClient ? "🆕 " : "",
			client,
			sSteamID64
		);
	}

	fieldPlayers.SetValue(sPlayerList);
	fieldPlayers.SetInline(true);
	embed.AddField(fieldPlayers);

	char sMap[PLATFORM_MAX_PATH];
	char sMapDisplayName[512];
	GetCurrentMap(sMap, sizeof sMap);
	GetMapDisplayName(sMap, sMapDisplayName, sizeof sMapDisplayName);
	EmbedField fieldMap = new EmbedField();
	fieldMap.SetName("Map");
	fieldMap.SetValue(sMapDisplayName);
	fieldMap.SetInline(true);
	embed.AddField(fieldMap);

	webhook.AddEmbed(embed);

	webhook.Execute(sWebhookURL, OnWebHookExecuted);
}

void SendWebhookServerEmpty()
{
	char sWebhookURL[1024];
	cvWebhookUrl.GetString(sWebhookURL, sizeof sWebhookURL);

	if (sWebhookURL[0] == '\0') return;

	Webhook webhook = new Webhook("");

	Embed embed = new Embed("Server empty", "Party's over! 🌚");
	embed.SetColor(7430060);
	embed.SetTimeStampNow();

	EmbedThumbnail thumbnail = new EmbedThumbnail();
	thumbnail.SetURL("https://gib.murl.is/static/embed.png");
	embed.SetThumbnail(thumbnail);
	delete thumbnail;

	char sHostname[256];
	cvHostname.GetString(sHostname, sizeof sHostname);

	EmbedFooter footer = new EmbedFooter(sHostname);
	embed.SetFooter(footer);
	delete footer;

	webhook.AddEmbed(embed);

	webhook.Execute(sWebhookURL, OnWebHookExecuted);
}


public void OnWebHookExecuted(HTTPResponse response, DataPack pack)
{
	if (response.Status == HTTPStatus_NoContent) return;

	LogMessage("An error has occured while sending a webhook.");
}
