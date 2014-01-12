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


/*
================================================================================================

A game-generic C++ wrapper around the iOS Game Center functionality.


The class checks for Game Center availability in the constructor, and if Game Center is found
to be unsupported, a flag is set that causes all other function calls to early-exit and
do nothing. This way, the game code doesn't have to worry about whether Game Center is supported
for every call it makes, but can still check for support in order to, say, adjust the UI
if necessary.

This class is not meant to be subclassed.

This class uses the pimpl idiom (see http://herbsutter.com/gotw/_100/) to hide many of the
implementation details. I've found this to be a decent way to hide all the Objective-C code
from user code, so that C++-only portions of code can still access iOS functionality.

================================================================================================
*/

#ifndef IDMOBILELIB_GAMECENTER_H
#define IDMOBILELIB_GAMECENTER_H

#include <objc/objc.h>

#include <string>
#include <vector>
#include <tr1/cstdint>

#include "../sys/sys_defines.h"


/*
================================================
Contains function definitions to be overridden by specific games.
================================================
*/
class idGameCenterMatchHandler
{
public:

	virtual ~idGameCenterMatchHandler() {}
	
	void createdMatch() { createdMatchImpl(); }
	void allPlayersConnected( std::vector<std::string> connectedPlayerIDs ) {
		allPlayersConnectedImpl( connectedPlayerIDs );
	}

	void playerConnected( std::string playerIdentifier ) {
		playerConnectedImpl( playerIdentifier );
	}
	
	void playerDisconnected( std::string playerIdentifer ) {
		playerDisconnectedImpl( playerIdentifer );
	}
	
	void receivedData( std::string fromPlayerID, const void * data, int numBytes ) {
		receivedDataImpl( fromPlayerID, data, numBytes );
	}

private:
	virtual void createdMatchImpl() = 0;
	virtual void allPlayersConnectedImpl( std::vector<std::string> connectedPlayerIDs ) = 0;
	virtual void playerConnectedImpl( std::string playerIdentifer ) = 0;
	virtual void playerDisconnectedImpl( std::string playerIdentifer ) = 0;
	
	virtual void receivedDataImpl( std::string fromPlayerID, const void * data, int numBytes ) = 0;
};


namespace idGameCenter {

	static const int	MAX_PACKET_SIZE_IN_BYTES = 1500;

	struct matchParms_t {
		unsigned int minimumPlayers;
		unsigned int maximumPlayers;
		std::tr1::uint32_t automatchGroup;
	};

	void				Initialize();
	void				Shutdown();
	
	void 				AuthenticateLocalPlayer( id currentViewController, idGameCenterMatchHandler * handler );
	
	bool 				IsAvailable();
	bool				IsLocalPlayerAuthenticated();
	
	void				HandleMoveToBackground();
	
	void				PresentMatchmaker( id currentViewController, matchParms_t parms, idGameCenterMatchHandler * handler );
	
	void				PushMatchmakerToNavigationController( id navigationController,
															  matchParms_t parms,
															  idGameCenterMatchHandler * handler );
	
	bool				IsInMatch();
	
	void				SendPacketToPlayerUnreliable( std::string destinationPlayer,
													  void * packet,
													  std::size_t packetSize );
	
	void				SendPacketToPlayerReliable( std::string destinationPlayer,
													void * packet,
													std::size_t packetSize );
	
	void				BroadcastPacketReliable( void * packet, int numBytes );
	
	void				DisconnectFromMatch();
}

#endif
