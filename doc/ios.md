# iOS Configuration

## Requirements

| Requirement | Value |
|-------------|-------|
| **iOS** | 15.0+ |
| **macOS** | 12.0+ |
| **Xcode** | 13.0+ |
| **Swift** | 5.5+ |

> This plugin uses **StoreKit 2**, Apple's modern Swift-based in-app purchase framework introduced in iOS 15. For migration details, see the [StoreKit 2 Migration Guide](storekit2-migration.md).

## Configure the App

App Store Connect: https://appstoreconnect.apple.com

 - Create an App ID (bundle identifier)
 - Create a Development Provisioning Profile
 - Create a new app (using the App ID)
 - Configure In-App Purchases under "Features" → "In-App Purchases"
 - Create a Sandbox test user under "Users and Access" → "Sandbox"

Device Setup

 - Settings → App Store → Sign out of production Apple ID
 - Sign in with Sandbox Apple ID when prompted during purchase
 - `cordova build ios`
 - Open with Xcode and run on device

## StoreKit 2 Features

### JWS Transaction Tokens

StoreKit 2 provides signed transactions in JWS (JSON Web Signature) format. Each transaction includes cryptographic proof that it came from Apple, enabling secure server-side verification.

```javascript
store.when().approved(transaction => {
    // The transaction contains a JWS token for server verification
    transaction.verify();
});
```

### AppAccountToken

StoreKit 2 introduces `appAccountToken`, a UUID that links purchases to your user accounts. Set this during purchase:

```javascript
const product = store.get('my_subscription');
product?.getOffer()?.order({
    appAccountToken: generateUUID(userId)  // Your user's ID as UUID
});
```

The token persists with the transaction and appears in:
- Client-side transaction data
- Server notifications (webhooks)
- Transaction history API calls

### Server-Side Verification

For your own validation server, use Apple's official library:

```bash
npm install @apple/app-store-server-library
```

```javascript
const { SignedDataVerifier, Environment } = require('@apple/app-store-server-library');

const verifier = new SignedDataVerifier([], true, Environment.SANDBOX, 'your.bundle.id');
const transaction = await verifier.verifyAndDecodeTransaction(jwsToken);
```

See the [StoreKit 2 Migration Guide](storekit2-migration.md) for complete backend setup instructions.

### Test users and subscriptions

1 month subscriptions auto-renew every 5 minutes. So far so good.
They auto-renew 5 times and then they stop,
so after 25 minutes your product will expire.

If you have any issue repurchasing the same subscription, or it will NOT auto-renew again on the same test account, you should be able to fix this by creating a new itunes connect test user.


### Hosted content

Apple offers the option to host non-consumable content on its servers, which is automatically downloaded to the device on successfully purchasing a non-consumable IAP (see the [documentation](https://developer.apple.com/library/ios/documentation/LanguagesUtilities/Conceptual/iTunesConnectInAppPurchase_Guide/Chapters/CreatingInAppPurchaseProducts.html#//apple_ref/doc/uid/TP40013727-CH3-SW4) in the Apple Dev Center for more on this).

To configure this in the demo app, follow these additional steps:

iTunes Connect

- Create a new purchase in iTunes Connect (type non-consumable)
- (Add a dummy screenshot)
- Check the box "Hosting Content with Apple"

Demo IAP content project

- Clone this Git repo containing a demo IAP containing content for hosting: [https://github.com/dpa99c/cordova-plugin-purchase-demo-ios-hosted](https://github.com/dpa99c/cordova-plugin-purchase-demo-ios-hosted)
- Edit the ContentInfo.plist (either in XCode or text editor) and set the `IAPProductIdentifier` key appropriately for your app Identifier
- Using XCode, select from the menu "Product" > "Archive"
- Then "Export..." > "Export as an Installer Package" > "Next" > "Export" to create an IAP .pkg file

Application Loader

- Download and install Apple's [Application Loader](https://itunesconnect.apple.com/docs/UsingApplicationLoader.pdf)
- Run Application Loaded and sign in with your iTunes Connect account details
- On the "Template Chooser" screen, select "New In-App purchases" > "Choose"
- Select the demo app Identifier > "Manage"
- Select the non-consumable IAP configured for Hosted content that you created above
- Select "Hosted Content"
- Ensure "Host Content with Apple" is checked and select "Choose..."
- Browse to and select the IAP .pkg file you exported from XCode
- Select "Next", then "Save" if prompted, then "Deliver"
- Once the package is uploaded to iTunes Connect, you'll see a big green tick

Demo application project

- Edit [config.xml](https://github.com/dpa99c/cordova-plugin-purchase-demo/blob/master/config.xml) and set the `id` attribute in the `<widget>` element to that of your app Identifier
- Edit [www/index.js](https://github.com/dpa99c/cordova-plugin-purchase-demo/blob/master/www/js/index.js) and set the `id` fields under `store.register` are for your IAP Identifiers.

You can omit automatic downloading of hosted content by setting the `disableHostedContent` store flag, for example:

    store.disableHostedContent = true;
    store.refresh();

### <a name="non-renewing"></a>Non-Renewing iOS Subscriptions

iOS has a special product type called Non-Renewing Subscriptions. You use this when you want something subscription based, but don't want Apple to auto-renew and manage your subscriptions. This means that the burden is on you, the developer, to manually implement necessary functionality like syncing between devices, prompting for renewals, etc. Apple will verify this functionality during the AppStore review process and reject your app if it does not implement this.

Anecdotally, non-renewing subscriptions are easier to implement and test than auto-renewing subscriptions, because you don't need to deal with receipt validation or wait hours for test subscriptions to expire. You also have more flexibility on subscription time periods than the limited options of auto-renewing subscriptions.

Although non-renewing subscriptions are officially subscriptions, you can think of them like consumable products, that you can purchase repeatedly during development and testing.

Key things to remember are:

  - You must prompt the user to renew when a subscription is about to expire. This isn't required by Apple, this is simply good business sense. Otherwise, users will have a gap between their subscription expiring and when they renew.
  - If a user purchases a new subscription before the existing has expired, you must add additional time to their subscription. For instance, if they purchase a year's subscription, then after 10 months they purchase another one, the subscription must now have 14 months remaining. This is required by Apple.
  - You must sync between all devices using the same Apple ID. Alternatively, if your app has a custom authentication mechanism that is not tied to an Apple ID, you must sync between all devices that login using your custom authentication. You must provide testing credentials to Apple during the AppStore review process so they can verify this. This is required by Apple.

Please read the [Apple Documentation](https://developer.apple.com/library/ios/documentation/LanguagesUtilities/Conceptual/iTunesConnectInAppPurchase_Guide/Chapters/CreatingInAppPurchaseProducts.html) for official information.

The easiest solution for most simple cases is to use the [Non-Renewing Subscriptions Extension](https://github.com/j3k0/cordova-non-renewing-subscription). It has a more high-level API that will take care of everything for you.

What follows is an example of how to implement non-renewing subscriptions in your JavaScript code. Remember, this is iOS only. When registering your product, use `store.NON_RENEWING_SUBSCRIPTION`.

This is made more difficult because non-renewing subscriptions always receive a series of lifecycle events everytime the app is started, which requires you to implement more code to handle various edge cases. Necessary helper functions you need to write are explained in the example below, called on a hypothetical `my_app_utils` class which contains a persistent state that lasts even if the app is killed, such as with HTML5 Local Storage.

This full body of code, which registers all necessary handlers and refreshes the `store`, must be executed every time the app starts.

```javascript
// Register the non-renewing subscription product with the store. You must
// create this in iTunes Connect.
store.register({
    id: "my_product_id",
    alias: "My Product",
    type: store.NON_RENEWING_SUBSCRIPTION
});

// Called when store.order("my_product_id") is executed. The user can
// still cancel after this has been called.
store.when("my_product_id").initiated(function(p) {
    // Write a function that identifies this product ID as having been
    // initiated to purchase.
    my_app_utils.setIsProductPurchaseInitiated("my_product_id", true);
});

// Called when the user has cancelled purchasing the product, after it has
// been initiated.
store.when("my_product_id").cancelled(function(p) {
    // Write a function that marks this product ID as not being purchased
    my_app_utils.setIsProductPurchaseInitiated("my_product_id", false);
});

// Called when the product purchase is finished. This gets called every time
// the app starts after the product has been purchased, so we use a helper
// function to determine if we actually need to purchase the non-renewing
// subscription on our own server.
store.when("my_product_id").approved(function(p) {

    my_product_id.purchaseNonRenewingSubscription(p.id, function success() {

        // Purchase has been executed successfully.
        // Must call finish to charge the user and allow the purchase to be
        // made again.

        p.finish();

        // Update the UI to allow another purchase
        my_app_utils.setIsProductPurchaseInitiated("my_product_id", false);

    }, function error(err));

        // Failed to deliver the subscription (link issue with server?).
        // Report to user, do not finish the transaction (so it pops up
        // next time the user starts the app).

        my_app_utils.alertUserAboutServerError({
            title: 'Subscription Purchase Error',
            template: 'We could not store your new subscription status on our server. ' +
                    'No worries, you have not been charged. Please ensure you are ' +
                    'connected to the Internet and try again.'
        });

        my_app_utils.setIsProductPurchaseInitiated("my_product_id", false);
    });
});

// Errors communicating with the iTunes server happen quite often,
// so it's highly recommended you implement some feedback to the user.
store.error(function(e){
    console.log("storekit ERROR " + e.code + ": " + e.message);
    my_app_utils.alertUserAboutITunesError({
        title: 'Subscription Purchase Error',
        template: 'We could not reach the Apple iTunes ordering server. ' +
                  'Please ensure you are connected to the Internet and try ' +
                  'again.'
    });
});

// Refresh the store to start everything
store.refresh();
```
