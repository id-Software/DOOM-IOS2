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

#include <cstddef>

#include "doom_wads.h"
#include "stdio.h"
#include "iphone_doom.h"
#include "prboom/i_system.h"

iphoneMissionPack_t iphoneMissionPack = MISSION_NONE;
int                 iphoneMasterLevel = 1;


/*
 ==================
 iphoneFindIWADFile
 
 Returns the IWAD to load for the selected mission pack. String MUST be freed by caller :(
 ==================
 */

static const char * MasterLevels_WADS[] = {
    "ATTACK.WAD", 
    "CANYON.WAD" ,
    "CATWALK.WAD" ,
    "COMBINE.WAD" ,
    "FISTULA.WAD" ,
    "GARRISON.WAD",
    "MANOR.WAD" ,
    "PARADOX.WAD", 
    "SUBSPACE.WAD", 
    "SUBTERRA.WAD" ,
    "TTRAP.WAD" ,
    "VIRGIL.WAD" ,
    "MINOS.WAD" ,
    "BLOODSEA.WAD", 
    "MEPHISTO.WAD", 
    "NESSUS.WAD" ,
    "GERYON.WAD" ,
    "VESPERAS.WAD", 
    "BLACKTWR.WAD" ,
    "TEETH.WAD",   
    "TEETH.WAD",
};

void iphoneFindIWADFile( iphoneMissionPack_t mission, char * returnFileName ) {

	switch ( mission ) {
		case MISSION_HELL_ON_EARTH:
			sprintf( returnFileName,  "doom2.wad" );
			return;
		
		case MISSION_PLUTONIA:
			sprintf( returnFileName,   "plutonia.wad" );
			return;
			
		case MISSION_TNT_EVILUTION:
			sprintf( returnFileName,   "tnt.wad" );
			return;
			
		case MISSION_NO_REST_FOR_THE_LIVING:
			sprintf( returnFileName,   "doom2.wad" );
			return;
            
		case MISSION_MASTER_LEVELS:
            sprintf( returnFileName,   "doom2.wad" );
            return;
			
		default:
			sprintf( returnFileName, "doom2.wad" );;
	}
}

/*
 ==================
 iphoneFindPWADFile
 
 Returns the name of the pwad that needs to be loaded for the user's selected mission.
 ==================
 */
void iphoneFindPWADFile( iphoneMissionPack_t mission, char * returnFileName ) {

	switch ( mission ) {
		case MISSION_NO_REST_FOR_THE_LIVING: {
			sprintf( returnFileName, "nerve.wad" );
            return;
			break;
		}
		case MISSION_MASTER_LEVELS: {
            sprintf( returnFileName, "%s", MasterLevels_WADS[ iphoneMasterLevel ] );
            return;
			break;
        }
		default:
			break;
	}
	
	returnFileName[0] = '\0';
}

/*
==================
GetNumberOfMapsInExpansion

Returns the total number of maps contained in an expansion dataset.
==================
*/
int GetNumberOfMapsInExpansion( iphoneMissionPack_t expansion ) {
	switch( expansion ) {
		case MISSION_HELL_ON_EARTH: {
			return TOTAL_HOE_MISSIONS;
		}
		
		case MISSION_ULTIMATE_DOOM: {
			return TOTAL_PLUT_MISSIONS;
		}
		
		case MISSION_NONE: {
			return 0;
		}
		
		case MISSION_MASTER_LEVELS: {
			return TOTAL_MAST_MISSIONS;
		}
		
		case MISSION_TNT_EVILUTION: {
			return TOTAL_TNT_MISSIONS;
		}
		
		case MISSION_NO_REST_FOR_THE_LIVING: {
			return TOTAL_NOREST_MISSIONS;
		}
		
		case MISSION_PLUTONIA: {
			return TOTAL_PLUT_MISSIONS;
		}
	};
	
	return 0;
}


/*
 =======================
 StartupWithIWADandPWAD
 =======================
 */
void StartupWithCorrectWads( int mission ) {
	// Look for the iwad file corresponding to the current mission.
	char iwad[ 1024 ]; 
	char expansion[ 1024 ];
	iphoneFindIWADFile( static_cast<iphoneMissionPack_t>(mission), expansion );
	I_FindFile( expansion, ".wad", iwad );
	
	// Look for the pwad corresponding to the current mission. Will be NULL if we don't
	// need a pwad for the mission.
	char mission_pwad[ 1024 ];
	iphoneFindPWADFile( static_cast<iphoneMissionPack_t>(mission), mission_pwad );
	
	char full_pwad[ 1024 ];
	
	if ( mission_pwad[0] != '\0' ) {
		I_FindFile( mission_pwad, ".wad", full_pwad );
		iphoneDoomStartup( iwad, full_pwad );
	}	else {
		iphoneDoomStartup( iwad, NULL );
	}
}
