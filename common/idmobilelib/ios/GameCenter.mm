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

#include "GameCenter.h"
#include "objectivec_utilities.h"
#include "LocalizationObjectiveC.h"
#include "ios_interface.h"

#include <string>

#import <GameKit/GameKit.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIDevice.h>
#import <Foundation/NSData.h>

namespace {
	enum matchmakerViewMode_t {
		MATCH_VIEW_MODAL,
		MATCH_VIEW_PUSH_TO_NAVIGATION_CONTROLLER
	};
}

/*
================================================
The Objective-C delegate required for implementing Game Kit matches.
================================================
*/
@interface MatchDelegate : NSObject< GKMatchmakerViewControllerDelegate, GKMatchDelegate >

@property(nonatomic, assign) UIViewController * 		gameViewController;
@property(nonatomic, assign) idGameCenterMatchHandler * matchHandler;
@property(nonatomic, retain) GKMatch * 					currentMatch;
@property(nonatomic, assign) BOOL	 					matchHasStarted;
@property(nonatomic, assign) matchmakerViewMode_t		matchmakerMode;

+ (MatchDelegate*)sharedMatchDelegate;

@end


static MatchDelegate * sharedMatchDelegateInstance = nil;



// Unnamed-namespace for internal-linkage definitions.
namespace {
	/*
	========================
	Game Center is only supported on iOS 4.1 and later. If we are running on a device
	that doesn't support Game Center, we must disable its functionality.
	The implementation of the check was taken straight form the Apple documentation.
	========================
	*/
	bool HasGameCenterSupport() {
		BOOL localPlayerClassAvailable = (NSClassFromString(@"GKLocalPlayer")) != nil;

		// The device must be running iOS 4.1 or later.
		NSString *reqSysVer = @"4.1";
		NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
		BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);

		return (localPlayerClassAvailable && osVersionSupported);
	}
}


@implementation MatchDelegate

@synthesize matchHandler;
@synthesize gameViewController;
@synthesize currentMatch;
@synthesize matchHasStarted;
@synthesize matchmakerMode;

/*
========================
Singleton implementation. Since we should only ever have one match going on at a time,
the delegate might as well be a singleton. This is Apple's idiomatic example of a Singleton
in Objective-C.
========================
*/
+ (MatchDelegate*)sharedMatchDelegate
{
    if (sharedMatchDelegateInstance == nil) {
        sharedMatchDelegateInstance = [[super allocWithZone:NULL] init];
		sharedMatchDelegateInstance->matchHandler = NULL;
		sharedMatchDelegateInstance->matchHasStarted = NO;
		sharedMatchDelegateInstance->currentMatch = nil;
		
    }
    return sharedMatchDelegateInstance;
}
 
+ (id)allocWithZone:(NSZone *)zone
{
	(void)zone;
    return [[self sharedMatchDelegate] retain];
}
 
- (id)copyWithZone:(NSZone *)zone
{
	(void)zone;
    return self;
}
 
- (id)retain
{
    return self;
}
 
- (NSUInteger)retainCount
{
    return NSUIntegerMax;  //denotes an object that cannot be released
}
 
- (oneway void)release
{
    //do nothing
}
 
- (id)autorelease
{
    return self;
}



/*
========================
Called by the system when Game Center receives a packet from another player. I was
somewhat surprised that this method actually runs on the main thread.
========================
*/
- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromPlayer:(NSString *)playerID {
	(void)match;
	(void)playerID;

	// Sanity-check the size of the data. Discard any packets that won't fit.
	if ( static_cast<int>( [data length] ) > idGameCenter::MAX_PACKET_SIZE_IN_BYTES ) {
		printf( "Received a packet that was too big. Discarding.\n" );
		return;
	}
	
	// Sanity-check the size of the data. Discard any packets with zero length.
	if ( [data length] == 0 ) {
		printf( "Received a packet with zero length. Discarding.\n" );
		return;
	}

	// Give the callback a chance to process the packet.
	self.matchHandler->receivedData( NSStringToStdString( playerID ),
									 [data bytes],
									 static_cast<int>( [data length] ) );
}

/*
========================
Called by the system when a player's state changes (for example, they connect or disconnect).
========================
*/
- (void)match:(GKMatch *)match player:(NSString *)playerID didChangeState:(GKPlayerConnectionState)state {
	switch (state)
    {
        case GKPlayerStateConnected:
			matchHandler->playerConnected( NSStringToStdString( playerID ) );
			
			if (!matchHasStarted && match.expectedPlayerCount == 0)
			{
				matchHasStarted = YES;
				
				std::vector<std::string> players;
				
				for( NSString* currentID in match.playerIDs ) {
					players.push_back( NSStringToStdString( currentID ) );
				}
				matchHandler->allPlayersConnected( players );
			}
			
			break;
        case GKPlayerStateDisconnected:
            matchHandler->playerDisconnected( NSStringToStdString( playerID ) );
			break;
    }
}

/*
========================
Called by the system if the connection with a player fails.
========================
*/
- (void)match:(GKMatch *)match connectionWithPlayerFailed:(NSString *)playerID withError:(NSError *)error {
	(void)match;
	(void)playerID;
	
	DisplayNSErrorMessage( @"GameKit Error", error );
}

/*
========================
Called by the system if the matchmaking interface fails.
========================
*/
- (void)match:(GKMatch *)match didFailWithError:(NSError *)error {
	(void)match;
	
	DisplayNSErrorMessage( @"GameKit Error", error ); 
}


// GKMatchmakerViewController

/*
========================
Called by the system if the user dismisses the matchmaking interface.
========================
*/
- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController
{
	switch ( matchmakerMode ) {
		case MATCH_VIEW_MODAL: {
			[gameViewController dismissModalViewControllerAnimated:YES];
    		break;
		}
		
		case MATCH_VIEW_PUSH_TO_NAVIGATION_CONTROLLER: {
			[viewController.navigationController popViewControllerAnimated:YES];
			break;
		}
	}	
}

/*
========================
Called by the system if there is an error in the matchmaking process.
========================
*/
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFailWithError:(NSError *)error
{
	(void)viewController;
	
	DisplayNSErrorMessage( idLocalization_GetNSString( @"Matchmaking error" ), error );
	
	switch ( matchmakerMode ) {
		case MATCH_VIEW_MODAL: {
			[gameViewController dismissModalViewControllerAnimated:YES];
    		break;
		}
		
		case MATCH_VIEW_PUSH_TO_NAVIGATION_CONTROLLER: {
			[viewController.navigationController popViewControllerAnimated:YES];
			break;
		}
	}
	
}

/*
========================
Called by the system if it finds a match.
========================
*/
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindMatch:(GKMatch *)match
{
	(void)viewController;
	(void)match;
	
	switch ( matchmakerMode ) {
		case MATCH_VIEW_MODAL: {
			[gameViewController dismissModalViewControllerAnimated:YES];
    		break;
		}
		
		case MATCH_VIEW_PUSH_TO_NAVIGATION_CONTROLLER: {
			[viewController.navigationController popViewControllerAnimated:NO];
			break;
		}
	}
	
	NSLog(@"Found a Game Center match!!!");
	
	self.currentMatch = match;
	match.delegate = self;
	
	matchHandler->createdMatch();
	
	if (!matchHasStarted && match.expectedPlayerCount == 0)
    {
		matchHasStarted = NO;
       
		std::vector<std::string> players;
	   
		for( NSString* currentID in match.playerIDs ) {
			players.push_back( NSStringToStdString( currentID ) );
		}
		matchHandler->allPlayersConnected( players );
    }
}

@end


/*
================================================
The private implementation of idGameCenter, defined here in order to insulate user code from
Objective-C land.
================================================
*/
namespace {
	// Cache the result of HasGameCenterSupport. Even if HasGameCenterSupport returns true,
	// it's possible that a Game Kit method may cause a GKErrorNotSupported. If it does, this
	// variable will be set to false in HandleError.
	bool						isAvailable;
	
	// Cache the player identifier. This is the unique key used to distiguish players in
	// Game Kit. All data associated with a player should be tied to this ID, such as
	// achievement and savegame progress. Note that this ID can change if a user task-switches
	// to the Game Center app and logs in with a different account.
	// The string will be empty if no local player is authenticated.
	// The string is UTF8 encoded.
	std::string					playerIdentifier;

	// Store the match handler object. This is how we deal with "callbacks" from the Game Center
	// API.
	idGameCenterMatchHandler *	matchHandler;

	void			HandleError( NSError * error );
	
	void 			ConfigureDelegate( matchmakerViewMode_t mode,
									   id currentViewController,
									   idGameCenterMatchHandler * handler );
	
	void SendPacketToPlayerHelper( std::string destinationPlayer,
								   void *packet,
					   		 	   std::size_t numBytes,
							 	   GKMatchSendDataMode mode );
								   
								   
								   
								   
	/*
	========================
	Handles errors reported by the Game Kit APIs. If it gets GKErrorNotSupported, this function
	sets isAvailable to false.
	========================
	*/
	void HandleError( NSError * error ) {
		if ( error == nil ) {
			return;
		}
		
		switch ( [error code] ) {
			case GKErrorGameUnrecognized: {
				NSLog( @"GameKit error: Game unrecognized." );
				break;
			}
			case GKErrorNotSupported: {
				NSLog( @"GameKit error: Not supported. Disabling GameKit features." );
				isAvailable = false;
				break;
			}
			default: {
				break;
			}
		}
	}


	/*
	========================
	Sets up neede properties of the match delegate. Call this before showing the matchmaking view
	controller. This implementation supports two ways of showing the built-in matchmaker, either
	modally or as a new view controller on a navigation controller's stack. If using a
	navigation controller, the currentViewController parameter can be left nil.
	========================
	*/
	void ConfigureDelegate( matchmakerViewMode_t mode,
							id currentViewController,
							idGameCenterMatchHandler * handler ) {
		
		[MatchDelegate sharedMatchDelegate].matchmakerMode = mode;
		[MatchDelegate sharedMatchDelegate].matchHandler = handler;
		[MatchDelegate sharedMatchDelegate].gameViewController = currentViewController;
		[MatchDelegate sharedMatchDelegate].matchHasStarted = NO;
	}



	/*
	========================
	Sends a packet to a player ID with the data mode specified in the parameter.
	========================
	*/
	void SendPacketToPlayerHelper( std::string destinationPlayer,
								   void *packet,
								   std::size_t numBytes,
								   GKMatchSendDataMode mode ) {

		if ( idGameCenter::IsAvailable() == false || idGameCenter::IsLocalPlayerAuthenticated() == false ) {
			return;
		}
		
		if ( idGameCenter::IsInMatch() == false ) {
			return;
		}
		
		
		GKMatch * theMatch = [MatchDelegate sharedMatchDelegate].currentMatch;


		NSError * theError = nil;
		
		NSData *nsPacket = [ NSData dataWithBytes:packet length:static_cast<NSUInteger>( numBytes ) ];
		NSArray *playerArray = [ NSArray arrayWithObject:StdStringToNSString( destinationPlayer ) ];
		
		[theMatch sendData:nsPacket toPlayers:playerArray withDataMode:mode error:&theError];
		
		if ( theError != nil )
		{
			DisplayNSErrorMessage( @"GameKit Error", theError );
		}
	}
}

namespace idGameCenter {
/*
========================
impl constructor. Sets the inital value of isAvailable based on the OS checks in
HasGameCenterSupport. Note that isAvailable might be set to false later if a GameKit API
returns a GKErrorNotSupported.
========================
*/
void Initialize() {
	isAvailable = HasGameCenterSupport();
	matchHandler = NULL;
}


/*
========================
Returns true if the runtime device supports Game Center. If it doesn't, we may need to
disable UI elements, etc.
========================
*/
bool IsAvailable() {
	return isAvailable;
}

/*
========================
Returns true if there is a local player authenticated.
========================
*/
bool IsLocalPlayerAuthenticated() {
	return !playerIdentifier.empty();
}

/*
========================
Attempts to authenticate the local player. Apple recommends that this be done as soon as
possible after the game starts up and is able to display a UI (probably in
applicationDidFinishLaunching).
========================
*/
void AuthenticateLocalPlayer( id currentViewController, idGameCenterMatchHandler * handler ) {
	// Early exit if Game Center is not supported.
	if ( IsAvailable() == false ) {
		return;
	}

	GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
	[localPlayer authenticateWithCompletionHandler:^(NSError * error) {
		if ( localPlayer.isAuthenticated )
		{
			// Perform additional tasks for the authenticated player.
			GKLocalPlayer * lp = [GKLocalPlayer localPlayer];
			 
			// Cache the player identifier string.
			std::string newPlayerIdentifier = NSStringToStdString( [lp playerID] );
			
			// If the player changed while the app was in the background, the playerIDs will
			// be different. If they are, we have to switch any game state to reflect the
			// new player.
			if ( newPlayerIdentifier != playerIdentifier ) {
				// TODO: Switch game state to reflect the newly logged in player.
			}
			 
			playerIdentifier = newPlayerIdentifier;
			
			// Set up the invitation handler. This code handles the cases where a friend
			// is invited to the game from the matchmaking UI or the Game Center application.
			[GKMatchmaker sharedMatchmaker].inviteHandler = ^(GKInvite *acceptedInvite, NSArray *playersToInvite) {
				// Disconnect from any previous game.
				idGameCenter::DisconnectFromMatch();
				
				ConfigureDelegate( MATCH_VIEW_MODAL, currentViewController, handler );
				
				if (acceptedInvite)
				{
					GKMatchmakerViewController *mmvc = [[[GKMatchmakerViewController alloc] initWithInvite:acceptedInvite] autorelease];
					mmvc.matchmakerDelegate = [MatchDelegate sharedMatchDelegate];
					[currentViewController presentModalViewController:mmvc animated:YES];
				}
				else if (playersToInvite)
				{
					GKMatchRequest *request = [[[GKMatchRequest alloc] init] autorelease];
					request.minPlayers = 2;
					request.maxPlayers = 4;
					request.playersToInvite = playersToInvite;

					GKMatchmakerViewController *mmvc = [[[GKMatchmakerViewController alloc] initWithMatchRequest:request] autorelease];
					mmvc.matchmakerDelegate = [MatchDelegate sharedMatchDelegate];
					[currentViewController presentModalViewController:mmvc animated:YES];
				}
			};			 
         } else {
		 	// No new local player is logged in. If no player was logged in before, we shouldn't
			// have to do anything here.
			// But if a player was previously logged in, we need to update the game state, for
			// example, clear achievement progress or load different saved games.
			if ( !playerIdentifier.empty() ) {
				// TODO: Clean up state related to the old playerIdentifier.
			}
			
			// Empty the string to indicate no one is logged in.
			playerIdentifier.clear();
		 }
		 
		 HandleError( error );
	}];
}

/*
========================
This function must be called when the app is moving to the background (such as from
applicationWillResignActive). It will de-authenticate the local player, because the user
might sign out while our app is in the background.

According to the Apple documentation, we need to de-authenticate the local player when the app
moves to the background. The implication of this is that for lockstep games like DOOM, we
can't continue to update the game while our app is in the background. In order to not cause
problems for other players, we just disconnect from a match (if any) right here.

TODO: When we support achievements and/or leaderboards, serialize out any data that hasn't
been successfully sent to Game Center yet. We'll need to do this because the OS might kill
our app while it's in the background.
========================
*/
void HandleMoveToBackground() {
	if ( IsInMatch() ) {
		ShowSystemAlert( "Connection lost", "Lost connection to server" );
	}
	
	DisconnectFromMatch();
	playerIdentifier.empty();
}



/*
========================
Presents Game Center's built-in matchmaking view controller as a model view controller on top
of currentViewController.
MAKE SURE the handler object survives the duration of the app!
========================
*/
void PresentMatchmaker( id currentViewController, matchParms_t parms, idGameCenterMatchHandler * handler ) {
	// Early exit if Game Center is not active.
	if ( IsAvailable() == false || IsLocalPlayerAuthenticated() == false ) {
		return;
	}
	
	ConfigureDelegate( MATCH_VIEW_MODAL, currentViewController, handler );
	
	
	GKMatchRequest *request = [[[GKMatchRequest alloc] init] autorelease];
    request.minPlayers = parms.minimumPlayers;
    request.maxPlayers = parms.maximumPlayers;
	request.playerGroup = parms.automatchGroup;
 
    GKMatchmakerViewController *mmvc = [[[GKMatchmakerViewController alloc] initWithMatchRequest:request] autorelease];
    mmvc.matchmakerDelegate = [MatchDelegate sharedMatchDelegate];
 
    [(UIViewController*)currentViewController presentModalViewController:mmvc animated:YES];
}

/*
========================
Presents Game Center's built-in matchmaking view controller as a new controller on top
of the navigationController's stack.
MAKE SURE the handler object survives the duration of the app!
========================
*/
void PushMatchmakerToNavigationController( id navigationController,
										   matchParms_t parms,
										   idGameCenterMatchHandler * handler ) {
	// Early exit if Game Center is not active.
	if ( IsAvailable() == false || IsLocalPlayerAuthenticated() == false ) {
		return;
	}
	
	ConfigureDelegate( MATCH_VIEW_PUSH_TO_NAVIGATION_CONTROLLER, nil, handler );
	
	GKMatchRequest *request = [[[GKMatchRequest alloc] init] autorelease];
    request.minPlayers = parms.minimumPlayers;
    request.maxPlayers = parms.maximumPlayers;
	request.playerGroup = parms.automatchGroup;
 
    GKMatchmakerViewController *mmvc = [[[GKMatchmakerViewController alloc] initWithMatchRequest:request] autorelease];
    mmvc.matchmakerDelegate = [MatchDelegate sharedMatchDelegate];
 
    [navigationController pushViewController:mmvc animated:YES];
}

/*
========================
Returns true if the player is currently connected to a Game Center match, false if not.
========================
*/
bool IsInMatch() {
	return [MatchDelegate sharedMatchDelegate].currentMatch != nil;
}

/*
========================
Sends an unreliable packet to a single player.
========================
*/
void SendPacketToPlayerUnreliable( std::string destinationPlayer,
									   			 void *packet,
									   			 std::size_t numBytes ) {
	SendPacketToPlayerHelper( destinationPlayer, packet, numBytes, GKMatchSendDataUnreliable );	
}


/*
========================
Sends a reliable packet to a single player.
========================
*/
void SendPacketToPlayerReliable( std::string destinationPlayer,
											   void *packet,
											   std::size_t numBytes ) {
	SendPacketToPlayerHelper( destinationPlayer, packet, numBytes, GKMatchSendDataReliable );	
}



/*
========================
Sends a packet to all other players in the current match. Just returns if Game Center is not
available or if the local player is not in a match.
========================
*/
void BroadcastPacketReliable( void * packet, int numBytes ) {
	if ( IsAvailable() == false || IsLocalPlayerAuthenticated() == false ) {
		return;
	}
	
	if ( IsInMatch() == false ) {
		return;
	}

	
	GKMatch * theMatch = [MatchDelegate sharedMatchDelegate].currentMatch;


	NSError * theError = nil;
	
	NSData *nsPacket = [NSData dataWithBytes:packet length:static_cast<NSUInteger>(numBytes)];
	
	[theMatch sendDataToAllPlayers:nsPacket withDataMode:GKMatchSendDataReliable error:&theError];
	
	if ( theError != nil )
    {
        DisplayNSErrorMessage( @"GameKit Error", theError );
    }
}

/*
========================
If this player is currently connected to a match. this will disconnect them.
========================
*/
void DisconnectFromMatch() {
	if ( IsInMatch() ) {
		[[MatchDelegate sharedMatchDelegate].currentMatch disconnect];
		
		// currentMatch is a retained property, so this will release it.
		[MatchDelegate sharedMatchDelegate].currentMatch = nil;
	}
}

}


