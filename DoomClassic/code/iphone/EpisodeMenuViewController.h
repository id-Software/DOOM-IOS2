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

#import <UIKit/UIKit.h>
#import "ios/LabelButton.h"

/*
 ================================================================================================
 EpisodeMenuViewController
 
 ================================================================================================
 */
@interface Doom_EpisodeMenuViewController : UIViewController {
    
    IBOutlet idLabelButton *     epi1Button;
    IBOutlet idLabelButton *     epi2Button;
    IBOutlet idLabelButton *     epi3Button;
    IBOutlet idLabelButton *     epi4Button;
    
    int                         episodeSelection;
    IBOutlet idLabelButton *    nextButton;
    IBOutlet idLabel *          nextLabel;
    
}

- (IBAction) BackToMain;
- (IBAction) NextToMissions;


- (IBAction) SelectEpisode1;
- (IBAction) SelectEpisode2;
- (IBAction) SelectEpisode3;
- (IBAction) SelectEpisode4;

@end
