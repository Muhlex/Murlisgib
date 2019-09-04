#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PATH_CONFIG /* SOURCEMOD PATH/ */ "configs/gib_resources.cfg"
#define CONFIG_LINE_MAXLENGTH 256

public Plugin myinfo =
{
	name = "Murlisgib Resources",
	author = "murlis",
	description = "Download and precache custom resources.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

public void OnPluginStart()
{
	RegAdminCmd("res", Command_TEST, ADMFLAG_SLAY, "res");
}

public Action Command_TEST(int iClient, int iArgs)
{
	OnMapStart();
}

public void OnMapStart()
{
	File fiConfig;
	char szConfigPath[PLATFORM_MAX_PATH];
	char szConfigLine[CONFIG_LINE_MAXLENGTH];

	BuildPath(Path_SM, szConfigPath, sizeof(szConfigPath), PATH_CONFIG);
	fiConfig = OpenFile(szConfigPath, "rt", false);


	if (!fiConfig)
		SetFailState("Plugin Config-File empty or corrupt!");

	while (fiConfig.ReadLine(szConfigLine, sizeof(szConfigLine)))
	{
		// Remove whitespace characters (includes newlines)
		TrimString(szConfigLine);

		// Filter out comments and empty lines
		if (StrContains(szConfigLine, "//") == 0 || strlen(szConfigLine) == 0)
		{
			continue;
		}

		DownloadAndPrecache(szConfigLine, sizeof(szConfigLine));
	}
}

void DownloadAndPrecache(const char[] szFilePathInput, int iFilePathLength)
{
	char[] szFilePath = new char[iFilePathLength];
	strcopy(szFilePath, iFilePathLength, szFilePathInput);

	AddFileToDownloadsTable(szFilePath);

	bool bFilePrecached = false;

	// Precache Decal Materials
	if (StrContains(szFilePath, "decals") != -1)
	{
		PrecacheDecal(szFilePath);
		bFilePrecached = true;
	}

	// Precache Models
	if (StrContains(szFilePath, ".mdl") != -1)
	{
		PrecacheModel(szFilePath);
		bFilePrecached = true;
	}

	// Precache Particles
	if (StrContains(szFilePath, ".pcf") != -1)
	{
		PrecacheGeneric(szFilePath, true);
		bFilePrecached = true;
	}

	// Precache Sounds
	if (StrContains(szFilePath, ".wav") != -1 || StrContains(szFilePath, ".mp3") != -1)
	{
		ReplaceString(szFilePath, iFilePathLength, "sound/", "");
		PrecacheSound(szFilePath);
		bFilePrecached = true;
	}

	if (bFilePrecached)
	{
		LogMessage("%s marked for DL and precached.", szFilePath);
	}
	else
	{
		LogMessage("%s marked for DL.", szFilePath);
	}
}

/*
public OnMapStart()
{
	// ### DOWNLOADS ###

	// Bullet Decals
	AddFileToDownloadsTable("materials/murlisgib/decals/1.vmt");
	AddFileToDownloadsTable("materials/murlisgib/decals/1.vtf");

	// Particles
	AddFileToDownloadsTable("particles/murlisgib/base.pcf");
	AddFileToDownloadsTable("particles/murlisgib/gibs.pcf");
	AddFileToDownloadsTable("particles/murlisgib/gibs_special.pcf");

	// Particle Materials
	AddFileToDownloadsTable("materials/murlisgib/particles/particle_heal_cross.vmt");
	AddFileToDownloadsTable("materials/murlisgib/particles/particle_heal_cross.vtf");

	// Sounds
	AddFileToDownloadsTable("sound/murlisgib/blast_jump.wav");
	AddFileToDownloadsTable("sound/murlisgib/gibs/fruit.wav");
	AddFileToDownloadsTable("sound/murlisgib/gibs/fruit_trail.wav");


	// ### PRECACHING ###
	PrecacheSound("murlisgib/blast_jump.wav");
	PrecacheSound("murlisgib/gibs/fruit.wav");
	PrecacheSound("murlisgib/gibs/fruit_trail.wav");

	PrecacheGeneric("particles/murlisgib/base.pcf", true);
	PrecacheGeneric("particles/murlisgib/gibs.pcf", true);
	PrecacheGeneric("particles/murlisgib/gibs_special.pcf", true);
}
*/