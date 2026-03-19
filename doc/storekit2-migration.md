# StoreKit 2 Migration Guide

This document describes the migration from StoreKit 1 (Objective-C) to StoreKit 2 (Swift) for iOS and macOS.

## Overview

Starting with version 13.14, the iOS/macOS implementation has been completely rewritten using Apple's **StoreKit 2** framework. This modern Swift-based API provides:

- **Built-in transaction verification** using JWS (JSON Web Signature)
- **Automatic receipt management** without manual receipt handling
- **Async/await support** for cleaner code
- **Better subscription handling** with native renewal info
- **AppAccountToken** for linking purchases to user accounts

## Requirements

| Requirement | Value |
|-------------|-------|
| **iOS** | 15.0+ |
| **macOS** | 12.0+ |
| **Swift** | 5.5+ |
| **Xcode** | 13.0+ |

> **Note:** iOS 15+ coverage is approximately 97% of active devices, making this a safe requirement for most applications.

## Key Changes

### 1. JWS Transaction Tokens

StoreKit 2 transactions are signed using JWS (JSON Web Signature) instead of the legacy unified receipt format.

**Before (StoreKit 1):**
```javascript
// Legacy receipt was a single Base64-encoded blob
const receipt = await store.getApplicationReceipt();
// Send entire receipt to server for validation
```

**After (StoreKit 2):**
```javascript
// Each transaction has its own JWS token
store.when().approved(transaction => {
    // transaction.nativePurchase.jwsRepresentation contains the signed transaction
    transaction.verify();
});
```

### 2. Transaction Verification

The plugin now provides per-transaction JWS tokens that can be verified server-side using Apple's certificate chain.

**Client-side** (unchanged from user perspective):
```javascript
store.when().approved(transaction => {
    transaction.verify(); // Sends JWS to your validation server
});
```

### 3. AppAccountToken (User Identification)

StoreKit 2 introduces `appAccountToken`, a UUID that persists with the transaction. This is the recommended way to link App Store purchases to your user accounts.

**Setting the token during purchase:**
```javascript
store.when().productUpdated(() => {
    const product = store.get('my_subscription');
    product?.getOffer()?.order({
        appAccountToken: generateUUID(userId) // Your user's unique identifier
    });
});
```

The `appAccountToken` will be included in:
- The JWS transaction token sent to your server
- App Store Server Notifications (webhooks)

### 4. Restore Purchases

Restore now uses `Transaction.currentEntitlements` internally, providing a more reliable list of active purchases.

```javascript
store.restorePurchases();
```

## Backend Server Changes

If you're running your own validation server (not using Iaptic), you'll need to update it to handle StoreKit 2 transactions.

### Required Changes

1. **Install Apple's official library:**
   ```bash
   npm install @apple/app-store-server-library
   ```

2. **Verify JWS transactions** using `SignedDataVerifier`:
   ```javascript
   const { SignedDataVerifier, Environment } = require('@apple/app-store-server-library');
   
   const verifier = new SignedDataVerifier(
       [], // Apple root CAs (empty = use online checks)
       true, // Enable online checks
       Environment.SANDBOX, // or Environment.PRODUCTION
       'your.bundle.id',
       appAppleId // Your app's App Store ID
   );
   
   // Verify a transaction from the client
   const transaction = await verifier.verifyAndDecodeTransaction(jwsToken);
   ```

3. **Handle App Store Server Notifications V2:**
   ```javascript
   app.post('/webhook/apple', async (req, res) => {
       const { signedPayload } = req.body;
       const decoded = await verifier.verifyAndDecodeNotification(signedPayload);
       // Process notification...
   });
   ```

### Environment Variables

Configure your server with these environment variables:

| Variable | Description |
|----------|-------------|
| `APPLE_BUNDLE_ID` | Your app's bundle identifier |
| `APPLE_APPLE_ID` | Your app's App Store ID (for production) |
| `APPLE_ENVIRONMENT` | `sandbox` or `production` |
| `APPLE_PRIVATE_KEY_PATH` | Path to your .p8 key file |
| `APPLE_KEY_ID` | Key ID from App Store Connect |
| `APPLE_ISSUER_ID` | Issuer ID from App Store Connect |

## Legacy Files

The original StoreKit 1 Objective-C implementation has been archived in:
```
src/ios/_legacy_storekit1/
```

These files are kept for reference but are no longer used by the plugin.

## Troubleshooting

### "JWS verification failed"

- Ensure your server has network access to fetch Apple's root certificates
- Verify your bundle ID matches exactly
- Check that `APPLE_ENVIRONMENT` matches your build (sandbox vs production)

### Transactions not appearing

- StoreKit 2 requires iOS 15.0+ — check your deployment target
- Ensure the device is signed in with an Apple ID
- In sandbox, use a Sandbox Apple ID for testing

### appAccountToken not received

- The token must be a valid UUID format
- Set it during the `order()` call, not after
- Verify your backend is extracting it from the correct field in the decoded transaction

## Migration Checklist

- [ ] Update your minimum iOS deployment target to 15.0
- [ ] Update your minimum macOS deployment target to 12.0
- [ ] Update your backend to use `@apple/app-store-server-library`
- [ ] Update your webhook endpoint to handle V2 notifications
- [ ] Test purchases in sandbox environment
- [ ] Test restore purchases functionality
- [ ] Verify subscription renewal handling

