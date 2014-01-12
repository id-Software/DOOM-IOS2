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

#ifndef DOOM_GAME_CENTER_MATCH_H
#define DOOM_GAME_CENTER_MATCH_H

#include "ios/GameCenter.h"
#include "iphone_doom.h"

#include <tr1/array>
#include <vector>
#include <string>
#include <tr1/cstdint>

class DoomGameCenterMatch : public idGameCenterMatchHandler {
public:
	virtual ~DoomGameCenterMatch();

private:
	virtual void createdMatchImpl();
	virtual void allPlayersConnectedImpl( std::vector<std::string> connectedPlayerIDs );
	virtual void playerConnectedImpl( std::string playerIdentifier );
	virtual void playerDisconnectedImpl( std::string playerIdentifier );
	
	virtual void receivedDataImpl( std::string fromPlayerID, const void * data, int numBytes );
};

extern DoomGameCenterMatch gDoomGameCenterMatch;
extern std::string serverGameCenterID;
extern std::tr1::array<std::string, 4> playerIndexToIDMap;

void SetupEmptyNetGame();
void SendGameCenterSetup();
void SendJoinPacket();

std::tr1::uint32_t GeneratePlayerGroup( const int deathmatch,
										const int missionPack,
										const int mapNum,
										const int fragLimit,
										const int timeLimit,
										const int skill );
										
packetSetup_t GenerateSetupPacketFromPlayerGroup( std::tr1::uint32_t playerGroup );

#endif
