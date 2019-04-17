#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "Murlisgib Resources",
	author = "murlis",
	description = "Download and precache custom resources.",
	version = "1.0",
	url = "http://steamcommunity.com/id/muhlex"
};

public OnMapStart() 
{
	// ### DOWNLOADS ###

	// Bullet Decals
	AddFileToDownloadsTable("materials/murlisgib/decals/1.vmt");
	AddFileToDownloadsTable("materials/murlisgib/decals/1.vtf");

	// Can't use the following random bullet impacts when changing them serverside via decals_subrect.txt:
	//AddFileToDownloadsTable("materials/decals/murlisgib/2.vmt");
	//AddFileToDownloadsTable("materials/decals/murlisgib/2.vtf");
	//AddFileToDownloadsTable("materials/decals/murlisgib/3.vmt");
	//AddFileToDownloadsTable("materials/decals/murlisgib/3.vtf");
	//AddFileToDownloadsTable("materials/decals/murlisgib/4.vmt");
	//AddFileToDownloadsTable("materials/decals/murlisgib/4.vtf");

	// Particles
	AddFileToDownloadsTable("particles/murlisgib/base.pcf");
	AddFileToDownloadsTable("particles/murlisgib/gibs.pcf");
	AddFileToDownloadsTable("particles/murlisgib/gibs_special.pcf");

	// Particle Materials
	AddFileToDownloadsTable("materials/murlisgib/particles/particle_heal_cross.vmt");
	AddFileToDownloadsTable("materials/murlisgib/particles/particle_heal_cross.vtf");


	// ### PRECACHING ###
	PrecacheGeneric("particles/murlisgib/base.pcf", true);
	PrecacheGeneric("particles/murlisgib/gibs.pcf", true);
	PrecacheGeneric("particles/murlisgib/gibs_special.pcf", true);
}

/*
#include <sdkhooks>
#include <fpvm_interface>

#define WEAPON "weapon_mag7" // weapon to replace
#define MODEL "models/weapons/v_shot_freedom.mdl" // custom view model

int g_Model;
*/

/*
public OnMapStart() 
{
	g_Model = PrecacheModel(MODEL); // Custom model
}
*/

/*
public OnClientPostAdminCheck(client)
{
	FPVMI_AddViewModelToClient(client, WEAPON, g_Model); // add custom view model to the player
}
*/

/*
 * Shotgun Models and Materials (MAG-7)
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/freedom_body.vmt");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/freedom_body_d.vtf");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/freedom_body_e.vtf");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/freedom_body_n.vtf");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/freedom_mag_body.vmt");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/freedom_mag_body_d.vtf");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/freedom_mag_body_e.vtf");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/freedom_mag_body_n.vtf");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/lens01.vmt");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/lens01.vtf");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/mode.vmt");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold/scan.vtf");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold_sniper/freedom_body.vmt");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold_sniper/freedom_mag_body.vmt");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold_sniper/lens01.vmt");
AddFileToDownloadsTable("materials/models/weapons/v_models/freedom_blackgold_sniper/mode.vmt");
AddFileToDownloadsTable("models/weapons/v_shot_freedom.dx90.vtx");
AddFileToDownloadsTable("models/weapons/v_shot_freedom.mdl");
AddFileToDownloadsTable("models/weapons/v_shot_freedom.vvd");
*/