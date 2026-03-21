/**
 * Minimal cross-platform IAP service (Apple + Google) — Node/Express
 * - Apple: App Store Server Notifications v2 (signedPayload)
 * - Google: Real-time Developer Notifications (RTDN) Pub/Sub push
 * - “validate” endpoints you call from the client after purchase
 *
 * To RUN: node purchase_api.js --sandbox (SANDBOX) 
 * or RUN: node purchase_api.js (PRODUCTION)
 * 
 * tools.conf = {
 *  "iap": { //production configuration
		"port": 3335,
		"apple": {
			"file_path": "/var/www/priv/iap.apple.p8",
			"APPLE_ISSUER_ID": "AAAAAA-BBBB-CCCC-DDDDD-EEEEEEE",
			"APPLE_KEY_ID": "JAAAAAAAA",
			"APPLE_PRIVATE_KEY": [
				"-----BEGIN PRIVATE KEY-----",
				"line 1",
				"line 2",
				"line 3",
				"line 4",
				"-----END PRIVATE KEY-----"
			],
			"APPLE_BUNDLE_ID": "earth.actualize",
			"APPLE_APPLE_ID": "111111111",
			"APPLE_ENVIRONMENT": "production",
			"APPLE_NOTIFICATION_SECRET": "<secret>"
		}
    },
    "iap_sandbox": { //development configuration
		"port": 3336,
		"apple": {
			"file_path": "/var/www/priv/iap.apple_sandbox.p8",
			"APPLE_ISSUER_ID": "AAAAAA-BBBB-CCCC-DDDDD-EEEEEEE",
			"APPLE_KEY_ID": "JAAAAAAAA",
			"APPLE_PRIVATE_KEY": [
				"-----BEGIN PRIVATE KEY-----",
				"line 1",
				"line 2",
				"line 3",
				"line 4",
				"-----END PRIVATE KEY-----"
			],
			"APPLE_BUNDLE_ID": "earth.actualize.dev",
			"APPLE_APPLE_ID": "111111111",
			"APPLE_ENVIRONMENT": "sandbox",
			"APPLE_NOTIFICATION_SECRET": "<secret>"
		}
    }
}
/* TESTING YOUR APPLE CREDENTIALS
https://your_api_domain.com/iap/debug/apple-auth:3335/iap/debug/apple-auth
You will get a response like this:
{
    success: true,
    message: "Apple credentials validated successfully!",
    config: {
        keyId: "AAAAA",
        issuerId: "8ef698f0...",
        bundleId: "earth.actualize",
        environment: "sandbox",
        privateKeyPath: "/var/www/priv/iap.apple.p8",
        privateKeyExists: true
    },
    appleResponse: {
        testNotificationToken: "aaa-aaa-aaa-aa-aaa_aaaa"
    },
    note: "testNotificationToken can be used with getTestNotificationStatus() to verify webhook delivery",
    elapsedMs: 140,
    ts: "2026-03-19T03:25:15.436Z"
}
*/
/* TESTING YOUR APPLE CREDENTIALS
//PROD
https://your_api_domain.com/iap/debug/apple-auth:3335/iap/debug/apple-auth
//SANDBOX
https://your_api_domain.com/iap/debug/apple-auth:3336/iap/debug/apple-auth
You will get a response like this:
{
    success: true,
    message: "Apple credentials validated successfully!",
    config: {
        keyId: "AAAAA",
        issuerId: "8ef698f0...",
        bundleId: "earth.actualize",
        environment: "sandbox",
        privateKeyPath: "/var/www/priv/iap.apple.p8",
        privateKeyExists: true
    },
    appleResponse: {
        testNotificationToken: "aaa-aaa-aaa-aa-aaa_aaaa"
    },
    note: "testNotificationToken can be used with getTestNotificationStatus() to verify webhook delivery",
    elapsedMs: 140,
    ts: "2026-03-19T03:25:15.436Z"
}
*/
var version='1.2';
var use_environment = process.argv.includes('--sandbox') ? 'sandbox' : 'production';
var platform = 'actualize'; // || none
var mode='testing'; // || none
if(platform=='actualize'){/* ACTUALIZE ENVIRONMENT INIT (DO NOT REMOVE) */
    var tools = require('./tools.js');
    tools.init({
        file:__filename,
        home_path:'node',
        autoUpdate:'pm2'
    });
    tools.setVar('debug',true);
    tools.service.start('iap.js');
    tools.getEntitlement= async function(userId) {
        return new Promise((resolve, reject) => {
            var postfix='';
            if(use_environment=='sandbox') postfix='_sandbox';
            tools.db.connect(tools.conf.dbname, 'iap_entitlement'+postfix, async function(coll) {
                try {
                    // iap_entitlement is append-only — every validation/renewal inserts a new record.
                    // Sort by _id descending (natural insertion order) and take the first to get
                    // the most recent entitlement state for this user.
                    const doc = await coll.findOne({ uid: userId }, { sort: { _id: -1 } });
                    resolve(doc);
                } catch (err) {
                    console.error('[IAP:DB] Error getting entitlement:', err);
                    reject(err);
                }
            });
        });
    }
    tools.upsertEntitlement= async function(userId, patch) {
        patch.uid=userId;
        var postfix='';
        if(use_environment=='sandbox') postfix='_sandbox';
        var resp=await tools.formbuilder('iap_entitlement'+postfix,patch);
        tools.log(JSON.stringify(resp));
        return resp;
    }
    tools.upsertTransaction= async function(data) {
        var postfix='';
        if(use_environment=='sandbox') postfix='_sandbox';
        var resp=await tools.formbuilder('iap_transaction'+postfix, data);
        tools.log(JSON.stringify(resp));
        return resp;
    }
}else{/* NON - ACTUALIZE ENVIRONMENT INIT */
    if(mode=='testing'){ /* FOR TESTING AGAINST ACTUALIZE */
    var actualize_tools = require('./tools.js');
    actualize_tools.init({});
    }
    var tools = {
        getEntitlement: async function(userId) {
            return new Promise((resolve, reject) => {
                //your DB logic for getting entitlement, you will want to make an api call to separate logic
                resolve(null);
            })
        },
        upsertEntitlement: async function(userId, patch) {
            //your DB logic for upserting entitlement
            return new Promise((resolve, reject) => {
                //your DB logic for getting entitlement, you will want to make an api call to separate logic
                resolve(null);
            })
        },
        upsertTransaction: async function(data) {
            //your DB logic for upserting entitlement
            return new Promise((resolve, reject) => {
                //your DB logic for getting entitlement, you will want to make an api call to separate logic
                resolve(null);
            })
        },
        modules:{},
        conf:actualize_tools.conf,
        vars:{
            debug:true
        },
        log:console.log,
        fs:require('fs'),
        require:function(type){
            if (!this.modules[type]) this.modules[type] = require(type);
            return this.modules[type];
        },
        import:async function (type) {
            return new Promise((resolve) => {
                tools.log('loading module: ' + type);
                if (!tools.modules[type]) {
                    import(type).then((tmodule) => {
                        tools.log('module [' + type + '] loaded');
                        tools.modules[type] = tmodule;
                        resolve(tmodule);
                    }).catch((err) => {
                        console.error('Error loading module: ' + type, err);
                        process.exit(1);
                    });
                } else {
                    resolve(tools.modules[type]);
                }
            });
        }
    }
}
const express=tools.require('express');
var route_start='/iap';
if(use_environment==='sandbox'){
    route_start='/iap_sandbox';
}
//load in ios creds
//save p8 to local, accessible file
var iosVariables=[
    "APPLE_ISSUER_ID",
    "APPLE_KEY_ID",
    "APPLE_BUNDLE_ID",
    "APPLE_APPLE_ID",
    "APPLE_ENVIRONMENT",
    "APPLE_NOTIFICATION_SECRET"
];
if(use_environment==='sandbox'){
    console.log('\n\x1b[43m\x1b[30m' + '▀'.repeat(50) + '\x1b[0m');
    console.log('\x1b[43m\x1b[30m   ⚠  SANDBOX MODE — NOT PRODUCTION              \x1b[0m');
    console.log('\x1b[43m\x1b[30m' + '▄'.repeat(50) + '\x1b[0m\n');
}
switch(use_environment){
    case 'sandbox':
        var iap_config=tools.conf.iap_sandbox;
    break;
    case 'production':
        var iap_config=tools.conf.iap;
    break;
    default:
        console.log('Invalid environment: '+use_environment);
        process.exit(0);
    break;
}
if(iap_config.apple.APPLE_PRIVATE_KEY){
    var key='';
    key=iap_config.apple.APPLE_PRIVATE_KEY.join("\n");
    tools.fs.writeFileSync(iap_config.apple.file_path,key);
    process.env.APPLE_PRIVATE_KEY_PATH=iap_config.apple.file_path;
}else{
    console.warn('Missing Required iOS variable: APPLE_PRIVATE_KEY');
    process.exit();
}
for(var i=0;i<iosVariables.length;i++){
    var variable=iosVariables[i];
    if(!iap_config.apple[variable]){
        console.warn('Missing Required iOS variable: ',variable);
        process.exit();
    }else{
        process.env[variable]=iap_config.apple[variable];
        tools.log('Loading iOS variable: ',variable);
    }
}
const app = express();

// CORS — allow Cordova app (app://localhost) and standard web origins
app.use((req, res, next) => {
    const origin = req.headers.origin || '';
    const allowed = [
        'app://localhost',       // Cordova iOS / Android
        'ionic://localhost',     // Ionic Capacitor
        'http://localhost',
        'https://localhost',
    ];
    if (!origin || allowed.some(o => origin.startsWith(o)) || /^https?:\/\/.*\.actualize\.earth$/.test(origin)) {
        res.setHeader('Access-Control-Allow-Origin', origin || '*');
    }
    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
});

app.use(express.json({ limit: "2mb" }));
app.use(express.urlencoded({ extended: true, limit: "2mb" }));

/**
 * Request logging middleware
 * Logs full URL, method, headers, and body for replay purposes
 */
app.use((req, res, next) => {
    const fullUrl = `${req.protocol}://${req.get('host')}${req.originalUrl}`;
    const logEntry = {
        timestamp: new Date().toISOString(),
        method: req.method,
        fullUrl: fullUrl,
        path: req.path,
        query: req.query,
        headers: {
            'content-type': req.get('content-type'),
            'user-agent': req.get('user-agent'),
            'x-forwarded-for': req.get('x-forwarded-for'),
        },
        bodySize: JSON.stringify(req.body || {}).length,
    };

    tools.log('\n' + '='.repeat(80));
    tools.log('[IAP REQUEST] '+logEntry.method+' :: '+logEntry.fullUrl);
    tools.log('[IAP REQUEST] Time: '+ logEntry.timestamp);
    tools.log('[IAP REQUEST] Headers: ' + JSON.stringify(logEntry.headers));

    // Log body for POST requests (but truncate large payloads)
    if (req.method === 'POST' && req.body) {
        const bodyStr = JSON.stringify(req.body);
        if (bodyStr.length > 2000) {
            tools.log('[IAP REQUEST] Body (truncated): '+ bodyStr.substring(0, 2000) + '...[truncated]');
        } else {
            tools.log('[IAP REQUEST] Body: '+bodyStr);
        }
    }
    tools.log('='.repeat(80));

    // Store start time for response timing
    req._iapStartTime = Date.now();

    // Capture response
    const originalSend = res.send;
    res.send = function(body) {
        const elapsed = Date.now() - req._iapStartTime;
        tools.log(`[IAP RESPONSE] ${req.method} ${req.path} => ${res.statusCode} (${elapsed}ms)`);
        if (res.statusCode >= 400) {
            tools.log('[IAP RESPONSE] Error body: '+(typeof body === 'string' ? body : JSON.stringify(body)));
        }
        return originalSend.call(this, body);
    };

    next();
});
/** --------------------------
 * IAP Entitlement Database Storage
 * ---------------------------
 * Collection: iap_entitlement
 * Keyed by userId (id field)
 */
var iap={
    init:async function(){
        tools.log('loading iap service...');
        iap.googleapis= await tools.import("googleapis");
        // Use Apple's official library: @apple/app-store-server-library
        iap.AppStoreServerLib = await tools.import("@apple/app-store-server-library");
        // Initialize Apple verification after loading library
        await iap.initAppleVerifier();
        tools.log('✅ iap service loaded');
        iap.listen();
    },

    /**
     * Download Apple root certificates for JWS verification
     * These are required to verify the certificate chain in signed payloads from Apple
     */
    fetchAppleRootCertificates: async function() {
        const fetch = (await import('node-fetch')).default;
        const certUrls = [
            'https://www.apple.com/certificateauthority/AppleRootCA-G3.cer',
            'https://www.apple.com/certificateauthority/AppleRootCA-G2.cer'
        ];

        const certs = [];
        for (const url of certUrls) {
            try {
                tools.log(`[IAP:INIT] Downloading Apple root cert: ${url.split('/').pop()}...`);
                const response = await fetch(url);
                if (response.ok) {
                    const buffer = Buffer.from(await response.arrayBuffer());
                    certs.push(buffer);
                    tools.log(`[IAP:INIT] ✅ Downloaded Apple root cert: ${url.split('/').pop()} (${buffer.length} bytes)`);
                } else {
                    console.warn(`[IAP:INIT] ⚠️ Failed to download ${url}: HTTP ${response.status}`);
                }
            } catch (err) {
                console.warn(`[IAP:INIT] ⚠️ Failed to download ${url}: ${err.message}`);
            }
        }
        return certs;
    },

    /**
     * Initialize Apple SignedDataVerifier for JWS verification
     * This verifies that notifications and transactions are legitimately signed by Apple
     *
     * NOTE: We create verifiers for BOTH environments because:
     * - Sandbox purchases can generate production webhooks in some cases
     * - TestFlight uses production environment
     * - It's safer to try both than to fail
     */
    initAppleVerifier: async function() {
        const { SignedDataVerifier, Environment } = iap.AppStoreServerLib;
        const bundleId = process.env.APPLE_BUNDLE_ID;
        const appAppleId = process.env.APPLE_APPLE_ID ? Number(process.env.APPLE_APPLE_ID) : undefined;

        // Download Apple's root certificates for chain verification
        const appleRootCAs = await iap.fetchAppleRootCertificates();

        if (appleRootCAs.length === 0) {
            console.error('[IAP:INIT] ❌ Failed to download any Apple root certificates!');
            console.error('[IAP:INIT] JWS verification will fail without root certs.');
            throw new Error('Could not fetch Apple root certificates - cannot verify JWS payloads');
        }

        // Enable online checks for OCSP revocation checking
        const enableOnlineChecks = true;

        // Create verifier for the configured environment (primary)
        const primaryEnv = process.env.APPLE_ENVIRONMENT === 'production'
            ? Environment.PRODUCTION
            : Environment.SANDBOX;

        iap.signedDataVerifier = new SignedDataVerifier(
            appleRootCAs,
            enableOnlineChecks,
            primaryEnv,
            bundleId,
            appAppleId
        );

        // Create verifier for the alternate environment (fallback)
        const fallbackEnv = process.env.APPLE_ENVIRONMENT === 'production'
            ? Environment.SANDBOX
            : Environment.PRODUCTION;

        iap.signedDataVerifierFallback = new SignedDataVerifier(
            appleRootCAs,
            enableOnlineChecks,
            fallbackEnv,
            bundleId,
            appAppleId
        );

        tools.log(`[IAP:INIT] ✅ Apple SignedDataVerifier initialized with ${appleRootCAs.length} root certs`);
        tools.log(`[IAP:INIT]    Primary env: ${process.env.APPLE_ENVIRONMENT || 'sandbox'}`);
        tools.log(`[IAP:INIT]    Fallback env: ${process.env.APPLE_ENVIRONMENT === 'production' ? 'sandbox' : 'production'}`);
        tools.log(`[IAP:INIT]    BundleId: ${bundleId}`);
        tools.log(`[IAP:INIT]    AppAppleId: ${appAppleId || 'not set'}`);
    },

    /**
     * Decode a UUID back to the original user ID
     * Reverses the hex encoding done on the client (each char = 2 hex digits, null-padded)
     * Example: "55313233-3435-3637-3839-300000000000" -> "U1234567890"
     */
    uuidToUserId: function(uuid) {
        if (!uuid) return null;

        // Remove dashes to get 32 hex chars
        const hex = uuid.replace(/-/g, '');

        // Convert pairs of hex digits back to characters
        let userId = '';
        for (let i = 0; i < hex.length; i += 2) {
            const charCode = parseInt(hex.substring(i, i + 2), 16);
            if (charCode === 0) break; // Stop at null padding
            userId += String.fromCharCode(charCode);
        }
        return userId;
    },

    /**
     * Helper to extract meaningful error info from Apple's VerificationException
     * Apple's library throws VerificationException with .status (enum) not .message
     */
    formatVerificationError: function(err) {
        // VerificationStatus enum values from @apple/app-store-server-library
        const statusNames = {
            0: 'OK',
            1: 'VERIFICATION_FAILURE (signature/chain invalid)',
            2: 'RETRYABLE_VERIFICATION_FAILURE (network/OCSP issue)',
            3: 'INVALID_APP_IDENTIFIER (bundleId or appAppleId mismatch)',
            4: 'INVALID_ENVIRONMENT (sandbox vs production mismatch)',
            5: 'INVALID_CHAIN_LENGTH (cert chain wrong length)',
            6: 'INVALID_CERTIFICATE (cert invalid/expired)',
            7: 'FAILURE (general failure)'
        };

        if (err.status !== undefined) {
            const statusName = statusNames[err.status] || `UNKNOWN_STATUS_${err.status}`;
            let msg = `VerificationException: ${statusName}`;
            if (err.cause) {
                msg += ` | Cause: ${err.cause.message || err.cause}`;
            }
            return msg;
        }
        return err.message || String(err);
    },

    /**
     * Verify JWS with fallback to alternate environment
     * Tries primary environment first, then fallback
     */
    verifyWithFallback: async function(verifyFn, payload, type = 'notification') {
        const primaryEnv = process.env.APPLE_ENVIRONMENT || 'sandbox';
        const fallbackEnv = primaryEnv === 'production' ? 'sandbox' : 'production';

        // Try primary environment first
        try {
            tools.log(`[IAP:VERIFY] Trying ${type} verification with ${primaryEnv} environment...`);
            const result = await verifyFn(iap.signedDataVerifier, payload);
            tools.log(`[IAP:VERIFY] ✅ ${type} verified successfully with ${primaryEnv} environment`);
            return { result, environment: primaryEnv };
        } catch (primaryErr) {
            const primaryErrMsg = iap.formatVerificationError(primaryErr);
            tools.log(`[IAP:VERIFY] ❌ ${type} verification failed with ${primaryEnv}: ${primaryErrMsg}`);

            // Try fallback environment
            try {
                tools.log(`[IAP:VERIFY] Trying ${type} verification with ${fallbackEnv} environment (fallback)...`);
                const result = await verifyFn(iap.signedDataVerifierFallback, payload);
                tools.log(`[IAP:VERIFY] ✅ ${type} verified successfully with ${fallbackEnv} environment (fallback)`);
                tools.log(`[IAP:VERIFY] ⚠️  Consider updating APPLE_ENVIRONMENT to '${fallbackEnv}' in your config`);
                return { result, environment: fallbackEnv };
            } catch (fallbackErr) {
                const fallbackErrMsg = iap.formatVerificationError(fallbackErr);
                console.error(`[IAP:VERIFY] ❌ ${type} verification failed with BOTH environments`);
                console.error(`[IAP:VERIFY] Primary (${primaryEnv}) error: ${primaryErrMsg}`);
                console.error(`[IAP:VERIFY] Fallback (${fallbackEnv}) error: ${fallbackErrMsg}`);
                console.error(`[IAP:VERIFY] Config check - APPLE_BUNDLE_ID: ${process.env.APPLE_BUNDLE_ID}`);
                console.error(`[IAP:VERIFY] Config check - APPLE_APPLE_ID: ${process.env.APPLE_APPLE_ID}`);
                throw new Error(`Verification failed in both environments. Primary: ${primaryErrMsg}, Fallback: ${fallbackErrMsg}`);
            }
        }
    },

    /**
     * Structure:
     * entitlements.set(userKey, {
     *   source: "apple" | "google",
     *   productId: string,
     *   status: "active" | "expired" | "canceled" | "grace" | "paused" | "unknown",
     *   expiresAt: number | null, // ms epoch
     *   raw: object,              // last payload / response
     *   updatedAt: number,        // ms epoch
     * });
     */

    /**
     * Upsert IAP entitlement to database
     * @param {string} userId - User ID (primary key)
     * @param {object} patch - Fields to update
     * @returns {Promise<object>} - The updated entitlement document
     */
    upsertEntitlement: tools.upsertEntitlement,

    /**
     * Upserts a transaction record into the append-only iap_transaction ledger
     * @param {object} data - Transaction fields
     * @returns {Promise<object>} - The inserted document
     */
    upsertTransaction: tools.upsertTransaction,

    /**
     * Fetch a single Apple transaction from Apple's API and save it to the iap_transaction ledger.
     * Called internally after a webhook event that carries a transactionId.
     *
     * @param {string} transactionId - Apple transaction ID
     * @param {string} userId - Internal user ID
     * @returns {Promise<void>}
     */
    fetchAndSaveTransaction: async function(transactionId, userId, renewalInfo = null) {
        try {
            tools.log(`[IAP:TX:APPLE] fetchAndSaveTransaction: transactionId=${transactionId} userId=${userId}`);
            const api = iap.getAppleApiClient();
            const response = await api.getTransactionInfo(transactionId);
            const { result: tx, environment: verifiedEnv } = await iap.verifyWithFallback(
                async (verifier, payload) => verifier.verifyAndDecodeTransaction(payload),
                response.signedTransactionInfo,
                'transaction info'
            );

            // tx.price is the actual amount charged for this specific transaction, in milliunits.
            // Divide by 1000 for the real amount (e.g. 9990 = $9.99).
            // For prorated upgrades, Apple sets this to the prorated charge — not the full plan price.
            // For downgrades, Apple does NOT create a new transaction; the plan change is applied
            // at the next renewal. The upcoming renewal price lives in renewalInfo (passed from
            // the webhook which has already decoded both signedTransactionInfo + signedRenewalInfo).
            const priceMicros   = tx.price ?? null;           // actual amount charged NOW (milliunits)
            const priceCurrency = tx.currency ?? null;
            const amountPaid    = priceMicros !== null ? (priceMicros / 1000) : null;  // human-readable

            // renewalInfo fields — only present when called from a webhook that included signedRenewalInfo
            const renewalPrice        = renewalInfo?.renewalPrice        ?? null;  // upcoming renewal amount (milliunits)
            const renewalPricePaid    = renewalPrice !== null ? (renewalPrice / 1000) : null;
            const autoRenewProductId  = renewalInfo?.autoRenewProductId  ?? null;  // product switching TO (upgrade/downgrade)
            const autoRenewStatus     = renewalInfo?.autoRenewStatus     ?? null;  // 1=will renew, 0=cancelled

            tools.log(`[IAP:TX:APPLE] Decoded: productId=${tx.productId} priceMicros=${priceMicros} amountPaid=${amountPaid} currency=${priceCurrency} reason=${tx.transactionReason}`);
            if (renewalPrice !== null) {
                tools.log(`[IAP:TX:APPLE] Renewal info: renewalPrice=${renewalPrice} (=${renewalPricePaid} ${priceCurrency}) autoRenewProductId=${autoRenewProductId} autoRenewStatus=${autoRenewStatus}`);
            }

            await iap.upsertTransaction({
                id: tx.transactionId,
                uid: String(userId),
                platform: 'apple',
                originalTransactionId: tx.originalTransactionId,
                productId: tx.productId,
                // Actual charge for this transaction in milliunits (divide by 1000 for real amount).
                // Prorated for upgrades; $0 scenarios don't produce a transaction (downgrade → see renewalPrice).
                priceMicros,
                currency: priceCurrency,
                transactionReason: tx.transactionReason ?? null,
                purchaseDate: tx.purchaseDate ? new Date(tx.purchaseDate).toISOString() : null,
                environment: tx.environment ?? verifiedEnv ?? null,
                source: 'webhook',
                // Upcoming renewal context (populated on DID_CHANGE_RENEWAL_PRODUCT, etc.)
                renewalPrice,          // what they'll pay at next renewal (milliunits); null if no plan change
                autoRenewProductId,    // product they're switching TO; null if no change
                autoRenewStatus,       // 1=renewing, 0=cancelled
                raw: { tx, renewalInfo }
            });
            tools.log(`[IAP:TX:APPLE] ✅ Transaction saved: userId=${userId} transactionId=${tx.transactionId} amountPaid=${amountPaid} renewalPricePaid=${renewalPricePaid}`);
        } catch (e) {
            // Non-fatal — log the error but don't fail the webhook
            console.error(`[IAP:TX:APPLE] fetchAndSaveTransaction error (transactionId=${transactionId}):`, e.message);
        }
    },

    /**
     * Get IAP entitlement from database
     * @param {string} userId - User ID
     * @returns {Promise<object|null>} - The entitlement document or null
     */
    getEntitlement: tools.getEntitlement,

    /**
     * True when an Apple entitlement status should still grant ownership.
     * @param {string|null|undefined} status
     * @returns {boolean}
     */
    isAppleOwnedStatus: function(status) {
        return ['active', 'grace', 'will_expire'].includes(status || 'active');
    },

    /**
     * Build a plugin-compatible VerifiedPurchase object for Apple.
     * @param {object} params
     * @returns {object|null}
     */
    buildAppleVerifiedPurchase: function(params) {
        const productId = params?.productId;
        if (!productId) return null;

        // PHP onBeforeSave divides expiresAt by 1000 before storing (PHP time = seconds).
        // Normalize to milliseconds so Date.now() comparisons are correct.
        const expiresAt = iap.ensureMs(params?.expiresAt);
        const purchaseDate = iap.ensureMs(params?.purchaseDate);
        const transactionId = params?.transactionId;
        const ownedStatus = iap.isAppleOwnedStatus(params?.status);
        const isExpired = !ownedStatus || (!!expiresAt && expiresAt <= Date.now());

        const purchase = {
            id: productId,
            transactionId: transactionId || undefined,
            isExpired
        };

        if (purchaseDate !== null && purchaseDate !== undefined) {
            purchase.purchaseDate = purchaseDate;
        }
        if (expiresAt !== null && expiresAt !== undefined) {
            purchase.expiryDate = expiresAt;
        }
        if (params?.isAcknowledged !== null && params?.isAcknowledged !== undefined) {
            purchase.isAcknowledged = params.isAcknowledged;
        }

        return purchase;
    },

    /**
     * Build a plugin-compatible Apple validator success response.
     * @param {object} params
     * @returns {{ok: true, data: object}}
     */
    buildAppleValidatorResponse: function(params) {
        const data = {
            id: params?.receiptId || params?.productId || 'unknown',
            latest_receipt: true,
            transaction: params?.transaction || { type: 'ios-appstore' },
            collection: params?.verifiedPurchase ? [params.verifiedPurchase] : [],
            date: new Date().toISOString(),
            notificationType: params?.notificationType || null,
            subtype: params?.subtype || null
        };

        if (params?.warning) {
            data.warning = params.warning;
        }

        return { ok: true, data };
    },

    /**
     * Normalize a timestamp to milliseconds.
     * PHP's iap_entitlement onBeforeSave divides expiresAt by 1000 before storing,
     * so values read from DB are in seconds. This converts them back to milliseconds
     * for correct Date.now() comparisons and plugin compatibility.
     * @param {number|null|undefined} ts
     * @returns {number|null}
     */
    ensureMs: function(ts) {
        if (!ts) return ts;
        // 10-digit = seconds (up to ~year 2286), 13-digit = milliseconds
        return ts < 1e11 ? ts * 1000 : ts;
    },

    /** --------------------------
     * Google Play: Android Publisher API client
     * -------------------------- */
    getGoogleClient:function() {
        // Recommended: set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON file
        // with Android Publisher permissions for your Play Console project.
        const auth = new google.auth.GoogleAuth({
            scopes: ["https://www.googleapis.com/auth/androidpublisher"],
        });

        return google.androidpublisher({ version: "v3", auth });
    },
    googleGetSubscriptionV2:async function ({ packageName, token }) {
        const androidpublisher = iap.getGoogleClient();

        // purchases.subscriptionsv2.get
        // Path params: packageName, token
        const res = await androidpublisher.purchases.subscriptionsv2.get({
            packageName,
            token,
        });

        return res.data;
    },

    /** --------------------------
     * Helpers: normalize states
     * -------------------------- */
    normalizeGoogleState:function(purchaseV2) {
        // Google returns a SubscriptionPurchaseV2; states are nested.
        // We’ll do a practical best-effort mapping.
        // See Google docs for fields like subscriptionState, lineItems, etc. :contentReference[oaicite:3]{index=3}
        const state = purchaseV2?.subscriptionState || "SUBSCRIPTION_STATE_UNSPECIFIED";

        // Common values include ACTIVE, CANCELED, EXPIRED, IN_GRACE_PERIOD, ON_HOLD, PAUSED
        // (Exact enums may evolve; treat unknown safely.)
        switch (state) {
            case "SUBSCRIPTION_STATE_ACTIVE":
            return "active";
            case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
            return "grace";
            case "SUBSCRIPTION_STATE_ON_HOLD":
            return "paused";
            case "SUBSCRIPTION_STATE_PAUSED":
            return "paused";
            case "SUBSCRIPTION_STATE_CANCELED":
            // Could still be active until expiry; we’ll derive from expiry if available
            return "canceled";
            case "SUBSCRIPTION_STATE_EXPIRED":
            return "expired";
            default:
            return "unknown";
        }
    },
    deriveGoogleExpiryMs:function(purchaseV2) {
    // SubscriptionPurchaseV2 commonly includes lineItems with expiryTime in RFC3339.
        const lineItems = purchaseV2?.lineItems || [];
        const expiryStr =
            lineItems[0]?.expiryTime ||
            purchaseV2?.lineItems?.[0]?.expiryTime ||
            null;

        if (!expiryStr) return null;
        const ms = Date.parse(expiryStr);
        return Number.isFinite(ms) ? ms : null;
    },

    /** --------------------------
     * Apple: notifications v2 decode/verify
     * --------------------------
     * Apple sends:
     * { "signedPayload": "<JWS>" }
     * and you decode/verify server-side. :contentReference[oaicite:4]{index=4}
     *
     * NOTE: Signature verification requires Apple public keys / chain.
     * The library handles verification when configured properly.
     * If you want strict verification, also enforce bundleId / appAppleId checks.
     */
    normalizeAppleNotification:function(decoded, transactionInfo = null, renewalInfo = null) {
        console.log('normalizeAppleNotification', transactionInfo, renewalInfo);
        // decoded: ResponseBodyV2DecodedPayload from @apple/app-store-server-library
        // transactionInfo: JWSTransactionDecodedPayload (decoded separately)
        // renewalInfo: JWSRenewalInfoDecodedPayload (decoded separately)
        const notificationType = decoded?.notificationType || "UNKNOWN";
        const subtype = decoded?.subtype || null;
        const data = decoded?.data || {};

        // Extract key fields from the decoded transaction info
        const productId = transactionInfo?.productId || null;
        const originalTransactionId = transactionInfo?.originalTransactionId || null;
        const transactionId = transactionInfo?.transactionId || null;
        const appAccountToken = transactionInfo?.appAccountToken || null;
        const expiresDate = transactionInfo?.expiresDate || null;
        const purchaseDate = transactionInfo?.purchaseDate || null;
        const environment = data?.environment || transactionInfo?.environment || null;

        // Price fields (added in App Store Server API 1.10+, June 2023)
        // price is in milliunits (divide by 1000 for actual amount, e.g. 9990 = $9.99)
        const priceMicros = transactionInfo?.price || null;
        const currency = transactionInfo?.currency || null;
        const offerDiscountType = transactionInfo?.offerDiscountType || null;

        // Renewal info fields — key for upgrade/downgrade (DID_CHANGE_RENEWAL_PRODUCT events)
        // renewalPrice: price at next renewal in milliunits (may differ from current priceMicros after a plan switch)
        // autoRenewProductId: the product ID they are switching TO (null if not changing)
        // autoRenewStatus: 1 = will auto-renew, 0 = user has turned off auto-renew (cancellation pending)
        const renewalPrice = renewalInfo?.renewalPrice ?? 0;
        const autoRenewProductId = renewalInfo?.autoRenewProductId || null;
        const autoRenewStatus = renewalInfo?.autoRenewStatus ?? null;

        let status = "unknown";

        if (["DID_RENEW", "DID_RECOVER", "SUBSCRIBED"].includes(notificationType)) status = "active";
        if (["EXPIRED", "DID_FAIL_TO_RENEW", "GRACE_PERIOD_EXPIRED"].includes(notificationType)) status = "expired";
        if (["CANCEL", "REFUND", "REVOKE"].includes(notificationType)) status = "canceled";
        if (notificationType === "DID_CHANGE_RENEWAL_STATUS" || notificationType === "DID_CHANGE_RENEWAL_PREF") {
            status = renewalInfo?.autoRenewStatus === 0 ? "will_expire" : "active";
        }
        if (notificationType === "DID_ENTER_GRACE_PERIOD") status = "grace";

        // For immediate upgrades (DID_CHANGE_RENEWAL_PREF + UPGRADE subtype),
        // Apple's transactionInfo still references the OLD product, but the user
        // is already on the new tier. Use autoRenewProductId as the effective
        // productId so the entitlement reflects the upgrade immediately.
        let effectiveProductId = productId;
        if (notificationType === "DID_CHANGE_RENEWAL_PREF" && subtype === "UPGRADE" && autoRenewProductId) {
            console.log(`[normalizeAppleNotification] UPGRADE detected: switching productId from ${productId} to ${autoRenewProductId}`);
            effectiveProductId = autoRenewProductId;
        }

        return {
            notificationType, subtype, status, productId: effectiveProductId, originalTransactionId,
            transactionId, appAccountToken, expiresDate, purchaseDate, environment,
            priceMicros, currency, offerDiscountType,
            renewalPrice, autoRenewProductId, autoRenewStatus,
            transactionInfo, renewalInfo
        };
    },

    /** --------------------------
     * Apple API Client (for debug/validation)
     * -------------------------- */

    getAppleApiClient:function() {
        const { AppStoreServerAPIClient, Environment } = iap.AppStoreServerLib;
        const encodedKey = tools.fs.readFileSync(process.env.APPLE_PRIVATE_KEY_PATH, 'utf8');
        const keyId = process.env.APPLE_KEY_ID;
        const issuerId = process.env.APPLE_ISSUER_ID;
        const bundleId = process.env.APPLE_BUNDLE_ID;

        // Environment enum: PRODUCTION or SANDBOX
        const environment = process.env.APPLE_ENVIRONMENT === 'production'
            ? Environment.PRODUCTION
            : Environment.SANDBOX;

        return new AppStoreServerAPIClient(encodedKey, keyId, issuerId, bundleId, environment);
    },
    listen:function(){
        /** --------------------------
         * Routes
         * -------------------------- */

        /**
         * Health check
         */
        app.get(route_start+"/health", (_req, res) => {
            res.json({ ok: true, ts: new Date().toISOString() });
        });

        /**
         * Debug: Apple Auth Test
         *
         * Tests Apple credentials by:
         * 1. Generating a JWT
         * 2. Calling Apple's sandbox/production API
         * 3. Returns success or detailed error
         *
         * This is useful for verifying your credentials work before wiring up the rest.
         */
        app.get(route_start+"/debug/apple-auth", async (_req, res) => {
        try {
            const startTime = Date.now();

            // Log config (redacted)
            const config = {
            keyId: process.env.APPLE_KEY_ID,
            issuerId: process.env.APPLE_ISSUER_ID ? process.env.APPLE_ISSUER_ID.substring(0,8) + '...' : null,
            bundleId: process.env.APPLE_BUNDLE_ID,
            environment: process.env.APPLE_ENVIRONMENT,
            privateKeyPath: process.env.APPLE_PRIVATE_KEY_PATH,
            privateKeyExists: tools.fs.existsSync(process.env.APPLE_PRIVATE_KEY_PATH),
            };

            tools.log('[IAP Debug] Testing Apple auth with config:',config);

            // Create API client
            const api = iap.getAppleApiClient();

            // Request a test notification - this validates the JWT and credentials
            // Apple will respond with a testNotificationToken if successful
            tools.log('[IAP Debug] Calling requestTestNotification()...');
            const response = await api.requestTestNotification();

            const elapsed = Date.now() - startTime;
            tools.log('[IAP Debug] Success! Response:', response);

            res.json({
            success: true,
            message: 'Apple credentials validated successfully!',
            config: config,
            appleResponse: response,
            note: 'testNotificationToken can be used with getTestNotificationStatus() to verify webhook delivery',
            elapsedMs: elapsed,
            ts: new Date().toISOString()
            });

        } catch (e) {
            console.error('[IAP Debug] Apple auth test failed:', e);

            // Parse detailed error info
            const errorDetails = {
            message: e?.message || String(e),
            name: e?.name,
            code: e?.code,
            status: e?.response?.status,
            statusText: e?.response?.statusText,
            responseData: null
            };

            // Try to get response body for API errors
            if (e?.response?.data) {
            errorDetails.responseData = e.response.data;
            }

            res.status(500).json({
            success: false,
            error: 'Apple auth test failed',
            details: errorDetails,
            config: {
                keyId: process.env.APPLE_KEY_ID,
                issuerId: process.env.APPLE_ISSUER_ID ? process.env.APPLE_ISSUER_ID.substring(0,8) + '...' : null,
                bundleId: process.env.APPLE_BUNDLE_ID,
                environment: process.env.APPLE_ENVIRONMENT,
                privateKeyExists: tools.fs.existsSync(process.env.APPLE_PRIVATE_KEY_PATH || ''),
            },
            troubleshooting: [
                'Check that APPLE_KEY_ID matches the key ID in App Store Connect',
                'Check that APPLE_ISSUER_ID is correct (from App Store Connect API Keys)',
                'Verify the private key (.p8) file is valid and matches the key ID',
                'Ensure APPLE_BUNDLE_ID matches your app bundle identifier',
                'For sandbox testing, set APPLE_ENVIRONMENT=sandbox'
            ],
            ts: new Date().toISOString()
            });
        }
        });

        /**
         * Entitlement lookup
         * Example: /status?userId=123
         */
        app.get(route_start+"/status", async (req, res) => {
            const userId = req.query.userId;
            if (!userId) return res.status(400).json({ error: "Missing userId" });
            try {
                const entitlement = await iap.getEntitlement(String(userId));
                res.json(entitlement || null);
            } catch (err) {
                console.error('[IAP:STATUS] Error:', err);
                res.status(500).json({ error: "Database error" });
            }
        });

        /**
         * Validate Apple purchase (client->server) - StoreKit 2
         * Verifies JWS transaction tokens using Apple's SignedDataVerifier
         * Also supports CdvPurchase format for backward compatibility
         */
        app.post(route_start+"/validate/apple", async (req, res) => {
            try {
                // Construct replay URL
                const replayUrl = `${req.protocol}://${req.get('host')}${req.originalUrl}`;
                tools.log('\n[IAP:APPLE:VALIDATE] ============= START =============');
                tools.log('[IAP:APPLE:VALIDATE] Replay URL:', replayUrl);
                tools.log('[IAP:APPLE:VALIDATE] Replay curl command:');
                tools.log(`curl -X POST "${replayUrl}" -H "Content-Type: application/json" -d '${JSON.stringify(req.body)}'`);
                tools.log('[IAP:APPLE:VALIDATE] Raw body keys:', Object.keys(req.body || {}));

                // Log specific fields for debugging
                tools.log('[IAP:APPLE:VALIDATE] Body analysis:',{
                    hasUserId: !!req.body.userId,
                    hasAdditionalData: !!req.body.additionalData,
                    hasApplicationUsername: !!req.body.additionalData?.applicationUsername,
                    hasTransaction: !!req.body.transaction,
                    hasSignedTransaction: !!req.body.signedTransaction || !!req.body.transaction?.signedTransaction,
                    hasAppStoreReceipt: !!req.body.transaction?.appStoreReceipt,
                    hasProducts: !!req.body.products,
                    productsCount: req.body.products?.length || 0,
                    queryToken: req.query.token || null,
                });

                // Support both direct format and CdvPurchase format
                let userId = req.body.userId;
                let signedTransaction = req.body.signedTransaction;
                let productId = req.body.productId;
                let originalTransactionId = req.body.originalTransactionId;
                let expiresAtMs = req.body.expiresAtMs;

                // CdvPurchase format: additionalData.applicationUsername, transaction.appStoreReceipt
                if (!userId && req.body.additionalData?.applicationUsername) {
                    userId = iap.uuidToUserId(req.body.additionalData.applicationUsername);
                    tools.log('[IAP:APPLE:VALIDATE] Found userId in additionalData.applicationUsername:', userId);
                }
                // CdvPurchase format: transaction object (StoreKit 2 sends signedTransaction here)
                if (req.body.transaction) {
                    tools.log('[IAP:APPLE:VALIDATE] Transaction object found:',{
                        type: req.body.transaction.type,
                        id: req.body.transaction.id,
                        hasSignedTransaction: !!req.body.transaction.signedTransaction,
                        signedTransactionLength: req.body.transaction.signedTransaction?.length || 0,
                        hasAppStoreReceipt: !!req.body.transaction.appStoreReceipt,
                        appStoreReceiptLength: req.body.transaction.appStoreReceipt?.length || 0,
                    });

                    // StoreKit 2: prefer JWS token from transaction object
                    if (!signedTransaction && req.body.transaction.signedTransaction) {
                        signedTransaction = req.body.transaction.signedTransaction;
                        tools.log('[IAP:APPLE:VALIDATE] Using signedTransaction from transaction object, length:', signedTransaction.length);
                    }
                    if (!productId && req.body.transaction.productId) {
                        productId = req.body.transaction.productId;
                    }
                    if (!originalTransactionId && req.body.transaction.id) {
                        originalTransactionId = req.body.transaction.id;
                    }
                }

                tools.log('[IAP:APPLE:VALIDATE] Extracted values:', { userId, productId, originalTransactionId, hasSignedTransaction: !!signedTransaction });

                if (!userId) {
                    tools.log('[IAP:APPLE:VALIDATE] ERROR: Missing userId');
                    tools.log('[IAP:APPLE:VALIDATE] ============= END (400) =============\n');
                    return res.status(400).json({ ok: false, code: 400, error: "Missing userId" });
                }

                // StoreKit 2: verify JWS transaction (with environment fallback)
                if (signedTransaction) {
                    tools.log('[IAP:APPLE:VALIDATE] Attempting JWS verification...');
                    try {
                        const { result: tx, environment: verifiedEnv } = await iap.verifyWithFallback(
                            async (verifier, payload) => verifier.verifyAndDecodeTransaction(payload),
                            signedTransaction,
                            'transaction'
                        );

                        tools.log('[IAP:APPLE:VALIDATE] JWS verification SUCCESS (env:'+ verifiedEnv + ')');
                        // Price fields (Apple milliunits - divide by 1000 for actual amount)
                        const priceMicros = tx.price || null;
                        const currency = tx.currency || null;
                        const offerDiscountType = tx.offerDiscountType || null;

                        tools.log('[IAP:APPLE:VALIDATE] Decoded transaction:', {
                            transactionId: tx.transactionId,
                            originalTransactionId: tx.originalTransactionId,
                            productId: tx.productId,
                            type: tx.type,
                            environment: tx.environment,
                            purchaseDate: tx.purchaseDate,
                            expiresDate: tx.expiresDate,
                            revocationDate: tx.revocationDate,
                            appAccountToken: tx.appAccountToken,
                            priceMicros, currency, offerDiscountType
                        });

                        const purchaseDate = tx.purchaseDate ? new Date(tx.purchaseDate).getTime() : null;
                        const expiresAt = tx.expiresDate ? new Date(tx.expiresDate).getTime() : null;
                        let status = 'active';
                        if (tx.revocationDate) status = 'revoked';
                        else if (expiresAt && expiresAt < Date.now()) status = 'expired';

                        tools.log('[IAP:APPLE:VALIDATE] Computed status:', status);
                        tools.log('[IAP:APPLE:VALIDATE] expiresAt:'+ expiresAt);

                        // Preserve webhook-set renewal fields (autoRenewProductId, renewalPrice,
                        // autoRenewStatus) so that a validate call doesn't clobber a pending
                        // upgrade/downgrade recorded by DID_CHANGE_RENEWAL_PREF webhook.
                        const existingEntitlement = await iap.getEntitlement(String(userId));
                        const preservedRenewalFields = {};
                        if (existingEntitlement) {
                            if (existingEntitlement.autoRenewProductId) {
                                preservedRenewalFields.autoRenewProductId = existingEntitlement.autoRenewProductId;
                            }
                            if (existingEntitlement.renewalPrice != null) {
                                preservedRenewalFields.renewalPrice = existingEntitlement.renewalPrice;
                            }
                            if (existingEntitlement.autoRenewStatus != null) {
                                preservedRenewalFields.autoRenewStatus = existingEntitlement.autoRenewStatus;
                            }
                            tools.log('[IAP:APPLE:VALIDATE] Preserving renewal fields from existing entitlement:', JSON.stringify(preservedRenewalFields));
                        }

                        await iap.upsertEntitlement(String(userId), {
                            source: "apple",
                            productId: tx.productId,
                            status:status,
                            expiresAt: expiresAt,
                            priceMicros:priceMicros,
                            currency:currency,
                            offerDiscountType:offerDiscountType,
                            ...preservedRenewalFields,
                            raw: {
                                source:'validate',
                                transactionId: tx.transactionId,
                                originalTransactionId: tx.originalTransactionId,
                                type: tx.type,
                                appAccountToken: tx.appAccountToken,
                                environment: tx.environment,
                                verifiedEnv:verifiedEnv,
                                verified: true,
                                priceMicros: priceMicros,
                                currency: currency,
                                offerDiscountType: offerDiscountType
                            }
                        });
                        tools.log('[IAP:APPLE:VALIDATE] Entitlement saved to database for userId:', userId);
                        if(status=='expired'){
                            tools.log('[IAP:APPLE:VALIDATE] ============= END (400) =============\n');
                            return res.json({ ok: false, code: 400, message: "Subscription expired" });
                        }
                        const verifiedPurchase = iap.buildAppleVerifiedPurchase({
                            productId: tx.productId,
                            transactionId: tx.transactionId,
                            purchaseDate,
                            expiresAt,
                            status
                        });
                        const response = iap.buildAppleValidatorResponse({
                            productId: tx.productId,
                            receiptId: tx.productId || tx.originalTransactionId || tx.transactionId,
                            transaction: {
                                type: 'ios-appstore',
                                id: tx.originalTransactionId || tx.transactionId,
                                transactionId: tx.transactionId,
                                originalTransactionId: tx.originalTransactionId,
                                productId: tx.productId,
                                purchaseDate,
                                expiresDate: expiresAt,
                                status,
                                environment: tx.environment,
                                verifiedEnv
                            },
                            verifiedPurchase,
                            notificationType: null,
                            subtype: null
                        });
                        tools.log('[IAP:APPLE:VALIDATE] Sending response:',JSON.stringify(response));
                        tools.log('[IAP:APPLE:VALIDATE] ============= END (200) =============\n');
                        return res.json(response);
                    } catch (err) {
                        console.error('[IAP:APPLE:VALIDATE] JWS verification FAILED:',err.message);
                        console.error('[IAP:APPLE:VALIDATE] Full error:', err);
                        tools.log('[IAP:APPLE:VALIDATE] ============= END (400) =============\n');
                        return res.status(400).json({ ok: false, code: 400, message: "JWS verification failed: " + err?.message });
                    }
                }

                // Legacy/CdvPurchase mode (Base64 receipt - trust and acknowledge)
                tools.log('[IAP:APPLE:VALIDATE] No signedTransaction - using legacy/CdvPurchase mode');
                tools.log('[IAP:APPLE:VALIDATE] Acknowledging receipt for user:',userId);

                // Extract productId from the first product if available
                if (!productId && req.body.products?.[0]?.id) {
                    productId = req.body.products[0].id;
                    tools.log('[IAP:APPLE:VALIDATE] Extracted productId from products array:',productId);
                }

                const existingEntitlement = await iap.getEntitlement(String(userId));
                const appleEntitlement = existingEntitlement?.source === 'apple' ? existingEntitlement : null;
                let responseProductId = appleEntitlement?.productId || productId || null;
                let responseTransactionId = appleEntitlement?.raw?.transactionId || null;
                let responseOriginalTransactionId = originalTransactionId || appleEntitlement?.raw?.originalTransactionId || responseTransactionId;
                let responsePurchaseDate = appleEntitlement?.raw?.purchaseDate ? new Date(appleEntitlement.raw.purchaseDate).getTime() : null;
                // DB stores expiresAt in seconds (PHP onBeforeSave divides by 1000); convert back to ms.
                let responseExpiresAt = appleEntitlement?.expiresAt != null ? iap.ensureMs(appleEntitlement.expiresAt) : (expiresAtMs ?? null);
                let responseStatus = appleEntitlement?.status || 'active';

                if (appleEntitlement) {
                    tools.log('[IAP:APPLE:VALIDATE] Using stored Apple entitlement for legacy response:', {
                        productId: appleEntitlement.productId,
                        status: appleEntitlement.status,
                        expiresAt: appleEntitlement.expiresAt,
                        transactionId: appleEntitlement.raw?.transactionId,
                        originalTransactionId: appleEntitlement.raw?.originalTransactionId
                    });
                }

                // For CdvPurchase compatibility, we acknowledge the receipt
                if (!appleEntitlement && productId) {
                    responseStatus = responseExpiresAt && responseExpiresAt <= Date.now() ? 'expired' : 'active';
                    await iap.upsertEntitlement(String(userId), {
                        source: "apple", productId,
                        status: responseStatus,
                        expiresAt: responseExpiresAt,
                        raw: { originalTransactionId: originalTransactionId ?? null, verified: false }
                    });
                    tools.log('[IAP:APPLE:VALIDATE] Entitlement saved to database (legacy mode) for userId:'+ userId+' productId:'+productId);
                } else if (!responseProductId) {
                    tools.log('[IAP:APPLE:VALIDATE] WARNING: No productId found, entitlement not saved');
                }

                const verifiedPurchase = iap.buildAppleVerifiedPurchase({
                    productId: responseProductId,
                    transactionId: responseTransactionId || responseOriginalTransactionId,
                    purchaseDate: responsePurchaseDate,
                    expiresAt: responseExpiresAt,
                    status: responseStatus,
                    isAcknowledged: !!responseProductId
                });

                const response = iap.buildAppleValidatorResponse({
                    productId: responseProductId,
                    receiptId: responseProductId || responseOriginalTransactionId || 'unknown',
                    transaction: {
                        type: 'ios-appstore',
                        id: responseOriginalTransactionId || responseTransactionId || responseProductId || 'unknown',
                        transactionId: responseTransactionId || undefined,
                        originalTransactionId: responseOriginalTransactionId || undefined,
                        productId: responseProductId || undefined,
                        purchaseDate: responsePurchaseDate || undefined,
                        expiresDate: responseExpiresAt || undefined,
                        status: responseStatus
                    },
                    verifiedPurchase,
                    warning: appleEntitlement ? 'Validated using stored Apple entitlement state.' : undefined,
                    notificationType: null,
                    subtype: null
                });
                tools.log('[IAP:APPLE:VALIDATE] Sending legacy response:', JSON.stringify(response));
                tools.log('[IAP:APPLE:VALIDATE] ============= END (200) =============\n');
                res.json(response);
            } catch (e) {
                console.error('[IAP:APPLE:VALIDATE] Unexpected error:', e);
                tools.log('[IAP:APPLE:VALIDATE] ============= END (500) =============\n');
                res.status(500).json({ error: e?.message || String(e) });
            }
        });

        /**
         * Apple Server Notifications v2 webhook
         * Uses SignedDataVerifier to verify notifications are from Apple
         * Tries both sandbox and production environments for robustness
         */
        app.post(route_start+"/webhook/apple", async (req, res) => {
        try {
            tools.log('\n[IAP:WEBHOOK:APPLE] ============= START =============');

            const { signedPayload } = req.body || {};
            if (!signedPayload) {
                tools.log('[IAP:WEBHOOK:APPLE] ERROR: Missing signedPayload');
                tools.log('[IAP:WEBHOOK:APPLE] ============= END (400) =============\n');
                return res.status(400).json({ error: "Missing signedPayload" });
            }

            tools.log(`[IAP:WEBHOOK:APPLE] signedPayload length: ${signedPayload.length}`);

            // Try to decode the header to see which environment it's from (for logging)
            try {
                const headerB64 = signedPayload.split('.')[0];
                const header = JSON.parse(Buffer.from(headerB64, 'base64').toString('utf8'));
                tools.log(`[IAP:WEBHOOK:APPLE] JWS Header alg: ${header.alg}`);
                if (header.x5c && header.x5c[0]) {
                    // Try to extract cert info
                    const certB64 = header.x5c[0];
                    const certInfo = Buffer.from(certB64, 'base64').toString('utf8');
                    if (certInfo.includes('Prod')) {
                        tools.log('[IAP:WEBHOOK:APPLE] Certificate indicates: PRODUCTION');
                    } else if (certInfo.includes('Sandbox')) {
                        tools.log('[IAP:WEBHOOK:APPLE] Certificate indicates: SANDBOX');
                    }
                }
            } catch (headerErr) {
                tools.log(`[IAP:WEBHOOK:APPLE] Could not parse JWS header: ${headerErr.message}`);
            }

            // Verify & decode using Apple's SignedDataVerifier (with fallback to other environment)
            const { result: decoded, environment: verifiedEnv } = await iap.verifyWithFallback(
                async (verifier, payload) => verifier.verifyAndDecodeNotification(payload),
                signedPayload,
                'webhook notification'
            );

            tools.log(`[IAP:WEBHOOK:APPLE] Verified with environment: ${verifiedEnv}`);
            tools.log(`[IAP:WEBHOOK:APPLE] Notification type: ${decoded.notificationType} / ${decoded.subtype || 'none'}`);

            // The signedTransactionInfo and signedRenewalInfo are STILL JWS strings that need separate decoding
            let transactionInfo = null;
            let renewalInfo = null;

            if (decoded?.data?.signedTransactionInfo) {
                tools.log(`[IAP:WEBHOOK:APPLE] Decoding nested signedTransactionInfo...`);
                try {
                    const { result: txn } = await iap.verifyWithFallback(
                        async (verifier, payload) => verifier.verifyAndDecodeTransaction(payload),
                        decoded.data.signedTransactionInfo,
                        'transaction info'
                    );
                    transactionInfo = txn;
                    tools.log(`[IAP:WEBHOOK:APPLE] Transaction decoded: productId=${txn.productId}, transactionId=${txn.transactionId}, appAccountToken=${txn.appAccountToken || 'none'}`);
                } catch (txnErr) {
                    tools.log(`[IAP:WEBHOOK:APPLE] WARNING: Could not decode signedTransactionInfo: ${txnErr.message}`);
                }
            }

            if (decoded?.data?.signedRenewalInfo) {
                tools.log(`[IAP:WEBHOOK:APPLE] Decoding nested signedRenewalInfo...`);
                try {
                    const { result: renewal } = await iap.verifyWithFallback(
                        async (verifier, payload) => verifier.verifyAndDecodeRenewalInfo(payload),
                        decoded.data.signedRenewalInfo,
                        'renewal info'
                    );
                    renewalInfo = renewal;
                    tools.log(`[IAP:WEBHOOK:APPLE] Renewal decoded: autoRenewStatus=${renewal.autoRenewStatus}`);
                } catch (renewErr) {
                    tools.log(`[IAP:WEBHOOK:APPLE] WARNING: Could not decode signedRenewalInfo: ${renewErr.message}`);
                }
            }

            const norm = iap.normalizeAppleNotification(decoded, transactionInfo, renewalInfo);
            tools.log(`[IAP:WEBHOOK:APPLE] Normalized: type=${norm.notificationType}, subtype=${norm.subtype || 'none'}, status=${norm.status}, productId=${norm.productId}, transactionId=${norm.transactionId}, originalTransactionId=${norm.originalTransactionId}, appAccountToken=${norm.appAccountToken || 'none'}`);

            if (norm.notificationType === "TEST") {
                tools.log('[IAP:WEBHOOK:APPLE] TEST notification received OK');
                tools.log('[IAP:WEBHOOK:APPLE] ============= END (200) =============\n');
                return res.json({ ok: true });
            }

            // User ID from appAccountToken (set during purchase) or query param
            // appAccountToken is a UUID that encodes the userId (each char = 2 hex digits)
            const rawAppAccountToken = norm.appAccountToken;
            const decodedUserId = rawAppAccountToken ? iap.uuidToUserId(rawAppAccountToken) : null;
            const userId = decodedUserId || req.query.userId;
            tools.log(`[IAP:WEBHOOK:APPLE] appAccountToken: ${rawAppAccountToken || '(not set)'}`);
            tools.log(`[IAP:WEBHOOK:APPLE] decoded userId: ${decodedUserId || '(none)'}`);
            tools.log(`[IAP:WEBHOOK:APPLE] final userId: ${userId || '(not found)'}`);

            if (!userId) {
                console.warn("[IAP:WEBHOOK:APPLE] No userId found - entitlement NOT saved");
                tools.log('[IAP:WEBHOOK:APPLE] ============= END (200) =============\n');
                return res.json({ ok: true, note: "No userId; not stored" });
            }

            const expiresAt = norm.expiresDate ? new Date(norm.expiresDate).getTime() : null;

            // If productId is missing, try to get it from existing entitlement
            let productId = norm.productId;
            if (!productId) {
                const existingEntitlement = await iap.getEntitlement(String(userId));
                productId = existingEntitlement?.productId || "unknown";
            }

            await iap.upsertEntitlement(String(userId), {
                source: "apple",
                productId: norm.productId || productId,
                status: norm.status,
                expiresAt,
                // Price fields (Apple milliunits - divide by 1000 for actual amount)
                priceMicros: (norm.renewalPrice) ? norm.renewalPrice : norm.priceMicros,
                currency: norm.currency,
                offerDiscountType: norm.offerDiscountType,
                // Renewal / plan-change fields (populated on DID_CHANGE_RENEWAL_PRODUCT, etc.)
                renewalPrice: norm.renewalPrice,
                autoRenewProductId: norm.autoRenewProductId,
                autoRenewStatus: norm.autoRenewStatus,
                raw: {
                    source: 'webhook',
                    transactionId: norm.transactionId, originalTransactionId: norm.originalTransactionId,
                    notificationType: norm.notificationType, subtype: norm.subtype,
                    environment: norm.environment, verifiedEnv, lastUpdated: new Date().toISOString(), verified: true,
                    priceMicros: norm.priceMicros, currency: norm.currency, offerDiscountType: norm.offerDiscountType,
                    renewalPrice: norm.renewalPrice, autoRenewProductId: norm.autoRenewProductId, autoRenewStatus: norm.autoRenewStatus
                }
            });

            tools.log(`[IAP:WEBHOOK:APPLE] ✅ Entitlement saved to database: userId=${userId}, status=${norm.status}, productId=${productId}`);

            // Persist the individual billing event to the transaction ledger (non-fatal).
            // Pass renewalInfo so fetchAndSaveTransaction can record the upcoming renewal price
            // and autoRenewProductId — critical for downgrades where there is no charge NOW
            // but the next renewal price and target product differ from the current transaction.
            if (norm.transactionId) {
                iap.fetchAndSaveTransaction(norm.transactionId, userId, renewalInfo);
            }

            tools.log('[IAP:WEBHOOK:APPLE] ============= END (200) =============\n');
            res.json({ ok: true });
        } catch (e) {
            console.error("[IAP:WEBHOOK:APPLE] ERROR:", e.message);
            console.error("[IAP:WEBHOOK:APPLE] Full error:", e);
            tools.log('[IAP:WEBHOOK:APPLE] ============= END (500) =============\n');
            res.status(500).json({ error: e?.message || String(e) });
        }
        });

        /**
         * Validate Google purchase (client->server)
         * Body: { userId, packageName, purchaseToken }
         *
         * This queries purchases.subscriptionsv2.get :contentReference[oaicite:7]{index=7}
         */
        app.post(route_start+"/validate/google", async (req, res) => {
        try {
            const { userId, packageName, purchaseToken } = req.body || {};
            if (!userId) return res.status(400).json({ error: "Missing userId" });
            if (!packageName) return res.status(400).json({ error: "Missing packageName" });
            if (!purchaseToken) return res.status(400).json({ error: "Missing purchaseToken" });

            const purchaseV2 = await iap.googleGetSubscriptionV2({
            packageName,
            token: purchaseToken,
            });

            const status = iap.normalizeGoogleState(purchaseV2);
            const expiresAt = iap.deriveGoogleExpiryMs(purchaseV2);

            // productId is in lineItems[].productId in many responses
            const productId = purchaseV2?.lineItems?.[0]?.productId || "unknown";

            const entitlement = await iap.upsertEntitlement(String(userId), {
                source: "google",
                productId,
                status: expiresAt && expiresAt > Date.now() ? "active" : status,
                expiresAt,
                raw: purchaseV2,
            });

            res.json({ ok: true, entitlement });
        } catch (e) {
            console.error("Google validate error", e);
            res.status(500).json({ error: e?.message || String(e) });
        }
        });

        /**
         * Restore Apple purchases
         *
         * Called when user wants to restore purchases on a new device or after reinstall.
         * Client should call StoreKit 2's Transaction.currentEntitlements to get all active
         * entitlements, then send the JWS tokens here for verification.
         *
         * Body: {
         *   userId: string,                    // Required - the user's ID
         *   transactions: [                    // Array of JWS transaction tokens
         *     { signedTransaction: string },   // From Transaction.currentEntitlements
         *     ...
         *   ]
         * }
         *
         * Alternative format (single transaction):
         * Body: { userId: string, signedTransaction: string }
         */
        app.post(route_start+"/restore/apple", async (req, res) => {
            try {
                tools.log('\n[IAP:RESTORE:APPLE] ============= START =============');
                tools.log('[IAP:RESTORE:APPLE] Body keys:', Object.keys(req.body || {}));

                const { userId, transactions, signedTransaction } = req.body || {};

                if (!userId) {
                    tools.log('[IAP:RESTORE:APPLE] ERROR: Missing userId');
                    tools.log('[IAP:RESTORE:APPLE] ============= END (400) =============\n');
                    return res.status(400).json({ ok: false, code: 400, error: "Missing userId" });
                }
                // look up the user!
                // Support both array format and single transaction format
                let txList = [];
                if (transactions && Array.isArray(transactions)) {
                    txList = transactions.map(t => t.signedTransaction || t).filter(Boolean);
                } else if (signedTransaction) {
                    txList = [signedTransaction];
                }

                tools.log(`[IAP:RESTORE:APPLE] userId: ${userId}, transactions count: ${txList.length}`);

                if (txList.length === 0) {
                    tools.log('[IAP:RESTORE:APPLE] No transactions to restore');
                    tools.log('[IAP:RESTORE:APPLE] ============= END (200) =============\n');
                    return res.json({
                        ok: true,
                        restored: 0,
                        message: "No transactions provided",
                        entitlements: []
                    });
                }

                const restored = [];
                const errors = [];

                for (let i = 0; i < txList.length; i++) {
                    const signedTx = txList[i];
                    tools.log(`[IAP:RESTORE:APPLE] Processing transaction ${i + 1}/${txList.length}...`);

                    try {
                        // Verify JWS transaction with fallback
                        const { result: tx, environment: verifiedEnv } = await iap.verifyWithFallback(
                            async (verifier, payload) => verifier.verifyAndDecodeTransaction(payload),
                            signedTx,
                            'restore transaction'
                        );

                        tools.log(`[IAP:RESTORE:APPLE] Transaction verified (env: ${verifiedEnv}):`, {
                            transactionId: tx.transactionId,
                            originalTransactionId: tx.originalTransactionId,
                            productId: tx.productId,
                            expiresDate: tx.expiresDate,
                            appAccountToken: tx.appAccountToken || 'none'
                        });

                        // Price fields
                        const priceMicros = tx.price || null;
                        const currency = tx.currency || null;
                        const offerDiscountType = tx.offerDiscountType || null;

                        const expiresAt = tx.expiresDate ? new Date(tx.expiresDate).getTime() : null;
                        let status = 'active';
                        if (tx.revocationDate) status = 'revoked';
                        else if (expiresAt && expiresAt < Date.now()) status = 'expired';

                        // Only restore active subscriptions
                        if (status === 'active') {
                            await iap.upsertEntitlement(String(userId), {
                                source: "apple",
                                productId: tx.productId,
                                status,
                                expiresAt,
                                priceMicros,
                                currency,
                                offerDiscountType,
                                raw: {
                                    transactionId: tx.transactionId,
                                    originalTransactionId: tx.originalTransactionId,
                                    type: tx.type,
                                    appAccountToken: tx.appAccountToken,
                                    environment: tx.environment,
                                    verifiedEnv,
                                    verified: true,
                                    restoredAt: new Date().toISOString(),
                                    priceMicros,
                                    currency,
                                    offerDiscountType
                                }
                            });

                            restored.push({
                                transactionId: tx.transactionId,
                                originalTransactionId: tx.originalTransactionId,
                                productId: tx.productId,
                                status,
                                expiresAt
                            });

                            tools.log(`[IAP:RESTORE:APPLE] ✅ Restored: ${tx.productId} (${tx.transactionId})`);
                        } else {
                            tools.log(`[IAP:RESTORE:APPLE] ⏭️ Skipped (${status}): ${tx.productId}`);
                        }

                    } catch (txErr) {
                        const errMsg = iap.formatVerificationError(txErr);
                        console.error(`[IAP:RESTORE:APPLE] ❌ Transaction ${i + 1} failed:`, errMsg);
                        errors.push({ index: i, error: errMsg });
                    }
                }

                tools.log(`[IAP:RESTORE:APPLE] Restore complete: ${restored.length} restored, ${errors.length} errors`);
                tools.log('[IAP:RESTORE:APPLE] ============= END (200) =============\n');

                res.json({
                    ok: true,
                    restored: restored.length,
                    errors: errors.length,
                    entitlements: restored,
                    errorDetails: errors.length > 0 ? errors : undefined
                });

            } catch (e) {
                console.error('[IAP:RESTORE:APPLE] Unexpected error:', e);
                tools.log('[IAP:RESTORE:APPLE] ============= END (500) =============\n');
                res.status(500).json({ ok: false, error: e?.message || String(e) });
            }
        });

        /**
         * Google RTDN webhook (Pub/Sub push)
         * Google Play publishes to a Pub/Sub topic, you subscribe and push to HTTPS.
         * You receive:
         * {
         *   message: { data: base64(JSON), messageId, ... },
         *   subscription: "projects/.../subscriptions/..."
         * }
         * RTDN reference :contentReference[oaicite:8]{index=8}
         */
        app.post(route_start+"/webhook/google", async (req, res) => {
        try {
            const msg = req.body?.message;
            if (!msg?.data) return res.status(400).json({ error: "Missing Pub/Sub message.data" });

            const jsonStr = Buffer.from(msg.data, "base64").toString("utf8");
            const payload = JSON.parse(jsonStr);

            /**
             * RTDN payload types include subscriptionNotification and oneTimeProductNotification, etc.
             * We focus on subscriptionNotification:
             * {
             *   packageName,
             *   eventTimeMillis,
             *   subscriptionNotification: { notificationType, purchaseToken, subscriptionId }
             * }
             */
            const packageName = payload.packageName;
            const sub = payload.subscriptionNotification;

            if (!packageName || !sub?.purchaseToken) {
            console.warn("RTDN received but missing required fields", payload);
            return res.json({ ok: true, note: "Missing required fields; ignored." });
            }

            const purchaseV2 = await iap.googleGetSubscriptionV2({
            packageName,
            token: sub.purchaseToken,
            });

            const status = iap.normalizeGoogleState(purchaseV2);
            const expiresAt = iap.deriveGoogleExpiryMs(purchaseV2);
            const productId = purchaseV2?.lineItems?.[0]?.productId || sub.subscriptionId || "unknown";

            /**
             * Resolve userId from obfuscatedExternalAccountId.
             * The client passes Store.userIdToUUID(userId) as the accountId,
             * which Google returns here as obfuscatedExternalAccountId.
             * We reverse it with uuidToUserId() — same pattern as Apple's appAccountToken.
             * Falls back to ?userId= query param if obfuscatedExternalAccountId is not present.
             */
            const obfuscatedId = purchaseV2?.obfuscatedExternalAccountId;
            const decodedUserId = obfuscatedId ? iap.uuidToUserId(obfuscatedId) : null;
            const userId = decodedUserId || req.query.userId;

            tools.log(`[IAP:WEBHOOK:GOOGLE] obfuscatedExternalAccountId: ${obfuscatedId || '(not set)'}`);
            tools.log(`[IAP:WEBHOOK:GOOGLE] decoded userId: ${decodedUserId || '(none)'}`);
            tools.log(`[IAP:WEBHOOK:GOOGLE] final userId: ${userId || '(not found)'}`);

            if (!userId) {
            console.warn("[IAP:WEBHOOK:GOOGLE] No userId found - entitlement NOT saved", {
                productId,
                status,
            });
            return res.json({ ok: true, note: "No userId found; not stored." });
            }

            await iap.upsertEntitlement(String(userId), {
                source: "google",
                productId,
                status: expiresAt && expiresAt > Date.now() ? "active" : status,
                expiresAt,
                raw: { rtdn: payload, purchaseV2 },
            });

            tools.log(`[IAP:WEBHOOK:GOOGLE] ✅ Entitlement saved: userId=${userId}, status=${status}, productId=${productId}`);
            res.json({ ok: true });
        } catch (e) {
            console.error("Google webhook error", e);
            res.status(500).json({ error: e?.message || String(e) });
        }
        });

        /** --------------------------
         * Start
         * -------------------------- */
        const port = Number(iap_config.port);
        app.listen(port, () => {
            tools.log(`IAP service listening on :${port}`);
            tools.log(`- Health check:   GET  ${route_start}/health`);
            tools.log(`- Debug Apple:    GET  ${route_start}/debug/apple-auth`);
            tools.log(`- Entitlements:   GET  ${route_start}/status?userId=...`);
            tools.log(`- Apple webhook:  POST ${route_start}/webhook/apple`);
            tools.log(`- Google webhook: POST ${route_start}/webhook/google`);
            tools.log(`- Validate:       POST ${route_start}/validate/apple | ${route_start}/validate/google`);
            tools.log(`- Restore:        POST ${route_start}/restore/apple`);
        });
    }
}

// Initialize the IAP service
iap.init();