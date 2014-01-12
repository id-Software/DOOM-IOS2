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

#include "objectivec_utilities.h"
#include "LocalizationObjectiveC.h"

#import <Foundation/NSString.h>
#import <UIKit/UIAlertView.h>
#import <Foundation/NSError.h>

/*
========================
Copies an NSString object to a C++ string encoded in UTF8.
========================
*/
std::string NSStringToStdString( NSString * toConvert ) {
	const char * cString = [toConvert cStringUsingEncoding:NSUTF8StringEncoding];
	return std::string( cString );
}

/*
========================
Copies a C++ string encoded in UTF8 to an NSString object.
========================
*/
NSString * StdStringToNSString( const std::string & toConvert ) {
	return [NSString stringWithCString:toConvert.c_str() encoding:NSUTF8StringEncoding];
}

/*
========================
Disaplys a system alert with information about the given error.
========================
*/
void DisplayNSErrorMessage( NSString * title, NSError * error ) {
	NSString *messageString = [error localizedDescription];
    NSString *reasonString = [error localizedFailureReason];
	
	if ( reasonString != nil ) {
		messageString = [NSString stringWithFormat:@"%@. %@", messageString, reasonString];
	} else {
		messageString = [NSString stringWithFormat:@"%@", messageString];
	}
 
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:idLocalization_GetNSString( title )
        message:messageString delegate:nil
        cancelButtonTitle:idLocalization_GetNSString(@"OK") otherButtonTitles:nil];
    [alertView show];
    [alertView release];
}
