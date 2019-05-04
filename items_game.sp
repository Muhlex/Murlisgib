#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PATH_ITEMS_GAME "scripts/items/items_game.txt"

KeyValues g_kv;
bool g_restart = false;

public Plugin myinfo =
{
	name = "Murlisgib Weapon Stats",
	author = "murlis",
	description = "Changes weapon's stats for Murlisgib.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

public void OnPluginStart()
{
	LoadItemsGame();

	if (CheckItemsGameReady())
	{
		LogMessage("items_game.txt is already modified for Murlisgib.");
	}
	else
	{
		LogMessage("items_game.txt is not modified for Murlisgib. Updating file...");
		UpdateItemsGame();
		g_restart = true;
	}
}

public void OnMapStart()
{
	// Delay Server restart until the command actually works
	if (g_restart)
		ServerCommand("_restart");
}

stock bool LoadItemsGame() {

	if (!FileExists(PATH_ITEMS_GAME, true))
	{
		SetFailState("Unable to find items_game.txt.", PATH_ITEMS_GAME);
		return false;
	}

	g_kv = new KeyValues("items_game");

	if (!g_kv.ImportFromFile(PATH_ITEMS_GAME))
	{
		SetFailState("Unable to load items_game.txt.");
		return false;
	}

	return true;
}

stock bool CheckItemsGameReady()
{
	g_kv.Rewind();

	if (!g_kv.JumpToKey("murlisgib"))
		return false;

	if(!g_kv.GetNum("modified"))
		return false;

	return true;
}

stock void UpdateItemsGame()
{
	ModifyWeaponStat("weapon_mag7",						"damage",														"200");
	ModifyWeaponStat("weapon_mag7",						"cycletime",												"0.700000");
	ModifyWeaponStat("weapon_mag7",						"range modifier",										"0.120000");
	ModifyWeaponStat("weapon_mag7",						"primary reserve ammo max",					"5");
	ModifyWeaponStat("weapon_mag7",						"max player speed",									"250");
	ModifyWeaponStat("weapon_mag7",						"max player speed alt",							"250");
	ModifyWeaponStat("weapon_mag7",						"flinch velocity modifier small",		"20");
	ModifyWeaponStat("weapon_mag7",						"flinch velocity modifier large",		"20");

	ModifyWeaponStat("weapon_m4a1_silencer",	"has silencer",											"0");
	ModifyWeaponStat("weapon_m4a1_silencer",	"damage",														"1000");
	ModifyWeaponStat("weapon_m4a1_silencer",	"range modifier",										"1.000000");
	ModifyWeaponStat("weapon_m4a1_silencer",	"penetration",											"10");
	ModifyWeaponStat("weapon_m4a1_silencer",	"primary clip size",								"250");
	ModifyWeaponStat("weapon_m4a1_silencer",	"primary reserve ammo max",					"250");
	ModifyWeaponStat("weapon_m4a1_silencer",	"max player speed",									"250");
	ModifyWeaponStat("weapon_m4a1_silencer",	"max player speed alt",							"250");
	ModifyWeaponStat("weapon_m4a1_silencer",	"flinch velocity modifier small",		"20");
	ModifyWeaponStat("weapon_m4a1_silencer",	"flinch velocity modifier large",		"20");

	ModifyWeaponStat("weapon_usp_silencer",		"has silencer",											"0");
	ModifyWeaponStat("weapon_usp_silencer",		"damage",														"1000");
	ModifyWeaponStat("weapon_usp_silencer",		"cycletime",												"0.800000"); // previously 1.1
	ModifyWeaponStat("weapon_usp_silencer",		"range modifier",										"1.000000");
	ModifyWeaponStat("weapon_usp_silencer",		"range",														"8192");
	ModifyWeaponStat("weapon_usp_silencer",		"penetration",											"10");
	ModifyWeaponStat("weapon_usp_silencer",		"primary clip size",								"1");
	ModifyWeaponStat("weapon_usp_silencer",		"primary reserve ammo max",					"0");
	ModifyWeaponStat("weapon_usp_silencer",		"max player speed",									"250");
	ModifyWeaponStat("weapon_usp_silencer",		"max player speed alt",							"250");
	ModifyWeaponStat("weapon_usp_silencer",		"flinch velocity modifier small",		"20");
	ModifyWeaponStat("weapon_usp_silencer",		"flinch velocity modifier large",		"20");

	SaveItemsGame(true);
}

stock bool SaveItemsGame(bool state = true)
{
	g_kv.Rewind();

	if (!g_kv.JumpToKey("murlisgib", true))
		return false;

	g_kv.SetNum("modified", state);
	g_kv.Rewind();

	if (!g_kv.ExportToFile(PATH_ITEMS_GAME))
		return false;

	delete g_kv;
	return true;
}

stock bool ModifyWeaponStat(char[] weapon, char[] stat, char[] value)
{
	g_kv.Rewind();

	if (!g_kv.JumpToKey("prefabs"))
		return false;

	char buffer[64];
	Format(buffer, sizeof(buffer), "%s_prefab", weapon);

	if (!g_kv.JumpToKey(buffer))
		return false;

	if (!g_kv.JumpToKey("attributes"))
		return false;

	g_kv.SetString(stat, value);
	g_kv.Rewind();

	if (!g_kv.ExportToFile(PATH_ITEMS_GAME))
		return false;

	return true;
}