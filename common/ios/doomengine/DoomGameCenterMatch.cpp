/*
 
 Copyright (C) 2009-2011 id Software LLC, a ZeniMax Media company.
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 */

#include "DoomGameCenterMatch.h"
#include "doomiphone.h"
#include "ios/ios_interface.h"

#include <cstdio>
#include <string>
#include <algorithm>

DoomGameCenterMatch gDoomGameCenterMatch;

std::string serverGameCenterID;
std::tr1::array<std::string, 4> playerIndexToIDMap;

namespace {
	bool IsServer() {
		return setupPacket.gameID == localGameID;
	}
	
	int numPlayersToJoin = 0;
}

DoomGameCenterMatch::~DoomGameCenterMatch() {
}

void DoomGameCenterMatch::createdMatchImpl() {
	std::printf( "Created a DOOM match!\n" );
}

void DoomGameCenterMatch::allPlayersConnectedImpl( std::vector<std::string> connectedPlayerIDs ) {
	std::printf( "All players connected to a DOOM match!\n" );
	
	// Send an initial setup packet if this is the server, this will cause clients to
	// send their join packets.
	if ( IsServer() ) {	
		printf( "Server broadcasting initial setup packet.\n" );
		
		numPlayersToJoin = connectedPlayerIDs.size();
		assert( numPlayersToJoin > 0 );
		SendGameCenterSetup();
	}
}

void DoomGameCenterMatch::playerConnectedImpl( std::string playerIdentifier ) {
	std::printf( "Player %s connected!\n", playerIdentifier.c_str() );
}

void DoomGameCenterMatch::playerDisconnectedImpl( std::string playerIdentifier ) {
	std::printf( "Player %s disconnected!\n", playerIdentifier.c_str() );
	
	if ( IsServer() ) {
		// Only the server tracks disconnected players. The next server packet sent to each
		// client will have the new playeringame[MAXPLAYERS] info.
		for ( int i = 0; i < MAXPLAYERS; ++i ) {
			if ( playerIndexToIDMap[i] == playerIdentifier ) {
				playeringame[i] = false;
			}
		}
	} else {
		// If we are a client, and the server is the one that disconnected, we're hosed.
		if ( !netGameFailure && playerIdentifier == serverGameCenterID ) {
			netGameFailure = NF_LOST_SERVER;
			
			idGameCenter::DisconnectFromMatch();
			
			ShowSystemAlert( "#LostServerTitle", "#LostServerMessage" );
			
			iphoneMainMenu();
		}
	}
}

template<class Type, size_t Size>
const Type * end( const Type (&testArray)[Size] ) {
	return testArray + Size;
}

template<class Type, size_t Size>
bool ArrayContains( const Type (&testArray)[Size], const Type & value ) {
	return std::find( testArray, end( testArray ), value ) != end( testArray );
}

/*
 ==================
 DoomGameCenterMatch::receivedDataImpl
 
 A packet has been received from Game Center. Because the Game Center "callback" actually runs
 on the main thread, it should be safe to directly process the packets here. This should only
 be called in between displaylink updates.
 ==================
 */
void DoomGameCenterMatch::receivedDataImpl( std::string fromPlayerID, const void * data, int numBytes ) {
	
	if ( numBytes < 4 ) {
		std::printf( "discarding packet because numBytes = %i.\n", numBytes );
		return;
	}
	
	int	packetID = *(int *)data;
	
	if ( packetID == PACKET_VERSION_SETUP ) {
		std::printf( "Received a setup packet!\n" );
		
		// Only the server sends setup packets, and we need to keep track of it's ID.
		serverGameCenterID = fromPlayerID;
		
		if ( localGameID == setupPacket.gameID ) {
			// if we are sending packets, always ignore other setup packets
			printf( "discarding setup packet because we are the server\n" );
			return;
		}
		setupPacketFrameNum = iphoneFrameNum;

		// save this packet
		setupPacket = *(packetSetup_t *)data;
		
		// Send a join packet to the server so that it's aware of this client, if this client
		// isn't already in the list.
		if ( !ArrayContains( setupPacket.playerID, localGameID ) ) {
			printf( "This client has not notified the server yet - sending join packet.\n" );
			SendJoinPacket();
		}
		
		// check for game start in a received setup packet
		if ( !netgame && setupPacket.startGame ) {
			StartupWithCorrectWads( setupPacket.map.dataset );
		
			ShowGLView();
		
			if ( StartNetGame() ) {
				setupPacket.startGame = false;
				// we aren't in this game
			}
			
			
		}
		
		return;
	}
	
	if ( packetID == PACKET_VERSION_JOIN ) {
		// we should only process join packets if we are running the current game
		if ( setupPacket.gameID != localGameID ) {
			printf( "discarding join packet because we aren't the server\n" );
			return;
		}
		
		packetJoin_t *pj = (packetJoin_t *)data;
		if ( pj->playerID == 0 ) {
			// should never happen
			printf( "discarding join packet because playerID is 0\n" );
			return;
		}
		// add this player
		int	i;
		for ( i = 0 ; i < MAXPLAYERS ; i++ ) {
			if ( setupPacket.playerID[i] == pj->playerID ) {
				netPlayers[i].peer.lastPacketTime = SysIphoneMilliseconds();
				break;
			}
		}
		if ( i == MAXPLAYERS ) {
			// not in yet, add if possible
			for ( i = 0 ; i < MAXPLAYERS ; i++ ) {
				if ( setupPacket.playerID[i] == 0 ) {
					setupPacket.playerID[i] = pj->playerID;
					
					// Save this client's GameCenter ID to send it packets later.
					playerIndexToIDMap[i] = fromPlayerID;
					
					//netPlayers[i].peer.address = *from;
					netPlayers[i].peer.lastPacketTime = SysIphoneMilliseconds();
					
					--numPlayersToJoin;
					
					break;
				}
			}
			// if all players are active, the new join gets ignored
		}

		printf( "valid join packet from %s\n", fromPlayerID.c_str() );		
		
		if ( numPlayersToJoin == 0 ) {
			std::printf( "Server starting the game!\n" );
			
			// Got the join packet from everyone, start the game!
			setupPacket.startGame = 1;
			
			StartupWithCorrectWads( setupPacket.map.dataset );
			
			StartNetGame();
			ShowGLView();
		}
		
		// Broadcast another setup packet to let each client know that someone else joined.
		SendGameCenterSetup();
		
		return;
	}
	
	
	// The only other packets we should be recieving are client and server packets. This call
	// will handle those.
	iphoneProcessPacket( NULL, data, numBytes );
	
	return;
}




void SetupEmptyNetGame() {
	// Disconnect from any previous multiplayer game
	idGameCenter::DisconnectFromMatch();
	
	// no current setup packet, so initialize with this phone's default values
	localGameID = SysIphoneMicroseconds();
	memset( &setupPacket, 0, sizeof( setupPacket ) );
	setupPacket.gameID = localGameID;
	setupPacket.packetType = PACKET_VERSION_SETUP;
	setupPacket.map.dataset = mpExpansion->value;
	setupPacket.map.episode = mpEpisode->value;
	setupPacket.map.map = mpMap->value;
	setupPacket.map.skill = mpSkill->value;
	setupPacket.deathmatch = mpDeathmatch->value;
	setupPacket.timelimit = timeLimit->value;
	setupPacket.fraglimit = fragLimit->value;
	setupPacket.playerID[0] = playerID;
}

/*
 ==================
 SendJoinPacket
 
 These will be sent to the server ever frame we are in the multiplayer menu.
 ==================
 */
void SendJoinPacket() {
	packetJoin_t	pj;
	
	pj.packetType = PACKET_VERSION_JOIN;
	pj.gameID = setupPacket.gameID;
	pj.playerID = playerID;
	
	idGameCenter::SendPacketToPlayerReliable( serverGameCenterID, &pj, sizeof( pj ) );
}

/*
 ==================
 SendGameCenterSetup
 
 the server sends out a setup packet to each joined client so they
 can see the game options needed to start the game.
 ==================
 */
void SendGameCenterSetup() {
	if ( setupPacket.gameID != localGameID ) {
		// we aren't the server
		return;
	}
	
	if ( gametic >= 2 ) {
		// everyone has already started, so they don't need more setup packets
		return;
	}

	setupPacket.sendCount++;
	idGameCenter::BroadcastPacketReliable( &setupPacket, sizeof( setupPacket ) );
	
}







//------------------------
// In order to facilitate automatching through Game Center, we can use a 32-bit playerGroup
// value. Players will only be matched with other players with the exact same playerGroup.
// Unfortunately, there doesn't seem to be a way to do more complex logical operations, such
// as match a player who is willing to play on any map with a player who has chosen a specific
// map.
//
// These functions will take the game setup parameters and create a 32-bit playerGroup value to
// match with other players who have chosen the same settings.
//
// In order to pack the game parameters into 32 bits, we use the following information:
//
// Deathmatch field requires 2 bits for 4 possible values.
// 		This will be 0 for co-op, 1 for deathmatch, and 2 for altdeath.
//
// Expansion pack field requires 3 bits for 8 possible values, but we only have 5 expansions
// currently.
//		This will simply be the enum value of iphoneMissionPack_t.
//
// Map number will require 5 bits for 32 possible maps per expansion, but let's use 6 since a)
// we have the space b) it allows for future expansion and c) allows us to start counting at 1,
// which is the natural first index for map nums.
//
// The frag limit is capped by us at 20, so we'll use 5 bits for this value.
//		Zero here will indicate an infinite frag limit.
//
// The time limit is capped to 20 minutes, so we'll use 5 bits for this value.
//		Zero here will indicate unlimited time.
//
// Skill will require 3 bits for 8 possible values, as there are 5 skill levels.
//
// In summary, we will need 2 + 3 + 6 + 5 + 5 + 3 = 24 bits to completely specify multiplayer
// parameters.
//
// So, the actual format of the playerGroup is:
//
// Bits 0-1: Match type.
// Bits 2-4: Expansion pack.
// Bits 5-10: Map number.
// Bits 11-15: Frag limit.
// Bits 16-20: Time limit in minutes.
// Bits 21-23: Skill level.
//------------------------

namespace {
	const unsigned int deathmatchGroupNumBits = 2;
	const unsigned int expansionGroupNumBits = 3;
	const unsigned int mapGroupNumBits = 6;
	const unsigned int fragLimitGroupNumBits = 5;
	const unsigned int timeLimitGroupNumBits = 5;
	
	// Currently unused
	//static const unsigned int skillGroupNumBits = 3;
	
	const unsigned int deathmatchGroupOffset = 0;
	const unsigned int expansionGroupOffset = deathmatchGroupOffset + deathmatchGroupNumBits;
	const unsigned int mapGroupOffset = expansionGroupOffset + expansionGroupNumBits;
	const unsigned int fragLimitGroupOffset = mapGroupOffset + mapGroupNumBits;
	const unsigned int timeLimitGroupOffset = fragLimitGroupOffset + fragLimitGroupNumBits;
	const unsigned int skillGroupOffset = timeLimitGroupOffset + timeLimitGroupNumBits;
}

//------------------------
// deathmatch: 1 for deathmatch, 2 for altdeath, 0 for cooperative
//------------------------
std::tr1::uint32_t GeneratePlayerGroup( const int deathmatch,
										const int missionPack,
										const int mapNum,
										const int fragLimit,
										const int timeLimit,
										const int skill ) {
	
	
	const int deathmatchGroup = deathmatch << deathmatchGroupOffset;
	const int expansionGroup = static_cast<int>( missionPack ) << expansionGroupOffset;
	const int mapNumGroup = mapNum << mapGroupOffset;
	const int tempFragLimitGroup = fragLimit << fragLimitGroupOffset;
	const int tempTimeLimitGroup = timeLimit << timeLimitGroupOffset;
	const int tempSkillGroup = skill << skillGroupOffset;
	
	// Don't let deathmatch or co-op specific options influence the matchmaking process.
	// If deathmatch, always set skill to 0.
	// If co-op, always set frag limit and time limit to 0.
	const int fragLimitGroup = ( deathmatch == 0 ) ? 0 : tempFragLimitGroup;
	const int timeLimitGroup = ( deathmatch == 0 ) ? 0 : tempTimeLimitGroup;
	const int skillGroup = ( deathmatch != 0 ) ? 0 : tempSkillGroup;

	const int playerGroup = deathmatchGroup
						  	| expansionGroup
							| mapNumGroup
							| fragLimitGroup
							| timeLimitGroup
							| skillGroup;
	
	return playerGroup;
}



//------------------------
// Converts a playerGroup from Game Center into a setupPacket_t
//------------------------
packetSetup_t GenerateSetupPacketFromPlayerGroup( std::tr1::uint32_t playerGroup ) {
	packetSetup_t packet;
	
	packet.packetType = PACKET_VERSION_SETUP;
	packet.gameID = 0;
	packet.startGame = 0;
	packet.sendCount = 0;
	
	packet.map.dataset = 0;
	packet.map.episode = 0;
	packet.map.map = 0;
	packet.map.skill = 0;
	
	packet.deathmatch = 0;
	packet.fraglimit = 0;
	packet.timelimit = 0;
	
	std::fill( packet.playerID, packet.playerID + sizeof( packet.playerID ), 0 );

	return packet;
}


