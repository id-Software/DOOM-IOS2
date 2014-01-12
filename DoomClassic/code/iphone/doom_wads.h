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

#ifndef DoomII_doom2_wads_h
#define DoomII_doom2_wads_h


#ifdef __cplusplus
extern "C" {
#endif

const static int TOTAL_HOE_MISSIONS      =  32;
const static int TOTAL_PLUT_MISSIONS     =  32;
const static int TOTAL_TNT_MISSIONS      =  32;
const static int TOTAL_MAST_MISSIONS     =  21;
const static int TOTAL_NOREST_MISSIONS   =  9;
const static int TOTAL_DOOM_MISSIONS     =  32;

const int MASTERLEVELS_MAPNUM[21] = {
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    3,
    5,
    7,
    7,
    7,
    8,
    9,
    25,
    31,
    32
};
    
//---------------------------------------
// iPhone mission pack management
//---------------------------------------
typedef enum {
	MISSION_HELL_ON_EARTH,
	MISSION_PLUTONIA,
	MISSION_TNT_EVILUTION,
	MISSION_MASTER_LEVELS,
	MISSION_NO_REST_FOR_THE_LIVING,
	MISSION_ULTIMATE_DOOM,
	
	// None must be the last entry in this enum for the menu to work correctly.
	MISSION_NONE
} iphoneMissionPack_t;

extern iphoneMissionPack_t iphoneMissionPack;
extern int                 iphoneMasterLevel;


void iphoneFindIWADFile( iphoneMissionPack_t mission, char * returnFileName );
void iphoneFindPWADFile( iphoneMissionPack_t mission, char * returnFileName );

int GetNumberOfMapsInExpansion( iphoneMissionPack_t expansion );

#ifdef __cplusplus
}
#endif


#endif
