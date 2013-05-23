#include <sourcemod>
#include <gungame>

public Plugin:myinfo =
{
	name = "GunGame:SM Map Vote Starter",
	author = GUNGAME_AUTHOR,
	description = "Start the map voting for next map",
	version = GUNGAME_VERSION,
	url = "http://www.hat-city.net/"
};

public GG_OnStartMapVote()
{
	InsertServerCommand("exec gungame\\gungame.mapvote.cfg");
}