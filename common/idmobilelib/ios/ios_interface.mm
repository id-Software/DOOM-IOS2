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

#include "ios_interface.h"
#import "objectivec_utilities.h"
#import "LocalizationObjectiveC.h"

#import <UIKit/UIAlertView.h>

/*
 =======================
 Shows the blue system alert box with localized text.
 =======================
 */
void ShowSystemAlert( const std::string & title, const std::string & message ) {
	NSString * nsTitle = idLocalization_GetNSString( StdStringToNSString( title ) );
	NSString * nsMessage = idLocalization_GetNSString( StdStringToNSString( message ) );
	NSString * nsCancelButton = idLocalization_GetNSString( @"#OK" );
	
	UIAlertView * alert = [[UIAlertView alloc] initWithTitle:nsTitle message:nsMessage delegate:nil cancelButtonTitle:nsCancelButton otherButtonTitles:nil];

	[alert show];
	[alert release];
}

