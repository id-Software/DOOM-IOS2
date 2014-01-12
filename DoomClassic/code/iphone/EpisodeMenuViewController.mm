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

#import "EpisodeMenuViewController.h"
#include "doomiphone.h"
#include "iphone_delegate.h"
#import "MissionMenuViewController.h"
/*
 ================================================================================================
 EpisodeMenuViewController
 
 ================================================================================================
 */
@implementation Doom_EpisodeMenuViewController

/*
 ========================
 Doom_EpisodeMenuViewController::initWithNibName
 ========================
 */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
            
        episodeSelection = -1;
        [ nextButton setEnabled: NO ];
        [ nextLabel setEnabled: NO ];
        
    }
    return self;
}

/*
 ========================
 Doom_EpisodeMenuViewController::didReceiveMemoryWarning
 ========================
 */
- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

/*
 ========================
 Doom_EpisodeMenuViewController::viewDidLoad
 ========================
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	
	[ nextButton setEnabled: NO ];
	[ nextLabel setEnabled: NO ];
}

/*
 ========================
 Doom_EpisodeMenuViewController::viewDidUnload
 ========================
 */
- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

/*
 ========================
 Doom_EpisodeMenuViewController::BackToMain
 ========================
 */
- (IBAction) BackToMain {
    
    [self.navigationController popViewControllerAnimated:NO];
    Sound_StartLocalSound( "iphone/controller_down_01_SILENCE.wav" );
}

/*
 ========================
 Doom_EpisodeMenuViewController::NextToMissions
 ========================
 */
- (IBAction) NextToMissions {
    
    Doom_MissionMenuViewController *vc = nil;
	
	
	if ( IS_IPHONE_5 ) {
		vc = [[Doom_MissionMenuViewController alloc] initWithNibName:@"MissionMenuViewi5" bundle:nil];
	} else {
		vc = [[Doom_MissionMenuViewController alloc] initWithNibName:@"MissionMenuView" bundle:nil];
	}
	
	
    [self.navigationController pushViewController:vc animated:NO];
    [vc setEpisode:episodeSelection ];
    [vc release];
    
    Sound_StartLocalSound( "iphone/controller_down_01_SILENCE.wav" );
}

/*
 ========================
 Doom_EpisodeMenuViewController::SelectEpisode1
 ========================
 */
- (IBAction) SelectEpisode1 {
    
    [ nextButton setEnabled: YES ];
    [ nextLabel setEnabled: YES ];
    episodeSelection = 0;
    [ epi1Button setEnabled: NO ];
    [ epi2Button setEnabled: YES ];
    [ epi3Button setEnabled: YES ];
    [ epi4Button setEnabled: YES ];
}

/*
 ========================
 Doom_EpisodeMenuViewController::SelectEpisode2
 ========================
 */
- (IBAction) SelectEpisode2 {
    [ nextButton setEnabled: YES ];
    [ nextLabel setEnabled: YES ];
    episodeSelection = 1;
    [ epi1Button setEnabled: YES ];
    [ epi2Button setEnabled: NO ];
    [ epi3Button setEnabled: YES ];
    [ epi4Button setEnabled: YES ];
}

/*
 ========================
 Doom_EpisodeMenuViewController::SelectEpisode3
 ========================
 */
- (IBAction) SelectEpisode3 {
    [ nextButton setEnabled: YES ];
    [ nextLabel setEnabled: YES ];
    episodeSelection = 2;
    [ epi1Button setEnabled: YES ];
    [ epi2Button setEnabled: YES ];
    [ epi3Button setEnabled: NO ];
    [ epi4Button setEnabled: YES ];
}

/*
 ========================
 Doom_EpisodeMenuViewController::SelectEpisode4
 ========================
 */
- (IBAction) SelectEpisode4 {
    [ nextButton setEnabled: YES ];
    [ nextLabel setEnabled: YES ];
    episodeSelection = 3;
    [ epi1Button setEnabled: YES ];
    [ epi2Button setEnabled: YES ];
    [ epi3Button setEnabled: YES ];
    [ epi4Button setEnabled: NO ];
}

@end
