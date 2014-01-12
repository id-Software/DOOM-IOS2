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

Interface to the device's In-App Purchase system.


This interface was designed to be dropped into any game that needs support for in-app purchases,
that is, there is nothing game-specific about this interface or its implementation.

It is essentially a singleton implemented in the idInAppPurchase namespace. The singleton must
be initialized at application launch (via Initialize()) and shut down at application exit (via
Shutdown()).

There are functions to request information about products for sale within the app, check whether
a particular product has been purchased, and get the localized price for a product, suitable
for displaying in the user interface.

Generally an app should call RequestInformation() at startup (but after Initialize()) and pass
in all the product identifiers that the app offers for sale. The request will run in the
background so that the interface will remain responsive. Once the requests have been returned,
the application can get the price information and actually initiate purchases of products.

================================================================================================
*/


#ifndef INAPPSTORE_H
#define INAPPSTORE_H

#include <vector>
#include <string>
#include <tr1/functional>

namespace idInAppStore {
	
	void Initialize( const std::vector<std::string> & productIdentifiers );
	void Shutdown();
	
	bool IsEnabled();
	
	void ShowDisabledAlert( std::string title,
							std::string description,
							std::string okButton );
	
	bool HasPurchased( const char * const productIdentifier );
	bool CanPurchase( const char * const productIdentifier );
	bool IsWaitingForInformation( const char * const productIdentifier );
	bool IsWaitingForPurchase( const char * const productIdentifier );
	
	std::string GetLocalizedPrice( const char * const productIdentifier );
	
	void StartPurchase( const char * const productIdentifier );
	
	/*
	========================
	The application can register callbacks to be notified of events that occur relating to
	the in-app store. The first parameter to the callback function is the product identifier
	string for the product that was affected, the second is the status of that product.
	========================
	*/
	enum productStatus_t {
		PRODUCT_STATUS_TRANSACTION_FAILED,
		PRODUCT_STATUS_RECEIVED_INFORMATION,
		PRODUCT_STATUS_PURCHASED
	};
	
	typedef std::tr1::function< void ( const char * const, productStatus_t ) > callback_t;
	
	void SetCallback( callback_t callback );
	void ClearCallback();
}


#endif
