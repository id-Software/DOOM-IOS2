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
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AnimatedImage.h"


@implementation idAnimatedImage


/*
 ========================
 SetupAnimation
 ========================
 */
- (void) SetupAnimation:( NSString * )animationBaseName
					   :( float )animationDuration
					   :( int  )animationRepeat {
 
    // Create an Array to store our images in.
    const static int MAX_NUM_ANIMFRAMES = 20;
    NSMutableArray * imageArray = [ [ NSMutableArray alloc ] initWithCapacity:MAX_NUM_ANIMFRAMES ];
    
    for( int index = 1; index < MAX_NUM_ANIMFRAMES; index++ ) {
        NSString * imageName = [ [ NSString alloc ] initWithFormat:@"%@_%d.png", animationBaseName, index ];
        
        // Try and Load the Image.
        UIImage * imageCheck = [UIImage imageNamed: imageName ];
        
        // are we good?
        if( imageCheck != nil ) {
         
            // add it to the array of Images.
            [ imageArray addObject:imageCheck ];
            
        } else  {
            break;
        }
    }
    // Set the Animation Data.
    [ self setAnimationImages: imageArray ];
    [ self setAnimationDuration: animationDuration];
    [ self setAnimationRepeatCount: animationRepeat ];
}





@end
