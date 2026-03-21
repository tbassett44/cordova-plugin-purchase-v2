# Cordova Purchase Plugin

> In-App Purchases for Cordova
Forked from [j3k0/cordova-plugin-purchase](https://github.com/j3k0/cordova-plugin-purchase) to add server-side IAP validation, webhook handling, and Upgrade to StoreKit 2.

Current State / Developer Notes:
-- Reasonbly tested on iOS / Cordova, not tested on Android.
-- iOS is likely not backward compatible with original plugin...or at least i havent tested or tried a migration.
-- Not tested with Capcitor / Ionic
-- Android version currently remains unchanged from original plugin.

---

Need professional help and support? [Contact Me](mailto:juicy@actualize.earth).

## Summary

This plugin allows **In-App Purchases** to be made from **Cordova, Ionic and Capacitor** applications.

It lets you handle in-app purchases on many platforms with a single codebase.

This is a plugin for the **Apache Cordova** framework that provides an easy and flexible way to integrate **in-app purchases** into Cordova-based mobile applications, including popular frameworks such as **Ionic and PhoneGap**. With this plugin, you can easily add support for in-app purchases of digital content, such as subscriptions, consumables, and non-consumables, using the store-specific purchase APIs provided by the major mobile platforms. The plugin also supports requesting payments through popular payment providers such as **Braintree**, allowing you to easily accept payments from your users.

The Cordova-Plugin-Purchase plugin is designed to be easy to use and integrate into your Cordova app, and it provides a consistent API across all supported platforms, so you can focus on building your app without worrying about platform-specific differences. Whether you are building a subscription-based app, a freemium app, or any other app that requires in-app purchases, the Cordova-Plugin-Purchase plugin can help you get started quickly and easily.

### Features

|  | AppStore (iOS / macOS) | Google Play | Braintree (iOS / Android) |
|--|--|--|--|
| consumables | ✅ | ✅ | ✅ |
| multi-quantity consumables |  | ✅ |  |
| non consumables | ✅ | ✅ |  |
| subscriptions | ✅ | ✅ |  |
| restore purchases | ✅ | ✅ | ✅ |
| payment requests |   |   | ✅ |
| [receipt validation](https://www.iaptic.com) | ✅ | ✅ | ✅ |

### Platform Requirements

| Platform | Minimum Version | Notes |
|----------|-----------------|-------|
| **iOS** | 15.0+ | StoreKit 2 (Swift) |
| **macOS** | 12.0+ | StoreKit 2 (Swift) |
| **Android** | SDK 23+ | Google Play Billing Library 8.3.0 |

> **iOS/macOS Note:** This plugin uses **StoreKit 2**, Apple's modern Swift-based in-app purchase framework. StoreKit 2 provides JWS-signed transactions, built-in verification, and improved subscription handling. See the [StoreKit 2 Migration Guide](doc/storekit2-migration.md) for details.

## Installation

### Install the plugin (Cordova)

```sh
cordova plugin add "cordova-plugin-purchase" --variable SWIFTVERSION="5.5"
```

> **Important:** The `--variable SWIFTVERSION="5.5"` flag is required for iOS/macOS builds. This plugin uses StoreKit 2 which requires Swift 5.5+ for async/await support.

## Development

### Building from Source

The plugin's JavaScript is compiled from TypeScript sources located in `src/ts/`. After modifying TypeScript files, you must recompile:

```bash
# Install dependencies (first time only)
npm install

# Compile TypeScript to JavaScript
make compile
```

This compiles the TypeScript source files and outputs to:
- `www/store.js` - Main plugin JavaScript
- `www/store.d.ts` - TypeScript type definitions

### Available Make Commands

| Command | Description |
|---------|-------------|
| `make compile` | Compile TypeScript to JavaScript |
| `make build` | Compile and run tests |
| `make test` | Run unit tests |
| `make doc` | Generate API documentation |
| `make javalint` | Check Java code syntax |
| `make clean` | Remove temporary files |
| `make help` | Show all available commands |

### Recommended plugins

<details>
<summary>
Install <strong>cordova-plugin-network-information</strong> (click for details).
</summary>


Sometimes, the plugin cannot connect to the app store because it has no network connection. It will then retry either:

* periodically after a certain amount of time;
* when the device fires an ['online'](https://developer.mozilla.org/en-US/docs/Web/Events/online) event.

The [cordova-plugin-network-information](https://github.com/apache/cordova-plugin-network-information) plugin is required in order for the `'online'` event to be properly received in the Cordova application. Without it, this plugin will only be able to use the periodic check to determine if the device is back online.

</details>

<details>
<summary>
Install <strong>cordova-plugin-advanced-http</strong> (click for details).
</summary>


When making receipt validation requests, the purchase plugin uses, by default, the browser's ajax capabilities. This sometime causes issues with CORS restriction. CORS also imposes an extra back-and-forth with the server (the CORS preflight request) to ensure the server allows for such request to be made. By installing the [advanced-http plugin](https://github.com/silkimen/cordova-plugin-advanced-http), you get rid of those issue and benefit from the extra feature of the the plugin, like advanced authentication option. Read the [advanced-http](https://github.com/silkimen/cordova-plugin-advanced-http) plugin documentation for details.
</details>

### Note for ionic 3

Since version 13 of the plugin, it should be used **without** `@ionic-native/in-app-purchase-2`.

ionic 3 doesn't support recent typescript notations, but the plugin can be used without typings by just declaring it:

```ts
declare var CdvPurchase: any
```

### Note for Capacitor users

Capacitor users can install the latest version of the plugin without the help of the awesome-cordova-plugins wrapper. Just install the `cordova-plugin-purchase` module and `import "cordova-plugin-purchase"` in files where it's needed. (some user reported using `import "cordova-plugin-purchase/www/store.d"` to get it working).

As with other plugins, you should wait for Capacitor `this.platform.ready()` before using the plugin.

```ts
import 'cordova-plugin-purchase';

@Injectable()
export class AppStoreService {

  // DO NOT initialize to CdvPurchase.store here
  store?: CdvPurchase.Store;

  constructor() {
    this.platform.ready().then(() => {
      // MUST WAIT for Cordova to initialize before referencing CdvPurchase namespace
      this.store = CdvPurchase.store
    });
  }
}
```

### Setup your Application

See [Setup iOS Applications](https://github.com/j3k0/cordova-plugin-purchase/wiki/Setup-for-iOS-and-macOS#setup-ios-applications) and [Setup Android Applications](https://github.com/j3k0/cordova-plugin-purchase/wiki/Setup-for-Android-Google-Play#setup-android-applications).

## Getting Started

### Learning about In-App Purchases

If you wish to learn more about In-App Purchases (IAP), you'll find a good overview on the subject from the various platforms documentation:

* Apple:
   * [In-App Purchase Introduction](https://developer.apple.com/in-app-purchase/)
   * [Auto-Renewable Subscriptions](https://developer.apple.com/app-store/subscriptions)
* Google:
   * [In-App Purchases Best Practices](https://developer.android.com/distribute/best-practices/earn/in-app-purchases)
   * [Billing Overview](https://developer.android.com/google/play/billing/billing_overview)
* Microsoft
  * [Monetize with In-App Purchases](https://docs.microsoft.com/en-us/windows/uwp/monetize/in-app-purchases-and-trials)

All platforms share the same concepts, so they are a good reads in all cases.

### Using the Plugin

To ease the beginning of your journey into the intimidating world of In-App Purchase with Cordova, we wrote a guide which hopefully will help you get things done:

* [Guide: Cordova In-App Purchase Plugin - v13.0](https://purchase.cordova.fovea.cc/v/v13.0/)

You'll have two main tasks to accomplish:

 1. Setup your application and In-App Products on AppStore, Play, Braintree or Azure platforms using their respective web interfaces.
 2. Add In-App Purchase code to your application.

For platform setup, the [wiki](https://github.com/j3k0/cordova-plugin-purchase/wiki/Home) is a good starting point.

There's a specific page for the [version 13](https://github.com/j3k0/cordova-plugin-purchase/wiki/Version-13).

**API documentation** can be found here: [cordova-plugin-purchase API](https://www.iaptic.com/documentation/cordova-plugin-api/)

### Upgrading to Version 13

There's been some changes to the API with version 13 of the plugin. This document should help existing apps with the migration: [Migrate to version 13](https://github.com/j3k0/cordova-plugin-purchase/wiki/HOWTO:-Migrate-to-v13).

### Receipt Validation

The plugin supports two modes of operation for managing product ownership:

1. **With Receipt Validation (Recommended)**
   - Products ownership status is determined by validating receipts with a server
   - `product.owned` reflects the validated ownership status
   - Works reliably across all environments (TestFlight, AppStore)
   - Can be setup using [Iaptic's receipt validation service](https://www.iaptic.com)

2. **Without Receipt Validation**
   - Relies only on local device data
   - `product.owned` will initially be false
   - Use `store.owned(productId)` to check ownership status
   - Limited functionality in test environments

For proper subscription support, receipt validation is strongly recommended. You can:
- Implement your own validation server
- Use [Iaptic's receipt validation service](https://www.iaptic.com)

See our [receipt validation guide](https://purchase.cordova.fovea.cc/v/v13.0/advanced/receipt-validation) for more details.

### Subscription Example

Here's a complete example showing how to implement subscriptions with the plugin:

```typescript
class SubscriptionService {

  constructor(store: CdvPurchase.Store) {
    // Setup receipt validation (recommended)
    store.validator = "https://validator.iaptic.com/v1/validate?appName=demo&apiKey=12345678";

    // Register products
    store.register([{
      id: 'subscription1',
      platform: CdvPurchase.Platform.APPLE_APPSTORE,
      type: CdvPurchase.ProductType.PAID_SUBSCRIPTION,
    }]);

    // Setup event handlers
    store.when()
      .productUpdated(() => {
        console.log('Products loaded from the store:', store.products);
        updateProductsUI(); //
      })
      .approved(transaction => {
        console.log('Purchase approved:', transaction);
        transaction.verify();
      })
      .verified(receipt => {
        console.log('Purchase verified:', receipt);
        receipt.finish();
        updateActiveSubscriptionUI();
      });

    // Initialize the store
    store.initialize([{
      platform: CdvPurchase.Platform.APPLE_APPSTORE,
      options: {
        needAppReceipt: true,
        // debug: true, // uncomment to enable verbose native Swift logging
      }
    }]);
  }

  /** Purchase a subscription */
  subscribe(productId: string) {
    const product = store.get(productId);
    if (!product) {
      console.log('Product not found');
      return;
    }
    product.getOffer()?.order()
      .then(error => {
        if (error) {
          if (error.code === CdvPurchase.ErrorCode.PAYMENT_CANCELLED) {
            console.log('Payment cancelled by user');
          }
          else {
            console.log('Failed to subscribe:', error);
          }
        }
      });
  }

  /** Check if user has an active subscription */
  hasActiveSubscription(): boolean {
    return store.owned('subscription1');
  }
}
```

For a more complete example with a backend integration, check:
- Client: https://github.com/j3k0/cordova-subscription-example
- Server: https://github.com/iaptic/iaptic-example-nodejs-backend

## Apple AppStore Initialization Options

When initializing the Apple AppStore platform you can pass an `options` object to tune behaviour.
The `options` block also supports **environment-specific configuration** via nested `production` and `sandbox` keys — the plugin automatically detects the environment and applies the matching settings.

```js
store.initialize([{
  platform: CdvPurchase.Platform.APPLE_APPSTORE,
  options: {
    needAppReceipt: false, // default: true — set false for StoreKit 2
    autoFinish: false,     // default: false
    debug: true,           // default: false

    // Environment-specific options (auto-selected on init)
    production: {
      validator: 'https://your-server.com/iap/validate/apple'
    },
    sandbox: {
      validator: 'https://your-server.com/iap_sandbox/validate/apple'
    }
  }
}]);
```

| Option | Type | Default | Description |
|---|---|---|---|
| `needAppReceipt` | `boolean` | `true` | Set to `false` to skip loading the legacy App Store receipt. Recommended when using StoreKit 2 JWS-only validation, which avoids an unnecessary disk read at startup. |
| `autoFinish` | `boolean` | `false` | Automatically finish all transactions as soon as they are approved. Use only in development when you want to clear a backlogged transaction queue. |
| `debug` | `boolean` | `false` | Enable verbose native Swift logging. When `true`, every internal `log()` call in the Swift plugin layer is printed to the Xcode console. Useful during development to trace subscription status checks, StoreKit 2 entitlement lookups, and upgrade/downgrade detection without changing `store.verbosity` globally. |
| `production` | `object` | — | Object with `{ validator: string, restore: string }`. Used when the app is running in a production environment. |
| `sandbox` | `object` | — | Object with `{ validator: string, restore: string }`. Used when the app is running in a sandbox (debug) environment. |
| `restore` | `string` | — | URL of the server restore endpoint (e.g. `https://your-server.com/iap/restore/apple`). Set at the top-level or inside `production`/`sandbox` blocks. Automatically assigned to `store.restoreUrl` on init. |

> **Tip:** `debug: true` is equivalent to setting `store.verbosity = CdvPurchase.LogLevel.DEBUG` but scoped only to the native layer — JS-level log volume stays unchanged.

### Sandbox / Production Environment Detection

During `initialize()`, the plugin automatically detects whether the app is running in **sandbox** or **production** mode:

- **iOS:** Uses `cordova-plugin-device-meta` to check if the build is a debug build → `sandbox`. Release builds → `production`.
- **Android:** Always returns `production` (Google Play handles sandbox internally).
- **Fallback:** If the DeviceMeta plugin is not installed, defaults to `production` with a console warning.

When **sandbox** is detected:
- `store.validator` is set from `options.sandbox.validator` (if provided)
- `store.minTimeBetweenUpdates` is automatically set to `0` (instant refresh for testing)
- A yellow warning banner is logged to the console

The detected environment is cached and available via:

```js
const env = await CdvPurchase.store.getEnvironment(); // 'production' | 'sandbox'
// Also available synchronously after init:
console.log(CdvPurchase.store.environment); // 'production' | 'sandbox'
```

> **Prerequisite:** Install `cordova-plugin-device-meta` for automatic sandbox detection on iOS.

## Warm-Up Pattern (Silent Initialization)

For the best user experience, initialize the store **at app launch** rather than waiting for the subscription page. This "warm-up" loads product metadata and checks entitlements silently — **no Apple ID login prompt** is triggered.

```javascript
// In your app startup (e.g. app.js or phone.init)
phone.iap = {
  status: 'loading',
  entitlement: null,

  getOptions: function() {
    return {
      needAppReceipt: false,  // Critical: prevents legacy receipt refresh prompt
      debug: true,
      production: { validator: apiUrl + '/iap/validate/apple' },
      sandbox:    { validator: apiUrl + '/iap_sandbox/validate/apple' }
    };
  },

  init: function() {
    if (!window.CdvPurchase) { phone.iap.status = 'unavailable'; return; }
    var platform = CdvPurchase.Platform.APPLE_APPSTORE;

    CdvPurchase.store.initialize([{
      platform: platform,
      options: phone.iap.getOptions()
    }]).then(function() {
      phone.iap.status = 'ready';
      // Silently check entitlements — no network, no login prompt
      var adapter = CdvPurchase.store.getAdapter(platform);
      if (adapter && adapter.bridge && adapter.bridge.getCurrentEntitlements) {
        adapter.bridge.getCurrentEntitlements(function(entitlements) {
          // Find active (non-expired) entitlement
          var now = Date.now(), active = null;
          for (var i = 0; i < entitlements.length; i++) {
            var expMs = entitlements[i].expirationDate
                      ? parseFloat(entitlements[i].expirationDate) : 0;
            if (!expMs || expMs > now) { active = entitlements[i]; break; }
          }
          phone.iap.entitlement = active || false;
        }, function() { phone.iap.entitlement = false; });
      }
    });
  }
};
```

**Why this is safe at app launch:**
- `initialize()` only sets up the StoreKit observer, checks `canMakePayments`, and reads local state
- `needAppReceipt: false` prevents the legacy `SKReceiptRefreshRequest` that can trigger a login prompt
- `getCurrentEntitlements` reads from `Transaction.currentEntitlements` — local only, no network

**Shortcut: `store.currentEntitlement`**

After `initialize()` resolves, the store automatically resolves and caches the active entitlement on `store.currentEntitlement`. You can use this instead of calling the bridge directly:

```javascript
CdvPurchase.store.initialize([...]).then(function() {
  // store.currentEntitlement is already resolved
  var entitlement = CdvPurchase.store.currentEntitlement;
  if (entitlement) {
    console.log('Active entitlement:', entitlement.productId, 'on', entitlement.platform);
  } else {
    console.log('No active entitlement');
  }
});
```

| Value | Meaning |
|-------|---------|
| `null` | Not yet resolved (init still in progress) |
| `false` | Resolved — no active entitlement |
| `{ productId, platform, expirationDate?, transactionId?, purchaseDate? }` | Active entitlement |

When the user later navigates to the subscription page, you can skip re-initialization:

```javascript
if (phone.iap.status === 'ready') {
  // Store already initialized — just refresh products
  CdvPurchase.store.update();
} else {
  // Cold init (warm-up not yet done)
  CdvPurchase.store.initialize([{ platform: p, options: phone.iap.getOptions() }]);
}
```

## Restore & Sync: `store.restoreAndSync()`

`restoreAndSync()` combines the native platform restore flow with a server-side sync in one call. It:
1. Triggers the native restore on Apple (StoreKit 2) or Google Play
2. Collects JWS tokens (iOS) or purchase tokens (Android)
3. POSTs them to `store.restoreUrl` for server-side entitlement re-validation

**Setup** — set `restoreUrl` via the `restore` option in `initialize()`:

```javascript
store.initialize([{
  platform: CdvPurchase.Platform.APPLE_APPSTORE,
  options: {
    production: {
      validator: 'https://your-server.com/iap/validate/apple',
      restore:   'https://your-server.com/iap/restore/apple'
    },
    sandbox: {
      validator: 'https://your-server.com/iap_sandbox/validate/apple',
      restore:   'https://your-server.com/iap_sandbox/restore/apple'
    }
  }
}]);
```

**Usage:**

```javascript
CdvPurchase.store.restoreAndSync({
  platform: CdvPurchase.Platform.APPLE_APPSTORE,
  userId: 'user123',
  headers: { 'Authorization': 'Bearer ' + authToken }, // optional
  onStart:          () => showSpinner(),
  onSuccess:        (result) => console.log('Restored', result.restored, 'purchase(s)'),
  onError:          (err)    => console.error('Restore failed:', err),
  onNoTransactions: ()       => console.log('Nothing to restore')
});
```

| Callback | When called |
|----------|-------------|
| `onStart` | Native restore begins |
| `onSuccess(result)` | Server responded OK — `result.restored` is the count re-validated |
| `onError(message)` | Any failure: no `restoreUrl`, native error, or server error |
| `onNoTransactions` | Native restore completed but found zero transactions |

> **Requires** `store.restoreUrl` to be set (via `options.restore` or directly). If not set, `onError` is called immediately.

## Utility: `Store.userIdToUUID()`

Apple requires `applicationUsername` (mapped to `appAccountToken` in StoreKit 2) to be a valid UUID. This static utility converts any short user ID string into a **deterministic, reversible UUID**:

```javascript
// Convert your app's user ID to a UUID for Apple
var uuid = CdvPurchase.Store.userIdToUUID('U1234567890');
// => "55313233-3435-3637-3839-300000000000"

// Set it before initializing or purchasing
CdvPurchase.store.applicationUsername = uuid;
```

**How it works:**
- Each character is encoded as 2 hex digits (ASCII code)
- The result is zero-padded to 32 hex characters
- Formatted as a UUID: `8-4-4-4-12`

**Constraints:**
- Maximum input length: **16 characters** (each char = 2 hex digits, UUID has 32 hex digits max)
- Throws an error if the input exceeds 16 characters

**Server-side reversal** — `purchase_api.js` includes a matching `uuidToUserId()` function that reverses the encoding:

```javascript
// Server-side (in purchase_api.js)
iap.uuidToUserId('55313233-3435-3637-3839-300000000000');
// => "U1234567890"
```

This is used automatically by the webhook handler to extract `userId` from `appAccountToken` in Apple notifications, and from `obfuscatedExternalAccountId` in Google Play notifications. Both platforms follow the same encode/decode pattern — set `store.applicationUsername = CdvPurchase.Store.userIdToUUID(userId)` before purchasing and the webhooks will decode it automatically.

## Server-Side IAP Service (purchase_api.js)

This plugin includes a standalone **Node.js/Express IAP service** (`purchase_api.js`) that handles server-side receipt validation, webhooks, and entitlement management for both Apple App Store and Google Play.

### Features

| Feature | Apple | Google |
|---------|-------|--------|
| Receipt/JWS Validation | ✅ | ✅ |
| Server Notifications (Webhooks) | ✅ App Store Server Notifications v2 | ✅ Real-time Developer Notifications (RTDN) |
| Restore Purchases | ✅ | - |
| Entitlement Status Lookup | ✅ | ✅ |
| Debug/Auth Testing | ✅ | - |

### Installation

```bash
npm install express googleapis @apple/app-store-server-library node-fetch
```

### Configuration

Add `iap` (production) and `iap_sandbox` sections to your config file:

```json
{
  "iap": {
    "port": 3335,
    "apple": {
      "file_path": "/var/www/priv/iap.apple.p8",
      "APPLE_ISSUER_ID": "your-issuer-id",
      "APPLE_KEY_ID": "your-key-id",
      "APPLE_PRIVATE_KEY": [
        "-----BEGIN PRIVATE KEY-----",
        "...your private key lines...",
        "-----END PRIVATE KEY-----"
      ],
      "APPLE_BUNDLE_ID": "com.your.app",
      "APPLE_APPLE_ID": "123456789",
      "APPLE_ENVIRONMENT": "production"
    }
  },
  "iap_sandbox": {
    "port": 3336,
    "apple": {
      "file_path": "/var/www/priv/iap.apple_sandbox.p8",
      "APPLE_ISSUER_ID": "your-issuer-id",
      "APPLE_KEY_ID": "your-sandbox-key-id",
      "APPLE_PRIVATE_KEY": [
        "-----BEGIN PRIVATE KEY-----",
        "...your sandbox private key lines...",
        "-----END PRIVATE KEY-----"
      ],
      "APPLE_BUNDLE_ID": "com.your.app.dev",
      "APPLE_APPLE_ID": "123456789",
      "APPLE_ENVIRONMENT": "sandbox"
    }
  }
}
```

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/iap/health` | Health check |
| `GET` | `/iap/debug/apple-auth` | Test Apple credentials |
| `GET` | `/iap/status?userId=...` | Get user's entitlement status |
| `POST` | `/iap/validate/apple` | Validate Apple JWS transaction |
| `POST` | `/iap/validate/google` | Validate Google purchase |
| `POST` | `/iap/restore/apple` | Restore Apple purchases |
| `POST` | `/iap/webhook/apple` | Apple Server Notifications v2 |
| `POST` | `/iap/webhook/google` | Google RTDN Pub/Sub webhook |

### Example: Validate Apple Purchase

```javascript
// Client-side after purchase
const response = await fetch('https://your-server.com/iap/validate/apple', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    userId: 'user123',
    signedTransaction: jwsToken  // From StoreKit 2
  })
});
```

### Example: Restore Purchases

```javascript
// After calling CdvPurchase.store.restorePurchases()
const response = await fetch('https://your-server.com/iap/restore/apple', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    userId: 'user123',
    transactions: [
      { signedTransaction: 'jws-token-1' },
      { signedTransaction: 'jws-token-2' }
    ]
  })
});
```

### Running the Service

The service supports a `--sandbox` flag to switch between production and sandbox environments:

```bash
# Production (default)
node purchase_api.js

# Sandbox — uses iap_sandbox config, separate DB collections, different route prefix
node purchase_api.js --sandbox

# With PM2 (run both side by side)
pm2 start purchase_api.js --name iap-prod --time
pm2 start purchase_api.js --name iap-sandbox --time -- --sandbox
```

**What `--sandbox` changes:**
| Aspect | Production | Sandbox |
|--------|-----------|---------|
| Config key | `tools.conf.iap` | `tools.conf.iap_sandbox` |
| Route prefix | `/iap/...` | `/iap_sandbox/...` |
| DB collections | `iap_entitlement`, `iap_transaction` | `iap_entitlement_sandbox`, `iap_transaction_sandbox` |
| Apple environment | `Environment.PRODUCTION` | `Environment.SANDBOX` |
| Startup banner | (none) | Yellow ⚠ SANDBOX MODE warning |

Your config file should have both `iap` (production) and `iap_sandbox` (sandbox) blocks with their respective Apple credentials, ports, and bundle IDs.

### Apple Webhook Setup

1. In App Store Connect, go to **App Information** → **App Store Server Notifications**
2. Set the URL to: `https://your-server.com/iap/webhook/apple`
3. Select **Version 2** notifications

### Google RTDN Setup

1. Create a Pub/Sub topic in Google Cloud Console
2. Configure a push subscription pointing to: `https://your-server.com/iap/webhook/google`
3. Link the topic to your Play Console app

**userId resolution in the Google webhook:** The webhook automatically decodes `obfuscatedExternalAccountId` from the purchase using `uuidToUserId()` — the same reverse of `Store.userIdToUUID()` used on the client. If `obfuscatedExternalAccountId` is not present (e.g. older purchases), it falls back to a `?userId=` query parameter on the webhook URL.

## Extra Resources

### For iOS

 - [In-App Purchase Configuration Guide for AppStore Connect](https://developer.apple.com/support/app-store-connect/)
   - Learn how to set up and manage In-App Purchases with AppStore Connect.

### Extensions

 - [Braintree SDK](https://github.com/j3k0/cordova-plugin-purchase-braintree)
   - Add the Braintree SDK to your application, enable Braintree on iOS and Android.

# Contribute

### Contributors:

 * ![](https://avatars1.githubusercontent.com/u/191881?s=64&v=4) [Jean-Christophe Hoelt](https://github.com/j3k0), Author
 * ![](https://avatars3.githubusercontent.com/u/1674289?s=64&v=4) [Josef Fröhle](https://github.com/Dexus), Support
 * Guillaume Charhon, (now defunct) v1 for android
 * Matt Kane, initial iOS code
 * Mohammad Naghavi, original unification attempt
 * Dave Alden [@dpa99c](https://github.com/dpa99c) (Apple-hosted IAPs for iOS)

## Sponsors

 * <a href="https://fovea.cc"><img alt="Logo Fovea" src="https://fovea.cc/blog/wp-content/uploads/2017/09/fovea-logo-flat-128.png" height="50" /></a><br/>For sponsoring most of JC's work on the plugin.
 * <img alt="Logo Ionic" src="https://www.fovea.cc/files/Ionic-logo-landscape.png" height="50"><br/>Ionic Framework Team (http://ionicframework.com/)
 * <a href="https://www.simplan.de/"><img alt="Logo SimPlan" src="https://files.fovea.cc/wp-content/uploads/SimPlan-Logo.png" height="50"></a><br/>For sponsoring the UWP platform.
 * Maxwell C. Moore ([MCM Consulting, LLC](http://mcmconsulting.biz))
 * Justin Noel [@calendee](https://github.com/calendee)
 * [Those guys](https://www.indiegogo.com/projects/phonegap-cordova-in-app-purchase-ios-and-android#pledges)

## Licence

The MIT License

Copyright (c) 2014-, Jean-Christophe HOELT and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
