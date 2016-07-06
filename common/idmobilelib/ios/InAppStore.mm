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

Implentation of the In-App Purchase system for iOS devices.


This implementation conforms to the interface in InAppStore.h. It uses the NSUserDefaults object
provided by the system to keep track of the state of the products that the application offers.

================================================================================================
*/


#include "InAppStore.h"

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#include <map>
#include <utility>
#include <vector>
#include <algorithm>

// For ease of development, leave this defined to skip in-app purchase prompts.
//#define TEST_ALL_PRODUCTS_PURCHASED

@interface MyStoreObserver : NSObject<SKProductsRequestDelegate, SKPaymentTransactionObserver> {

}

// SKProductsRequestDelegate methods
- (void)productsRequest: (SKProductsRequest *)request didReceiveResponse: (SKProductsResponse *)response;

// SKPaymentTransactionObserver methods
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions;

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error;
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue;

// MyStoreObserver methods
- (void)completeTransaction:(SKPaymentTransaction *)transaction;
- (void)failedTransaction:(SKPaymentTransaction *)transaction;
- (void)restoreTransaction:(SKPaymentTransaction *)transaction;
- (void)finalizeTransaction:(SKPaymentTransaction *)transaction;

@end

// Unnamed-namespace for stuff that's "private" to this file (internal linkage).
namespace {
	// The single instance of the store observer. This is created in Initialize and released
	// in Shutdown.
	MyStoreObserver * observer;
	
	// The callback to invoke when an interesting event occurs.
	idInAppStore::callback_t callbackObject;
	
	/*
    ================================================
	Each product identifier has an associated state to keep track of the progress of
	in-app purchases. These states are stored in the NSUserDefaults for the corresponding
	product identifier. These states are not in an enum because the the NSUserDefaults store
	NSIntegers, and we can't define the type of an enum in C++03.
    ================================================
    */
	typedef NSInteger productState_t;
	
	// This is the state of a product if it not found in the user's defaults.
	const productState_t PRODUCT_NOT_FOUND = 0;
		
	// Information from this product has been requested, but has not been received yet.
	const productState_t PRODUCT_WAIT_FOR_INFORMATION = 1;
		
	// Information for this product is available, but a purchase has not been initiated.
	const productState_t PRODUCT_HAS_INFORMATION = 2;
		
	// A purchase was initiated, and the application is waiting for the App Store to
	// process the purchase.
	const productState_t PRODUCT_WAIT_FOR_PURCHASE = 3;
	
	// The app store has fully processed the purchase and the product is available for the
	// user/
	const productState_t PRODUCT_PURCHASED = 4;
	
	
	void RequestInformation( const std::vector<std::string> & productIdentifiers );
	
	/*
    ================================================
    Store product information in a C++ friendly way.
    ================================================
    */
	struct productInformation_t {
		std::string identifier;
		std::string localizedPrice;
		
		productInformation_t( const std::string & identifier_, const std::string & localizedPrice_ )
			: identifier( identifier_ )
			, localizedPrice( localizedPrice_ )
		{
		}
	};
	
	// Cache the product information that has been received from the App Store.
	typedef std::map<std::string, productInformation_t> productMap_t;
	productMap_t productCache;
	
	/*
    ========================
	GetProductState
	
    Queries the NSUserDefaults for the state of the product corresponding to the
	productIdentifier.
    ========================
    */
	productState_t GetProductState( const char * const productIdentifier ) {
#if defined( TEST_ALL_PRODUCTS_PURCHASED )
		return PRODUCT_PURCHASED;
#endif
	
		// Convert the C string to an NSString for use with NSUserDefaults.
		NSString *productKey = [NSString stringWithCString:productIdentifier
													encoding:NSUTF8StringEncoding];
		
		// Purchase records are stored in the standardUserDefaults, with a key equal to the
		// product identifier.
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSInteger productState = [defaults integerForKey:productKey];
		
		return productState;
	}
	
	/*
    ========================
	SetProductState
	
    Sets the NSUserDefaults value corresponding to product identifier to the given state.
    ========================
    */
	void SetProductState( NSString * productIdentifier, productState_t state ) {
		// Purchase records are stored in the standardUserDefaults, with a key equal to the
		// product identifier.
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setInteger:state forKey:productIdentifier];
	}
	
	/*
    ========================
	SetProductState
	
    Sets the NSUserDefaults value corresponding to product identifier to the given state.
    ========================
    */
	void SetProductState( const char * const productIdentifier, productState_t state ) {
		// Convert the C string to an NSString for use with NSUserDefaults.
		NSString *productKey = [NSString stringWithCString:productIdentifier
													encoding:NSUTF8StringEncoding];
		
		SetProductState( productKey, state );
	}
	
	/*
	========================
	RequestInformation

	Queries the App Store for information about the all the identifiers in the vector.
	When the App Store responds, calls the callback. The product identifiers are UTF8 encoded.
	
	If in-app purchases are disabled, this function does nothing. The application may want to
	show an alert in this case. The application can call IsEnabled() to check for this.
	========================
	*/
	void RequestInformation( const std::vector<std::string> & productIdentifiers ) {
		// Early exit if the system hasn't been initialized.
		if ( observer == nil ) {
			printf( "In-App Purchase system not initialized. Can't purchase anything!\n" );
			return;
		}
		
		// Early exit if in-app purchases are disabled.
		if ( [SKPaymentQueue canMakePayments] == FALSE ) {
			printf( "In-App Purchases are disabled for this device. Can't purchase anything!\n" );
			return;
		}
		
		// This will be the set of product identifiers to request from the App Store.
		NSMutableSet * identifiersToRequest = [NSMutableSet setWithCapacity: productIdentifiers.size()];
		
#ifndef NDEBUG		
		// For debugging purposes, set this flag to 'true' and all in-app purchase products
		// will be reset to the unpurchased state.
		bool resetPurchases = false;
		
		if ( resetPurchases ) {
			for( std::vector<std::string>::const_iterator i = productIdentifiers.begin(); i != productIdentifiers.end(); ++i ) {
				SetProductState( i->c_str(), PRODUCT_NOT_FOUND );
			}
		}
#endif		
		
		// Check the NSUserDefaults for each identifier requested, to get the state of
		// the product.
		for( std::vector<std::string>::const_iterator i = productIdentifiers.begin(); i != productIdentifiers.end(); ++i ) {
			// If the user has not purchased this product, we need to request information about
			// it from the App Store.
			productState_t productState = GetProductState( i->c_str() );
			if ( productState != PRODUCT_PURCHASED ) {
				
				SetProductState( i->c_str(), PRODUCT_WAIT_FOR_INFORMATION );
				
				NSString * nsIdentifier = [NSString stringWithCString:i->c_str()
											   encoding:NSUTF8StringEncoding];
											   
				[identifiersToRequest addObject:nsIdentifier];
			}
		}
		
		// Now we know which identifiers to request from the store, start the request object.
		if ( [identifiersToRequest count] > 0 ) {
			SKProductsRequest *request= [[SKProductsRequest alloc]
											initWithProductIdentifiers:identifiersToRequest ];
			
			request.delegate = observer;
			[request start];
		}
	}
}

namespace idInAppStore {
	
	/*
	========================
	Initialize

	Creates the StoreKit observer object and registers it with the payment queue. The
	application must provide all the product IDs it has available for sale to this function,
	so that it can request information from the app store.
	========================
	*/
	void Initialize( const std::vector<std::string> & productIdentifiers ) {
		if ( !observer ) {
			observer = [[MyStoreObserver alloc] init];
			
			// Add the observer here in case purchase requests were interrupted last time.
			[[SKPaymentQueue defaultQueue] addTransactionObserver:observer];
		}
		
		RequestInformation( productIdentifiers );
	}
	
	/*
	========================
	Shutdown

	Frees the StoreKit observer object.
	========================
	*/
	void Shutdown() {
		[observer release];
		observer = nil;
	}
	
	/*
	========================
	IsEnabled

	Returns true if in-app purchases are enabled, false if they are not.
	========================
	*/
	bool IsEnabled() {
		return ( [SKPaymentQueue canMakePayments] )? true: false;
	}
	
	/*
	========================
	StartPurchase

	Begins the purchase process with the App Store. The product id must have been
	previously requested through RequestInformation. This will launch the OS-controlled
	confirmation prompt after a moment, and it might take a while to actually complete the
	purchase.
	========================
	*/
	void StartPurchase( SKProduct * product ) {
		if ( ![SKPaymentQueue canMakePayments] ) {
			return;
		}
		
        const char * productIdentifier = [product.productIdentifier UTF8String];
        
		if ( !CanPurchase( productIdentifier ) ) {
			return;
		}
		
		SetProductState( product.productIdentifier, PRODUCT_WAIT_FOR_PURCHASE );

        SKPayment * payment = [SKPayment paymentWithProduct:product];
		[[SKPaymentQueue defaultQueue] addPayment:payment];
	}
	
	/*
	========================
	ShowDisabledAlert
	
	If and only if in-app purchases are disabled, shows an alert notifying the user of this fact
	and reminds him or her that he or she can enable in-app purchases in settings.
	
	If in-app purchasees are enabled, this function does nothing.
	
	The string parameters must be encoded in UTF8.
	========================
	*/
	void ShowDisabledAlert( std::string title,
							std::string description,
							std::string okButton ) {
		if ( ![SKPaymentQueue canMakePayments] ) {
			// User has disabled In-App purchases in settings. Kindly remind him that he can
			// enable purchases again.
			
			if ( title.empty() ) {
				title = "In-App Purchases are disabled";
			}
			
			if ( description.empty() ) {
				description = "You can enable In-App purchases in your device's settings.";
			}
			
			if ( okButton.empty() ) {
				title = "OK";
			}
			
			NSString * nsTitle = [NSString stringWithCString:title.c_str() encoding:NSUTF8StringEncoding];
			NSString * nsDescription = [NSString stringWithCString:description.c_str() encoding:NSUTF8StringEncoding];
			NSString * nsOkButton = [NSString stringWithCString:okButton.c_str() encoding:NSUTF8StringEncoding];
			
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nsTitle
															message:nsDescription
														   delegate:nil
												  cancelButtonTitle:nsOkButton
												  otherButtonTitles:nil];
			
			// Make sure the alert shows up on the main thread.
			[alert show];
			[alert release];
		}
	}
		
	/*
	========================
	HasPurchased
	 
	Queries the standard NSUserDefaults object for the state of the product with the given
	identifier. If the state is PRODUCT_PURCHASED, the user has purchased the product.
	If the state is anything else, the user has not purchased the product.
	========================
	*/
	bool HasPurchased( const char * const productIdentifier ) {
		const productState_t state = GetProductState( productIdentifier );
		const bool stateIsPurchased = (state == PRODUCT_PURCHASED);
		return ( stateIsPurchased );
	}

	/*
	========================
	CanPurchase
	 
	Returns true if it is safe for the application to start a purchase, false if the application
	should not start a purchase at this time.
	========================
	*/
	bool CanPurchase( const char * const productIdentifier ) {
		const productState_t state = GetProductState( productIdentifier );
		const bool stateHasInformaion = ( state == PRODUCT_HAS_INFORMATION );
		return ( stateHasInformaion );
	}
	
	
	/*
	========================
	IsWaitingForInformation
	 
	Queries the standard NSUserDefaults object for the state of the product with the given
	identifier. If the application is still waiting for the App Store to return information,
	this function returns true. If the application has information, this function returns false.
	========================
	*/
	bool IsWaitingForInformation( const char * const productIdentifier ) {
		return ( GetProductState( productIdentifier ) == PRODUCT_WAIT_FOR_INFORMATION );
	}

	/*
	========================
	IsWaitingForPurchase
	 
	Queries the standard NSUserDefaults object for the state of the product with the given
	identifier. If the application is still waiting for the App Store to purchase the item,
	this function returns true. If the application is not waiting on the app store, returns false.
	========================
	*/
	bool IsWaitingForPurchase( const char * const productIdentifier ) {
		return ( GetProductState( productIdentifier ) == PRODUCT_WAIT_FOR_PURCHASE );
	}

	/*
	========================
	GetLocalizedPrice
	 
	Returns a UTF-8 encoded string that represents the price of the product. This string is
	suitable for display to the user. If the string isn't available yet, for example, if the
	App Store hasn't responded to an information request, the return value will be an empty
	string.	
	========================
	*/
	std::string GetLocalizedPrice( const char * const productIdentifier ) {
		productMap_t::iterator found = productCache.find( productIdentifier );
		
		if ( found != productCache.end() ) {
			return found->second.localizedPrice;
		}
		
		return std::string();
	}
	
	/*
	========================
	SetCallback
	 
	Stores a callback function to be invoked when something happens relating to a product.
	========================
	*/
	void SetCallback( callback_t callback ) {
		callbackObject = callback;
	}
	
	/*
	========================
	ClearCallback
	 
	Removes the callback function previously registered through SetCallback.
	========================
	*/
	void ClearCallback() {
		callbackObject = callback_t();
	}
}



@implementation MyStoreObserver

- (void) showInvalidProductIdAlert
{
	NSString * nsTitle = @"In-app purchase error";
	NSString * nsDescription = @"Invalid product ID requested. In-app purchase will not work!";
	NSString * nsOkButton = @"OK";
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nsTitle
													message:nsDescription
												   delegate:nil
										  cancelButtonTitle:nsOkButton
										  otherButtonTitles:nil];
	
	[alert show];
	[alert release];
}

/*
========================
productsRequest:didReceiveResponse

Called by the OS when the application gets product information about an In-App Purchase.
========================
*/
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	NSArray *myProduct = response.products;
	NSArray *invalidProducts = response.invalidProductIdentifiers;

	for ( SKProduct * product in myProduct )
	{
		NSLog( @"Valid product: %@", product.productIdentifier);
	}

	for ( NSString * productId in invalidProducts )
	{
		NSLog( @"Invalid product: %@", productId);
    
		[self performSelectorOnMainThread:@selector(showInvalidProductIdAlert) withObject:nil waitUntilDone:NO];
		return;
	}

	// We should handle the case of an empty array, this seems to occur if we send a request
	// with a nonexistant product ID, but there may be other cases.
	// TODO: Need a timeout to be even more robust.
	if ( [myProduct count] == 0 ) {
		//if ( clientCallback ) {
		//	clientCallback( IAP_FAILURE );
		//}
		return;
	}
    
	// We can use the same number formatter for all the products.
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
	
	// Get the response and cache it.
	for ( SKProduct * product in response.products )
	{
		// Convert the price to user-interface worthy representation.
		[numberFormatter setLocale:product.priceLocale];
		NSString *formattedString = [numberFormatter stringFromNumber:product.price];
		
		const std::string priceString = [formattedString cStringUsingEncoding:NSUTF8StringEncoding];
		
		// Convert the NSString identifier to a C++ string.
		const std::string identifierString = [product.productIdentifier cStringUsingEncoding:NSUTF8StringEncoding];
		
		productInformation_t productInformation( identifierString, priceString );
		
		// Add the C++ product information to the cache.
		productCache.insert( std::make_pair( identifierString, productInformation ) );
		
		// Store the fact that we have information in the defaults.
		SetProductState( identifierString.c_str(), PRODUCT_HAS_INFORMATION );
		
		if ( callbackObject ) {
			callbackObject( identifierString.c_str(), idInAppStore::PRODUCT_STATUS_RECEIVED_INFORMATION );
		}
	}
	
	[numberFormatter release];
    [request autorelease];
}

/*
 ========================
 paymentQueue:updatedTransactions
 
 Called by the system when purchase requests are updated.
 ========================
 */
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    (void)queue;
	for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    }
} 

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions
{
	(void)queue; (void)transactions;
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
	(void)queue; (void)error;
}


- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
	(void)queue;}

/*
========================
completeTransaction

Called by updatedTransactions when a request is completed.
========================
*/
- (void)completeTransaction:(SKPaymentTransaction *)transaction
{
	[self finalizeTransaction:transaction];
}

/*
========================
failedTransaction

Called by updatedTransactions when a request fails.
========================
*/
- (void)failedTransaction:(SKPaymentTransaction *)transaction
{
	if (transaction.error.code != SKErrorPaymentCancelled)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"In-App Purchase error"
														message:[transaction.error localizedDescription]
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
		
		[alert show];
		[alert release];
    }
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
	
	const char * const cProductIdentifier = [transaction.payment.productIdentifier cStringUsingEncoding:NSUTF8StringEncoding];
	
	// Since we can get failed transactions after the user has already purchased a product,
	// don't do anthing if the user has already purchased the product.
	if ( GetProductState( cProductIdentifier ) != PRODUCT_PURCHASED ) {
		SetProductState( transaction.payment.productIdentifier, PRODUCT_HAS_INFORMATION );

	
		if ( callbackObject ) {
			callbackObject( cProductIdentifier, idInAppStore::PRODUCT_STATUS_TRANSACTION_FAILED );
		}
	}
}

/*
========================
restoreTransaction

Called by updatedTransactions when a request is restored. This can behave identically to
completeTransaction.
========================
*/
- (void)restoreTransaction:(SKPaymentTransaction *)transaction
{
	[self finalizeTransaction:transaction.originalTransaction];
}

/*
========================
finalizeTransaction

This method actually delivers the purchased item to the user. Currently, this means setting
the state in NSUserDefaults to PRODUCT_PURCHASED.
========================
*/
- (void)finalizeTransaction:(SKPaymentTransaction *)transaction
{
	SetProductState( transaction.payment.productIdentifier, PRODUCT_PURCHASED );
	
	[[SKPaymentQueue defaultQueue] finishTransaction: transaction];
	
	const char * const cProductIdentifier = [transaction.payment.productIdentifier cStringUsingEncoding:NSUTF8StringEncoding];
	
	if ( callbackObject ) {
		callbackObject( cProductIdentifier, idInAppStore::PRODUCT_STATUS_PURCHASED );
	}
}

@end

