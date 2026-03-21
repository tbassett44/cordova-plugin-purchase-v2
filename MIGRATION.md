# Migration Guide: j3k0/cordova-plugin-purchase → cordova-plugin-purchase-v2

This document covers what changed when migrating from the upstream [j3k0/cordova-plugin-purchase](https://github.com/j3k0/cordova-plugin-purchase) (forked at commit `a954174`, v13.x) to this fork.

---

## Summary of Changes

| Area | Upstream | This Fork |
|------|----------|-----------|
| iOS implementation | StoreKit 1 (Objective-C) | **StoreKit 2 (Swift)** |
| iOS minimum version | ~12.0 | **15.0+** |
| macOS minimum version | ~10.15 | **12.0+** |
| Install command | `cordova plugin add cordova-plugin-purchase` | requires `--variable SWIFTVERSION="5.5"` |
| Receipt format (iOS) | Unified app receipt (Base64) | **Per-transaction JWS tokens** |
| Server-side validation | Iaptic or DIY | Ships with `purchase_api.js` (Express) |
| Sandbox/prod detection | Manual | **Automatic** (via `cordova-plugin-device-meta`) |
| Android | Unchanged | Unchanged |
| Backward compatible (iOS) | — | **No** |

---

## Breaking Changes

### 1. iOS Requires StoreKit 2

The entire iOS/macOS layer has been rewritten in Swift using StoreKit 2. This is **not backward compatible** with the original Objective-C StoreKit 1 implementation.

**Impact:**
- Minimum iOS deployment target must be **15.0**
- Minimum macOS deployment target must be **12.0**
- The legacy receipt (`needAppReceipt: true`) is no longer the primary validation path — JWS tokens per transaction are used instead

### 2. Install Command Requires Swift Version Flag

**Before:**
```sh
cordova plugin add "cordova-plugin-purchase"
```

**After:**
```sh
cordova plugin add "cordova-plugin-purchase" --variable SWIFTVERSION="5.5"
```

This flag is required. Without it, the Swift files will fail to compile.

### 3. Receipt Format Changed (iOS)

**Before (StoreKit 1):** A single Base64-encoded app receipt blob was sent to your server.

**After (StoreKit 2):** Each transaction has its own `jwsRepresentation` (JWS-signed token). Your server must be updated to verify JWS transactions using `@apple/app-store-server-library`.

If you were using Iaptic for validation, no change is needed on the client — just point `store.validator` at a server that handles JWS. See `doc/storekit2-migration.md` for full server-side upgrade details.

### 4. `applicationUsername` Must Be a Valid UUID (iOS)

StoreKit 2 maps `applicationUsername` to `appAccountToken`, which Apple requires to be a **valid UUID**. Passing a raw user ID string will be rejected.

**Before:**
```javascript
store.applicationUsername = 'user123'; // worked in SK1
```

**After:**
```javascript
store.applicationUsername = CdvPurchase.Store.userIdToUUID('user123'); // required for SK2
```

Use `Store.userIdToUUID()` to convert any short string to a deterministic UUID. Max 16 characters. The server-side `purchase_api.js` includes a matching `uuidToUserId()` to reverse it.

---

## New Features

### Environment-Specific `initialize()` Options

The `options` block for Apple AppStore now supports nested `production` and `sandbox` keys. The plugin auto-detects the environment at startup and applies the matching config:

```javascript
store.initialize([{
  platform: CdvPurchase.Platform.APPLE_APPSTORE,
  options: {
    needAppReceipt: false,  // recommended for StoreKit 2
    debug: false,
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

| New Option | Description |
|------------|-------------|
| `needAppReceipt` | Set `false` to skip legacy receipt — recommended for StoreKit 2 |
| `debug` | Enable verbose native Swift logging to Xcode console |
| `production` | `{ validator, restore }` applied in production builds |
| `sandbox` | `{ validator, restore }` applied in sandbox/debug builds |
| `restore` | URL used by `store.restoreAndSync()` |

> **Prerequisite:** Install `cordova-plugin-device-meta` for automatic sandbox detection on iOS. Without it, the environment defaults to `production`.

### `store.environment` / `store.getEnvironment()`

After `initialize()`, the detected environment is available:

```javascript
await store.initialize([...]);
console.log(store.environment); // 'production' | 'sandbox'
// or async:
const env = await store.getEnvironment();
```

### `store.currentEntitlement`

Automatically resolved after `initialize()`. No need to call the bridge directly:

```javascript
await store.initialize([...]);
const e = store.currentEntitlement;
// null  → not yet resolved
// false → no active entitlement
// { productId, platform, expirationDate?, transactionId?, purchaseDate? } → active
```

### `store.restoreAndSync(options)`

Combines native restore + server-side sync in one call. Requires `store.restoreUrl` (set via `options.restore` in `initialize()`).

```javascript
store.restoreAndSync({
  platform: CdvPurchase.Platform.APPLE_APPSTORE,
  userId: 'user123',
  onStart:          () => showSpinner(),
  onSuccess:        (result) => console.log('Restored', result.restored),
  onError:          (err)    => console.error(err),
  onNoTransactions: ()       => console.log('Nothing to restore')
});
```

### `Store.userIdToUUID()` / `iap.uuidToUserId()` (Server)

Client converts a user ID to a UUID for `appAccountToken`:

```javascript
store.applicationUsername = CdvPurchase.Store.userIdToUUID('user123');
```

Server reverses it to get back the original user ID:

```javascript
iap.uuidToUserId('75736572-3132-3300-0000-000000000000'); // => 'user123'
```

This decoding is applied automatically by both the Apple and Google webhooks in `purchase_api.js`.

### Server-Side IAP Service (`purchase_api.js`)

A standalone Node.js/Express IAP service is now included with the plugin. It handles:

- Apple JWS transaction validation
- Google Play purchase validation
- Apple App Store Server Notifications v2 (webhooks)
- Google Play Real-Time Developer Notifications (RTDN, Pub/Sub)
- Purchase restore (Apple)
- Entitlement status lookup (Apple + Google)
- Sandbox and production modes (run two instances side-by-side)

```bash
npm install express googleapis @apple/app-store-server-library node-fetch
node purchase_api.js           # production
node purchase_api.js --sandbox # sandbox
```

See the **Server-Side IAP Service** section in `README.md` for full configuration and endpoint documentation.

---

## What Did Not Change

- The JavaScript/TypeScript public API (`store.register`, `store.when`, `store.initialize`, `product.getOffer()?.order()`, etc.) is unchanged
- Android implementation is unchanged from the original plugin
- Ionic 3, Capacitor, and PhoneGap usage patterns are unchanged
- `store.owned()`, `store.get()`, `store.products`, `store.validator` all work as before

---

## Migration Checklist

- [ ] Update iOS deployment target to **15.0** and macOS to **12.0**
- [ ] Add `--variable SWIFTVERSION="5.5"` to your `cordova plugin add` command
- [ ] Set `needAppReceipt: false` in `initialize()` options
- [ ] Install `cordova-plugin-device-meta` for sandbox auto-detection
- [ ] Wrap user IDs with `Store.userIdToUUID()` before assigning to `store.applicationUsername`
- [ ] Update your server to verify JWS transactions (see `doc/storekit2-migration.md`)
- [ ] Optionally: deploy `purchase_api.js` as your IAP validation server
- [ ] Optionally: configure `production.restore` / `sandbox.restore` in `initialize()` to use `store.restoreAndSync()`
