//
//  InAppPurchase.swift
//  StoreKit 2 Implementation
//
//  Migrated from InAppPurchase.m (StoreKit 1)
//  Copyright (c) 2024. MIT License.
//

import Foundation
import StoreKit

// MARK: - Error Codes (matching JS error codes)
private let ERROR_CODES_BASE = 6777000
private let ERR_SETUP = ERROR_CODES_BASE + 1
private let ERR_LOAD = ERROR_CODES_BASE + 2
private let ERR_PURCHASE = ERROR_CODES_BASE + 3
private let ERR_LOAD_RECEIPTS = ERROR_CODES_BASE + 4
private let ERR_CLIENT_INVALID = ERROR_CODES_BASE + 5
private let ERR_PAYMENT_CANCELLED = ERROR_CODES_BASE + 6
private let ERR_PAYMENT_INVALID = ERROR_CODES_BASE + 7
private let ERR_PAYMENT_NOT_ALLOWED = ERROR_CODES_BASE + 8
private let ERR_UNKNOWN = ERROR_CODES_BASE + 10
private let ERR_REFRESH_RECEIPTS = ERROR_CODES_BASE + 11
private let ERR_INVALID_PRODUCT_ID = ERROR_CODES_BASE + 12
private let ERR_FINISH = ERROR_CODES_BASE + 13
private let ERR_PRODUCT_NOT_AVAILABLE = ERROR_CODES_BASE + 23

// MARK: - Main Plugin Class
@objc(InAppPurchase)
@available(iOS 15.0, macOS 12.0, *)
public class InAppPurchase: CDVPlugin {
    
    // MARK: - Properties
    private var products: [String: Product] = [:]
    private var unfinishedTransactions: [String: Transaction] = [:]
    private var pendingTransactionUpdates: [[String: Any]] = []
    private var suppressedTransactionIds: Set<String> = []
    /// Transaction IDs that have already been emitted to JS via emitTransactionUpdateRaw.
    /// Prevents duplicate deliveries when both the purchase() polling loop and the
    /// Transaction.updates observer find the same upgrade transaction.
    private var emittedTransactionIds: Set<String> = []
    private var transactionObserverTask: Task<Void, Never>?
    
    private var isInitialized = false
    private var debugEnabled = false
    private var autoFinishEnabled = false

    /// Set while a purchase() call is in flight. The transaction observer uses this to suppress
    /// background auto-renewals for other products (e.g. pro_monthly_1 renewing while the user
    /// is purchasing pro_monthly_2) so they never reach the JS approved callback.
    private var currentOrderingProductId: String? = nil
    
    // MARK: - Plugin Lifecycle
    
    override public func pluginInitialize() {
        super.pluginInitialize()
        log("🚀 pluginInitialize: START isInitialized=\(isInitialized) pendingCount=\(pendingTransactionUpdates.count)")
        startTransactionObserver()
        log("🚀 pluginInitialize: DONE — observer task created: \(transactionObserverTask != nil)")
    }

    private func startTransactionObserver() {
        log("👀 startTransactionObserver: creating Task.detached observer")
        transactionObserverTask = Task.detached { [weak self] in
            guard let self = self else {
                NSLog("[CdvPurchase.AppleAppStore.swift] 👀 startTransactionObserver: self is nil — observer will not run")
                return
            }
            self.log("👀 startTransactionObserver: observer loop STARTED — waiting for Transaction.updates...")
            for await result in Transaction.updates {
                self.log("👀 startTransactionObserver: ⚡️ Transaction.updates fired — dispatching to handleTransactionUpdate")
                await self.handleTransactionUpdate(result)
            }
            self.log("👀 startTransactionObserver: observer loop ENDED (task cancelled or stream closed)")
        }
        log("👀 startTransactionObserver: Task created (isCancelled=\(transactionObserverTask?.isCancelled ?? true))")
    }

    override public func dispose() {
        log("🗑️ dispose: called — isInitialized=\(isInitialized) pendingCount=\(pendingTransactionUpdates.count) unfinishedCount=\(unfinishedTransactions.count) suppressedCount=\(suppressedTransactionIds.count)")
        if !pendingTransactionUpdates.isEmpty {
            let ids = pendingTransactionUpdates.compactMap { $0["transactionId"] as? String }
            log("🗑️ dispose: ⚠️ DISCARDING \(pendingTransactionUpdates.count) pending transaction(s): \(ids) — these will be LOST")
        }
        transactionObserverTask?.cancel()
        transactionObserverTask = nil
        products.removeAll()
        unfinishedTransactions.removeAll()
        pendingTransactionUpdates.removeAll()
        suppressedTransactionIds.removeAll()
        emittedTransactionIds.removeAll()
        isInitialized = false
        debugEnabled = false
        autoFinishEnabled = false
        log("🗑️ dispose: complete")
        super.dispose()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        //if debugEnabled || !isInitialized {
            NSLog("[CdvPurchase.AppleAppStore.swift] %@", message)
        //}
    }

    private func logTransaction(_ tx: Transaction, label: String = "Transaction") {
        var dict: [String: Any] = [
            "id":                    String(tx.id),
            "originalID":            String(tx.originalID),
            "productID":             tx.productID,
            "productType":           "\(tx.productType)",
            "purchaseDate":          tx.purchaseDate.description,
            "originalPurchaseDate":  tx.originalPurchaseDate.description,
            "quantity":              tx.purchasedQuantity,
            "isUpgraded":            tx.isUpgraded,
            "webOrderLineItemID":    tx.webOrderLineItemID ?? "nil",
            "subscriptionGroupID":   tx.subscriptionGroupID ?? "nil",
            "storefrontCountryCode": tx.storefrontCountryCode,
        ]
        if let exp    = tx.expirationDate       { dict["expirationDate"]   = exp.description }
        if let rev    = tx.revocationDate       { dict["revocationDate"]   = rev.description
                                                  dict["revocationReason"] = "\(tx.revocationReason as Any)" }
        if let token  = tx.appAccountToken      { dict["appAccountToken"]  = token.uuidString }
        if let offer  = tx.offerID              { dict["offerID"]          = offer }
        if let offerType = tx.offerType         { dict["offerType"]        = "\(offerType)" }

        if let json = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str  = String(data: json, encoding: .utf8) {
            log("\(label): \(str)")
        }
    }


    // MARK: - Setup Commands
    
    @objc func debug(_ command: CDVInvokedUrlCommand) {
        debugEnabled = true
        let result = CDVPluginResult(status: .ok)
        commandDelegate.send(result, callbackId: command.callbackId)
    }
    
    @objc func autoFinish(_ command: CDVInvokedUrlCommand) {
        autoFinishEnabled = true
        let result = CDVPluginResult(status: .ok)
        commandDelegate.send(result, callbackId: command.callbackId)
    }
    
    @objc func setup(_ command: CDVInvokedUrlCommand) {
        log("⚙️ setup: called — was isInitialized=\(isInitialized), pendingCount=\(pendingTransactionUpdates.count), observerRunning=\(transactionObserverTask != nil && !(transactionObserverTask?.isCancelled ?? true))")
        isInitialized = true
        log("⚙️ setup: isInitialized now TRUE — JS should call processPendingTransactions in 50ms")
        let result = CDVPluginResult(status: .ok, messageAs: "InAppPurchase initialized")
        commandDelegate.send(result, callbackId: command.callbackId)
    }
    
    @objc func canMakePayments(_ command: CDVInvokedUrlCommand) {
        // In StoreKit 2, we check AppStore.canMakePayments
        Task {
            let canMake = AppStore.canMakePayments
            log("canMakePayments: \(canMake)")
            
            let result: CDVPluginResult
            if canMake {
                result = CDVPluginResult(status: .ok, messageAs: "Can make payments")
            } else {
                result = CDVPluginResult(status: .error, messageAs: "Can't make payments")
            }
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }
    
    // MARK: - Load Products
    
    @objc func load(_ command: CDVInvokedUrlCommand) {
        guard let productIds = command.arguments.first as? [String], !productIds.isEmpty else {
            log("load: Empty array")
            let callbackArgs: [Any] = [NSNull(), NSNull()]
            let result = CDVPluginResult(status: .ok, messageAs: callbackArgs)
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }
        
        log("load: Getting products data for \(productIds.count) products")
        
        Task {
            do {
                let storeProducts = try await Product.products(for: Set(productIds))
                var validProducts: [[String: Any]] = []
                var loadedIds: Set<String> = []
                
                for product in storeProducts {
                    self.products[product.id] = product
                    loadedIds.insert(product.id)
                    validProducts.append(self.productToDictionary(product))
                    self.log("load: - \(product.id): \(product.displayName)")
                }
                
                // Find invalid product IDs
                let invalidIds = productIds.filter { !loadedIds.contains($0) }
                
                let callbackArgs: [Any] = [validProducts, invalidIds]
                let result = CDVPluginResult(status: .ok, messageAs: callbackArgs)
                self.commandDelegate.send(result, callbackId: command.callbackId)
                
            } catch {
                self.log("load: Error - \(error.localizedDescription)")
                let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                self.commandDelegate.send(result, callbackId: command.callbackId)
            }
        }
    }

    // MARK: - Live Entitlement Helper

    /// A live entitlement snapshot for a single product, gathered from StoreKit 2
    /// without any network call or sign-in prompt.
    private struct ActiveEntitlement {
        /// The product that is currently active.
        let productId: String
        /// The raw VerificationResult — carries `.jwsRepresentation` and `.payloadValue`.
        /// Nil only when the entitlement came from `subscription.status` and the inner
        /// transaction could not be extracted (rare).
        let verificationResult: VerificationResult<Transaction>?
    }

    /// Query both `Transaction.currentEntitlements` and `subscription.status` for all
    /// registered products, merge the results, and return one entry per active product.
    ///
    /// This is the single source of truth used by both `purchase` (to gate the attempt)
    /// and `getCurrentEntitlements` (to answer the JS bridge call).
    private func fetchLiveEntitlements() async -> [ActiveEntitlement] {
        var nonSubscriptionEntitlements: [ActiveEntitlement] = []
        var coveredProductIds: Set<String> = []
        // Track transaction IDs globally so the same JWS never appears twice.
        // Source 1 can emit multiple renewal transactions for the same product,
        // and source 2 can emit a sibling-product transaction that source 1 already saw.
        var seenTransactionIds: Set<UInt64> = []
        // For subscription group deduplication: groupID -> (entitlement, purchaseDate).
        // When multiple tiers of the same group appear in currentEntitlements simultaneously
        // (common in sandbox during upgrades before isUpgraded is set), we keep only the
        // most recently purchased one.
        var bestByGroup: [String: (ActiveEntitlement, Date)] = [:]

        // Source 1: Transaction.currentEntitlements (primary, fast, local)
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                guard !seenTransactionIds.contains(transaction.id) else {
                    log("fetchLiveEntitlements: skipping duplicate tx \(transaction.id) for \(transaction.productID)")
                    continue
                }
                seenTransactionIds.insert(transaction.id)
                // Skip transactions explicitly superseded by an upgrade (isUpgraded is set once
                // Apple processes the upgrade; the sandbox may lag, hence the group dedup below).
                guard !transaction.isUpgraded else {
                    log("fetchLiveEntitlements: skipping upgraded tx \(transaction.id) for \(transaction.productID)")
                    continue
                }
                let entitlement = ActiveEntitlement(productId: transaction.productID, verificationResult: result)
                if let groupID = transaction.subscriptionGroupID {
                    // Within a subscription group keep only the most recently purchased tier.
                    if let existing = bestByGroup[groupID] {
                        if transaction.purchaseDate > existing.1 {
                            log("fetchLiveEntitlements: group \(groupID): replacing \(existing.0.productId) with newer \(transaction.productID) (tx:\(transaction.id))")
                            coveredProductIds.remove(existing.0.productId)
                            bestByGroup[groupID] = (entitlement, transaction.purchaseDate)
                            coveredProductIds.insert(transaction.productID)
                        } else {
                            log("fetchLiveEntitlements: group \(groupID): keeping \(existing.0.productId) over older \(transaction.productID) (tx:\(transaction.id))")
                        }
                    } else {
                        bestByGroup[groupID] = (entitlement, transaction.purchaseDate)
                        coveredProductIds.insert(transaction.productID)
                    }
                } else {
                    log("fetchLiveEntitlements: currentEntitlements — \(transaction.productID) tx:\(transaction.id)")
                    nonSubscriptionEntitlements.append(entitlement)
                    coveredProductIds.insert(transaction.productID)
                }
            }
        }

        // Flatten subscription group winners into the result list.
        var entitlements = nonSubscriptionEntitlements
        for (groupID, (entitlement, _)) in bestByGroup {
            log("fetchLiveEntitlements: currentEntitlements — \(entitlement.productId) (best in group \(groupID))")
            entitlements.append(entitlement)
        }

        // Source 2: subscription.status fallback — catches the sandbox gap where
        // currentEntitlements briefly returns nothing between a cycle expiry and its
        // renewal transaction landing.
        for (productId, product) in products {
            guard !coveredProductIds.contains(productId),
                  let subscriptionInfo = product.subscription else { continue }
            do {
                let statuses = try await subscriptionInfo.status
                for status in statuses {
                    switch status.state {
                    case .subscribed, .inGracePeriod:
                        // Verify the actual transaction belongs to this product. In a subscription
                        // group, Apple reports .subscribed for every sibling product using the same
                        // underlying transaction — we must not create phantom entitlements for tiers
                        // the user never purchased.
                        guard let tx = try? status.transaction.payloadValue,
                              tx.productID == productId,
                              !seenTransactionIds.contains(tx.id) else {
                            if let tx = try? status.transaction.payloadValue {
                                log("fetchLiveEntitlements: subscription.status for \(productId) skipped — tx belongs to \(tx.productID) (tx:\(tx.id))")
                            }
                            continue
                        }
                        log("fetchLiveEntitlements: subscription.status fallback — \(productId) is \(status.state) tx:\(tx.id)")
                        seenTransactionIds.insert(tx.id)
                        entitlements.append(ActiveEntitlement(productId: productId, verificationResult: status.transaction))
                        coveredProductIds.insert(productId)
                    default:
                        break
                    }
                }
            } catch {
                log("fetchLiveEntitlements: Could not fetch subscription.status for \(productId): \(error)")
            }
        }

        log("fetchLiveEntitlements: \(entitlements.count) active entitlement(s): \(entitlements.map { $0.productId })")
        return entitlements
    }

    // MARK: - Purchase

    @objc func purchase(_ command: CDVInvokedUrlCommand) {
        guard let productId = command.arguments[0] as? String else {
            let result = CDVPluginResult(status: .error, messageAs: "Invalid product identifier")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        guard let product = products[productId] else {
            log("purchase: Product (\(productId)) does not exist or is not initialized.")
            let result = CDVPluginResult(status: .error, messageAs: "Product does not exist.")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        let quantity = (command.arguments.count > 1 ? command.arguments[1] as? Int : nil) ?? 1
        let applicationUsername = command.arguments.count > 2 ? command.arguments[2] as? String : nil
        let discountArg = command.arguments.count > 3 ? command.arguments[3] as? [String: Any] : nil
        // canPurchase is computed by the JS layer from the most recent local receipt state.
        // Defaults to true so existing callers that omit the argument are unaffected.
        let canPurchase = command.arguments.count > 4 ? (command.arguments[4] as? Bool ?? true) : true

        log("purchase: About to purchase \(productId) (canPurchase: \(canPurchase))")

        Task {
            do {
                var purchaseOptions: Set<Product.PurchaseOption> = []

                enum PurchaseCommandCallbackResult {
                    case success(message: String)
                    case failure(message: String)
                }

                func processPurchaseResult(_ result: Product.PurchaseResult, allowRetryAfterStaleExpiredTransaction: Bool) async throws -> PurchaseCommandCallbackResult {
                    switch result {
                    case .success(let verification):
                        let transaction = try self.checkVerified(verification)
                        let jwsRepresentation = verification.jwsRepresentation

                        let expiresStr = transaction.expirationDate?.description ?? "none"
                        let purchaseStr = transaction.purchaseDate.description
                        let isExpired = transaction.expirationDate.map { $0 < Date() } ?? false
                        self.log("purchase: Success - id:\(transaction.id) product:\(transaction.productID)")
                        self.log("purchase: Transaction details - purchaseDate:\(purchaseStr) expiresDate:\(expiresStr) isExpired:\(isExpired)")

                        if self.shouldSilentlyFinishExpiredSubscriptionTransaction(transaction) {
                            let transactionId = String(transaction.id)
                            self.log("purchase: Detected stale expired transaction \(transactionId) returned from product.purchase()")
                            await self.silentlyFinishTransaction(transaction, reason: "purchase returned an already-expired subscription transaction")

                            if allowRetryAfterStaleExpiredTransaction {
                                self.log("purchase: Retrying product.purchase() once after finishing stale transaction \(transactionId)")
                                let retryResult = try await product.purchase(options: purchaseOptions)
                                self.log("purchase: Retry product.purchase() returned")
                                return try await processPurchaseResult(retryResult, allowRetryAfterStaleExpiredTransaction: false)
                            } else {
                                // Retry also returned an expired transaction (common in sandbox with
                                // a backlog of short cycles). Before failing, check if there is already
                                // an active entitlement for this product — if so, surface it as a
                                // successful purchase rather than showing an error to the user.
                                self.log("purchase: Retry also returned stale transaction \(transactionId); checking currentEntitlements for \(productId)")
                                var foundActive = false
                                for await entitlementResult in Transaction.currentEntitlements {
                                    if let activeTx = try? self.checkVerified(entitlementResult),
                                       activeTx.productID == productId {
                                        self.log("purchase: Found active entitlement \(activeTx.id) via currentEntitlements — treating as success")
                                        let activeJws = entitlementResult.jwsRepresentation
                                        await self.handleVerifiedTransaction(activeTx, jwsRepresentation: activeJws, skipExpiredCheck: true)
                                        foundActive = true
                                        break
                                    }
                                }
                                // Source 2: subscription.status — catches the sandbox gap where
                                // currentEntitlements is briefly empty between a cycle expiry and
                                // its renewal transaction landing. Status can show .subscribed even
                                // when currentEntitlements returns nothing.
                                if !foundActive, let subscription = product.subscription {
                                    self.log("purchase: currentEntitlements empty; checking subscription.status for \(productId)")
                                    if let statuses = try? await subscription.status {
                                        for status in statuses {
                                            self.log("purchase: subscription.status = \(status.state) for \(productId)")
                                            if status.state == .subscribed || status.state == .inGracePeriod {
                                                if let activeTx = try? self.checkVerified(status.transaction) {
                                                    // Guard: in a subscription group, Apple may report .subscribed
                                                    // for sibling products using a transaction that belongs to a
                                                    // different tier. Only accept if the tx actually matches.
                                                    guard activeTx.productID == productId else {
                                                        self.log("purchase: subscription.status tx \(activeTx.id) belongs to \(activeTx.productID), not \(productId) — skipping")
                                                        continue
                                                    }
                                                    self.log("purchase: subscription.status confirms active (\(status.state)) — using transaction \(activeTx.id)")
                                                    let activeJws = status.transaction.jwsRepresentation
                                                    await self.handleVerifiedTransaction(activeTx, jwsRepresentation: activeJws, skipExpiredCheck: true)
                                                    foundActive = true
                                                    break
                                                }
                                            }
                                        }
                                    }
                                }
                                if !foundActive {
                                    let errorMessage = "Store returned an expired transaction. Please try again."
                                    self.log("purchase: No active entitlement found after retry + status check; giving up on \(transactionId)")
                                    self.emitTransactionUpdate(
                                        state: "PaymentTransactionStateFailed",
                                        errorCode: ERR_PURCHASE,
                                        error: errorMessage,
                                        productId: productId
                                    )
                                    return .failure(message: errorMessage)
                                }
                                return .success(message: "Payment added to queue")
                            }
                        }

                        // During subscription plan changes (upgrade or downgrade), Apple can
                        // return a transaction for the OLD product even though we called
                        // purchase() on the NEW product. For upgrades the new entitlement
                        // appears quickly; for downgrades it won't appear until renewal.
                        if transaction.productID != productId {
                            self.log("purchase: Returned transaction is for \(transaction.productID) but requested \(productId) — polling currentEntitlements for target product")
                            var foundTarget = false

                            // Quick poll: check currentEntitlements a few times for immediate upgrades
                            let maxAttempts = 5
                            for attempt in 1...maxAttempts {
                                for await entitlementResult in Transaction.currentEntitlements {
                                    if let targetTx = try? self.checkVerified(entitlementResult),
                                       targetTx.productID == productId {
                                        self.log("purchase: Found target product \(productId) in currentEntitlements on attempt \(attempt) (tx:\(targetTx.id)) — using for verify")
                                        await self.handleVerifiedTransaction(targetTx, jwsRepresentation: entitlementResult.jwsRepresentation)
                                        foundTarget = true
                                        break
                                    }
                                }
                                if foundTarget { break }
                                if attempt < maxAttempts {
                                    self.log("purchase: Target \(productId) not in currentEntitlements (attempt \(attempt)/\(maxAttempts)) — waiting 1s before retry")
                                    try await Task.sleep(nanoseconds: 1_000_000_000)
                                }
                            }

                            // Fallback: check subscription.status for immediate upgrades
                            if !foundTarget {
                                self.log("purchase: Target \(productId) not in currentEntitlements after \(maxAttempts) attempts — checking subscription.status")
                                if let targetProduct = self.products[productId],
                                   let subscription = targetProduct.subscription,
                                   let statuses = try? await subscription.status {
                                    for status in statuses {
                                        if status.state == .subscribed || status.state == .inGracePeriod {
                                            if let targetTx = try? self.checkVerified(status.transaction),
                                               targetTx.productID == productId {
                                                self.log("purchase: Found target \(productId) via subscription.status (tx:\(targetTx.id)) — using for verify")
                                                await self.handleVerifiedTransaction(targetTx, jwsRepresentation: status.transaction.jwsRepresentation)
                                                foundTarget = true
                                                break
                                            }
                                        }
                                    }
                                }
                            }

                            // Final fallback: for downgrades (or sandbox delays), the target product
                            // won't appear in entitlements until the next renewal cycle. If both products
                            // are in the same subscription group, Apple accepted the plan change — emit
                            // the returned (current) transaction so the purchase flow completes on-device.
                            // The server webhook (DID_CHANGE_RENEWAL_PREF) handles recording the pending
                            // switch to the target product via autoRenewProductId.
                            if !foundTarget {
                                let sameGroup: Bool = {
                                    guard let returnedProduct = self.products[transaction.productID],
                                          let targetProduct = self.products[productId],
                                          let returnedGroup = returnedProduct.subscription?.subscriptionGroupID,
                                          let targetGroup = targetProduct.subscription?.subscriptionGroupID else {
                                        return false
                                    }
                                    return returnedGroup == targetGroup
                                }()

                                if sameGroup {
                                    self.log("purchase: Target \(productId) not in entitlements but same subscription group as \(transaction.productID) — treating as successful plan change (downgrade/deferred upgrade)")
                                    await self.handleVerifiedTransaction(transaction, jwsRepresentation: jwsRepresentation)
                                } else {
                                    self.log("purchase: ⚠️ Target \(productId) not found and different subscription group — emitting error")
                                    self.emitTransactionUpdate(
                                        state: "PaymentTransactionStateFailed",
                                        errorCode: ERR_PURCHASE,
                                        error: "Plan change for \(productId) could not be confirmed. Please try again.",
                                        productId: productId
                                    )
                                }
                            }
                        } else {
                            await self.handleVerifiedTransaction(transaction, jwsRepresentation: jwsRepresentation)
                        }
                        return .success(message: "Payment added to queue")

                    case .userCancelled:
                        self.log("purchase: User cancelled")
                        self.emitTransactionUpdate(
                            state: "PaymentTransactionStateFailed",
                            errorCode: ERR_PAYMENT_CANCELLED,
                            error: "User cancelled",
                            productId: productId
                        )
                        return .success(message: "Payment cancelled")

                    case .pending:
                        self.log("purchase: Pending (Ask to Buy)")
                        self.emitTransactionUpdate(
                            state: "PaymentTransactionStateDeferred",
                            productId: productId
                        )
                        return .success(message: "Payment added to queue")

                    @unknown default:
                        let errorMessage = "Unknown purchase result"
                        self.log("purchase: Unknown result")
                        self.emitTransactionUpdate(
                            state: "PaymentTransactionStateFailed",
                            errorCode: ERR_UNKNOWN,
                            error: errorMessage,
                            productId: productId
                        )
                        return .failure(message: errorMessage)
                    }
                }

                // Set quantity for consumables
                if quantity > 1 {
                    purchaseOptions.insert(.quantity(quantity))
                }

                // Set application username (for server-side validation)
                if let username = applicationUsername, !username.isEmpty {
                    self.log("purchase: applicationUsername = \(username)")
                    if let uuidToken = UUID(uuidString: username) {
                        self.log("purchase: Setting appAccountToken = \(uuidToken.uuidString)")
                        purchaseOptions.insert(.appAccountToken(uuidToken))
                    } else {
                        self.log("purchase: WARNING - Failed to parse UUID from applicationUsername: '\(username)'")
                    }
                } else {
                    self.log("purchase: WARNING - No applicationUsername provided")
                }

                // Handle promotional offer discount
                if let discount = discountArg,
                   let offerId = discount["id"] as? String,
                   let keyId = discount["key"] as? String,
                   let nonceString = discount["nonce"] as? String,
                   let nonce = UUID(uuidString: nonceString),
                   let signature = discount["signature"] as? Data,
                   let timestampNumber = discount["timestamp"] as? NSNumber {
                    let timestamp = timestampNumber.intValue
                    purchaseOptions.insert(.promotionalOffer(
                        offerID: offerId,
                        keyID: keyId,
                        nonce: nonce,
                        signature: signature,
                        timestamp: timestamp
                    ))
                }

                // Gate on the JS-side canPurchase flag, which is derived from the most
                // recent local receipt state. If JS says the product is already owned,
                // block immediately without any additional StoreKit queries.
                if !canPurchase {
                    self.log("purchase: JS canPurchase=false — product already owned; blocking purchase")
                    self.emitTransactionUpdate(
                        state: "PaymentTransactionStateFailed",
                        errorCode: ERR_PURCHASE,
                        error: "Already subscribed to this product",
                        productId: productId
                    )
                    let pluginResult = CDVPluginResult(status: .error, messageAs: "Already subscribed")
                    self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                    return
                }

                self.log("purchase: Calling product.purchase()...")
                self.currentOrderingProductId = productId
                let result = try await product.purchase(options: purchaseOptions)
                self.log("purchase: product.purchase() returned")
                let callbackResult = try await processPurchaseResult(result, allowRetryAfterStaleExpiredTransaction: true)
                self.currentOrderingProductId = nil

                let pluginResult: CDVPluginResult
                switch callbackResult {
                case .success(let message):
                    pluginResult = CDVPluginResult(status: .ok, messageAs: message)
                case .failure(let message):
                    pluginResult = CDVPluginResult(status: .error, messageAs: message)
                }
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)

            } catch StoreKitError.userCancelled {
                self.currentOrderingProductId = nil
                self.emitTransactionUpdate(
                    state: "PaymentTransactionStateFailed",
                    errorCode: ERR_PAYMENT_CANCELLED,
                    error: "User cancelled",
                    productId: productId
                )
                let pluginResult = CDVPluginResult(status: .ok, messageAs: "Payment cancelled")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)

            } catch StoreKitError.notAvailableInStorefront {
                self.currentOrderingProductId = nil
                self.emitTransactionUpdate(
                    state: "PaymentTransactionStateFailed",
                    errorCode: ERR_PRODUCT_NOT_AVAILABLE,
                    error: "Product not available in storefront",
                    productId: productId
                )
                let pluginResult = CDVPluginResult(status: .error, messageAs: "Product not available")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)

            } catch {
                self.currentOrderingProductId = nil
                self.log("purchase: Error - \(error.localizedDescription)")
                self.emitTransactionUpdate(
                    state: "PaymentTransactionStateFailed",
                    errorCode: ERR_PURCHASE,
                    error: error.localizedDescription,
                    productId: productId
                )
                let pluginResult = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    // MARK: - Transaction Handling

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        log("📦 handleTransactionUpdate: ENTRY — isInitialized=\(isInitialized) currentOrderingProductId=\(currentOrderingProductId ?? "nil")")
        do {
            let transaction = try checkVerified(result)
            let jwsRepresentation = result.jwsRepresentation
            log("📦 handleTransactionUpdate: verified tx=\(transaction.id) product=\(transaction.productID) isUpgraded=\(transaction.isUpgraded) revoked=\(transaction.revocationDate != nil)")

            // If a purchase is in flight for a specific product, suppress observer deliveries
            // for any other product. Background auto-renewals (e.g. pro_monthly_1 renewing
            // while the user is purchasing pro_monthly_2) must not reach the JS approved
            // callback — the purchase() flow handles the correct transaction directly.
            if let ordering = currentOrderingProductId, ordering != transaction.productID {
                log("📦 handleTransactionUpdate: 🚫 suppressing background renewal of \(transaction.productID) while ordering \(ordering)")
                return
            }

            log("📦 handleTransactionUpdate: ✅ passing to handleVerifiedTransaction for \(transaction.productID)")
            await handleVerifiedTransaction(transaction, jwsRepresentation: jwsRepresentation)
        } catch {
            log("📦 handleTransactionUpdate: ❌ Transaction verification FAILED: \(error)")
        }
    }

    /// - Parameter skipExpiredCheck: Pass `true` when deliberately syncing JS ownership state
    ///   for a subscription that `subscription.status` confirms is still `.subscribed`, even if
    ///   the underlying transaction object is marked as expired (common in sandbox between renewal
    ///   cycles). In that case we must emit the ownership event rather than silently finish.
    private func handleVerifiedTransaction(_ transaction: Transaction, jwsRepresentation: String, skipExpiredCheck: Bool = false) async {
        let transactionId = String(transaction.id)
        log("✅ handleVerifiedTransaction: ENTRY tx=\(transactionId) product=\(transaction.productID) isUpgraded=\(transaction.isUpgraded) skipExpiredCheck=\(skipExpiredCheck) isInitialized=\(isInitialized) suppressed=\(suppressedTransactionIds.contains(transactionId))")

        if suppressedTransactionIds.contains(transactionId) {
            log("✅ handleVerifiedTransaction: 🚫 SUPPRESSED — tx=\(transactionId) is in suppressedTransactionIds — returning without emitting")
            return
        }

        //if emittedTransactionIds.contains(transactionId) {
         //   log("✅ handleVerifiedTransaction: 🚫 ALREADY EMITTED — tx=\(transactionId) was already sent to JS — skipping duplicate")
         //   return
        //}

        if !skipExpiredCheck && shouldSilentlyFinishExpiredSubscriptionTransaction(transaction) {
            let expStr = transaction.expirationDate?.description ?? "nil"
            log("✅ handleVerifiedTransaction: 🚫 SILENT FINISH — tx=\(transactionId) product=\(transaction.productID) is already expired (expDate=\(expStr)) — NOT emitting to JS")
            await silentlyFinishTransaction(transaction, reason: "observer received an already-expired subscription transaction")
            return
        }

        // Log detailed transaction information for debugging
        logTransaction(transaction, label: "handleVerifiedTransaction")
        if let revocationDate = transaction.revocationDate {
            log("handleVerifiedTransaction: revocationDate=\(revocationDate)")
        }
        log("handleVerifiedTransaction: isUpgraded=\(transaction.isUpgraded)")

        // For subscription products, check the actual subscription status
        // This provides more accurate state information than just checking expiration date
        if let productId = products[transaction.productID]?.id,
           let subscription = products[productId]?.subscription {
            do {
                let statuses = try await subscription.status
                for status in statuses {
                    log("handleVerifiedTransaction: Subscription status for \(productId): \(status.state)")

                    switch status.state {
                    case .subscribed:
                        log("handleVerifiedTransaction: User is currently subscribed")
                    case .inGracePeriod:
                        log("handleVerifiedTransaction: Subscription in grace period")
                    case .inBillingRetryPeriod:
                        log("handleVerifiedTransaction: Subscription in billing retry period")
                    case .expired:
                        log("handleVerifiedTransaction: Subscription has expired")
                    case .revoked:
                        log("handleVerifiedTransaction: Subscription was revoked")
                    default:
                        log("handleVerifiedTransaction: Unknown subscription state")
                    }

                    // Log renewal info if available
                    if case .verified(let renewalInfo) = status.renewalInfo {
                        log("handleVerifiedTransaction: Renewal - willAutoRenew=\(renewalInfo.willAutoRenew)")
                        if let expirationReason = renewalInfo.expirationReason {
                            log("handleVerifiedTransaction: Renewal expirationReason=\(expirationReason)")
                        }
                        if let gracePeriodExpirationDate = renewalInfo.gracePeriodExpirationDate {
                            log("handleVerifiedTransaction: Renewal gracePeriodExpirationDate=\(gracePeriodExpirationDate)")
                        }
                    }
                }
            } catch {
                log("handleVerifiedTransaction: Could not fetch subscription status: \(error)")
            }
        }

        // Check if this is an expired subscription
        // Note: We log details but still emit the transaction for the app to handle
        if let expirationDate = transaction.expirationDate {
            if expirationDate < Date() {
                log("handleVerifiedTransaction: Transaction \(transaction.id) is EXPIRED (expired: \(expirationDate))")
                // Don't silently finish - let the transaction update be emitted
                // so the app can properly handle the state
                // The app should decide whether to finish based on its business logic
            }
        }

        let state: String
        if transaction.revocationDate != nil {
            state = "PaymentTransactionStateRestored"
        } else if transaction.isUpgraded {
            state = "PaymentTransactionStateRestored"
        } else {
            state = "PaymentTransactionStatePurchased"
        }

        let originalTransactionId = transaction.originalID != transaction.id ? String(transaction.originalID) : ""
        let transactionDate = String(transaction.purchaseDate.timeIntervalSince1970 * 1000)

        // Get expiration date for subscriptions (milliseconds since epoch)
        var expirationDate = ""
        if let expiresDate = transaction.expirationDate {
            expirationDate = String(expiresDate.timeIntervalSince1970 * 1000)
        }

        var discountId = ""
        if let offerID = transaction.offerID {
            discountId = offerID
        }

        let args: [Any] = [
            state,
            0,
            "",
            transactionId,
            transaction.productID,
            jwsRepresentation,  // Position 5: JWS token for server verification
            originalTransactionId,
            transactionDate,
            discountId,
            expirationDate   // Position 9: Expiration date for subscriptions
        ]

        if isInitialized {
            log("📤 handleVerifiedTransaction: isInitialized=true — emitting NOW for \(transaction.productID) tx=\(transactionId)")
            emitTransactionUpdateRaw(args, transaction: transaction)
        } else {
            log("📤 handleVerifiedTransaction: ⏳ isInitialized=false — QUEUING tx=\(transactionId) product=\(transaction.productID) (queue will have \(pendingTransactionUpdates.count + 1) items after this)")
            log("📤 handleVerifiedTransaction: ⚠️ This transaction will be delivered when processPendingTransactions is called from JS (50ms after setup)")
            pendingTransactionUpdates.append([
                "args": args,
                "transactionId": transactionId,
                "jwsRepresentation": jwsRepresentation
            ])
            unfinishedTransactions[transactionId] = transaction
        }
    }

    private func shouldSilentlyFinishExpiredSubscriptionTransaction(_ transaction: Transaction) -> Bool {
        guard transaction.revocationDate == nil,
              !transaction.isUpgraded,
              let expirationDate = transaction.expirationDate else {
            return false
        }
        return expirationDate < Date()
    }

    private func silentlyFinishTransaction(_ transaction: Transaction, reason: String) async {
        let transactionId = String(transaction.id)

        if suppressedTransactionIds.contains(transactionId) {
            log("silentlyFinishTransaction: Transaction \(transactionId) already suppressed (\(reason))")
            return
        }

        log("silentlyFinishTransaction: Finishing transaction \(transactionId) for product \(transaction.productID) - \(reason)")
        suppressedTransactionIds.insert(transactionId)
        unfinishedTransactions.removeValue(forKey: transactionId)
        pendingTransactionUpdates.removeAll { pending in
            (pending["transactionId"] as? String) == transactionId
        }
        await transaction.finish()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        @unknown default:
            throw StoreKitError.unknown
        }
    }

    private func emitTransactionUpdate(
        state: String,
        errorCode: Int = 0,
        error: String = "",
        transactionId: String = "",
        productId: String = "",
        transactionReceipt: String = "",
        originalTransactionId: String = "",
        transactionDate: String = "",
        discountId: String = ""
    ) {
        let args: [Any] = [
            state,
            errorCode,
            error,
            transactionId,
            productId,
            transactionReceipt,
            originalTransactionId,
            transactionDate,
            discountId
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: args),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let js = "window.storekit.transactionUpdated.apply(window.storekit, \(jsonString))"
        commandDelegate.evalJs(js)
    }

    private func emitTransactionUpdateRaw(_ args: [Any], transaction: Transaction) {
        let txId = String(transaction.id)
        emittedTransactionIds.insert(txId)

        guard let jsonData = try? JSONSerialization.data(withJSONObject: args),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            log("📤 emitTransactionUpdateRaw: ❌ JSON serialization failed for tx=\(transaction.id) product=\(transaction.productID)")
            return
        }

        let transactionId = String(transaction.id)
        let state = args.first as? String ?? "unknown"
        log("📤 emitTransactionUpdateRaw: ✅ evalJs → window.storekit.transactionUpdated state=\(state) product=\(transaction.productID) tx=\(transactionId) autoFinish=\(autoFinishEnabled)")

        let js = "window.storekit.transactionUpdated.apply(window.storekit, \(jsonString))"
        commandDelegate.evalJs(js)

        if autoFinishEnabled {
            log("📤 emitTransactionUpdateRaw: autoFinish=true — finishing tx=\(transactionId) immediately")
            Task {
                await transaction.finish()
                self.emitTransactionFinished(transaction)
            }
        } else {
            log("📤 emitTransactionUpdateRaw: storing in unfinishedTransactions['\(transactionId)'] — waiting for JS to call finishTransaction")
            unfinishedTransactions[transactionId] = transaction
        }
    }

    private func emitTransactionFinished(_ transaction: Transaction) {
        let args: [Any] = [
            "PaymentTransactionStateFinished",
            0,
            "",
            String(transaction.id),
            transaction.productID,
            ""
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: args),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let js = "window.storekit.transactionUpdated.apply(window.storekit, \(jsonString))"
        commandDelegate.evalJs(js)
    }

    // MARK: - Finish Transaction

    @objc func finishTransaction(_ command: CDVInvokedUrlCommand) {
        guard let transactionId = command.arguments[0] as? String else {
            let result = CDVPluginResult(status: .error, messageAs: "Invalid transaction identifier")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        log("finishTransaction: \(transactionId)")

        guard let transaction = unfinishedTransactions[transactionId] else {
            log("finishTransaction: Transaction not found: \(transactionId)")
            let result = CDVPluginResult(status: .ok, messageAs: "Transaction not found (may already be finished)")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        Task {
            await transaction.finish()
            self.unfinishedTransactions.removeValue(forKey: transactionId)
            self.emitTransactionFinished(transaction)

            let result = CDVPluginResult(status: .ok, messageAs: "Transaction finished")
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    // MARK: - Process Pending Transactions

    @objc func processPendingTransactions(_ command: CDVInvokedUrlCommand) {
        log("🔄 processPendingTransactions: called — isInitialized=\(isInitialized) pendingCount=\(pendingTransactionUpdates.count) unfinishedCount=\(unfinishedTransactions.count)")

        if pendingTransactionUpdates.isEmpty {
            log("🔄 processPendingTransactions: queue is empty — nothing to flush")
        }

        for (index, pending) in pendingTransactionUpdates.enumerated() {
            let txId = pending["transactionId"] as? String ?? "unknown"
            if let args = pending["args"] as? [Any],
               let transactionId = pending["transactionId"] as? String,
               let transaction = unfinishedTransactions[transactionId] {
                let state = args.first as? String ?? "unknown"
                log("🔄 processPendingTransactions: flushing [\(index)] tx=\(transactionId) product=\(transaction.productID) state=\(state)")
                emitTransactionUpdateRaw(args, transaction: transaction)
            } else {
                log("🔄 processPendingTransactions: ⚠️ [\(index)] tx=\(txId) — missing args or transaction in unfinishedTransactions (may have been silently finished)")
            }
        }
        pendingTransactionUpdates.removeAll()

        log("🔄 processPendingTransactions: flushed — calling window.storekit.lastTransactionUpdated()")
        // Also emit last transaction update signal
        commandDelegate.evalJs("window.storekit.lastTransactionUpdated()")

        let result = CDVPluginResult(status: .ok)
        commandDelegate.send(result, callbackId: command.callbackId)
    }

    // MARK: - Receipt Methods

    /// Build the 5-element receipt array that the JS bridge expects:
    /// [base64Receipt, bundleIdentifier, bundleShortVersion, bundleNumericVersion, bundleSignature]
    private func buildReceiptArgs(base64Receipt: String) -> [Any] {
        let bundle = Bundle.main
        return [
            base64Receipt,
            bundle.bundleIdentifier ?? "",
            bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            Int(bundle.infoDictionary?["CFBundleNumericVersion"] as? String ?? "0") ?? 0,
            bundle.infoDictionary?["CFBundleSignature"] as? String ?? ""
        ]
    }

    /// Try to read the legacy on-disk StoreKit 1 receipt and return the args array.
    /// Returns nil if the receipt file doesn't exist.
    private func loadLegacyReceiptArgs() -> [Any]? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path),
              let receiptData = try? Data(contentsOf: receiptURL) else {
            return nil
        }
        let base64 = receiptData.base64EncodedString()
        log("loadLegacyReceiptArgs: receipt read (\(base64.count) chars)")
        return buildReceiptArgs(base64Receipt: base64)
    }

    @objc func appStoreReceipt(_ command: CDVInvokedUrlCommand) {
        log("appStoreReceipt: Reading app store receipt...")

        // Try legacy on-disk receipt first
        if let args = loadLegacyReceiptArgs() {
            log("appStoreReceipt: Returning legacy receipt")
            let result = CDVPluginResult(status: .ok, messageAs: args)
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        // StoreKit 2 fallback: return empty receipt (JWS tokens are sent per-transaction)
        log("appStoreReceipt: No legacy receipt — returning empty receipt for StoreKit 2 JWS flow")
        let args = buildReceiptArgs(base64Receipt: "")
        let result = CDVPluginResult(status: .ok, messageAs: args)
        commandDelegate.send(result, callbackId: command.callbackId)
    }

    @objc func appStoreRefreshReceipt(_ command: CDVInvokedUrlCommand) {
        log("appStoreRefreshReceipt: Refreshing receipt...")

        Task {
            // Sync with Apple (refreshes the on-disk receipt if possible)
            do {
                try await AppStore.sync()
                self.log("appStoreRefreshReceipt: Sync completed")
            } catch {
                self.log("appStoreRefreshReceipt: AppStore.sync() failed — \(error.localizedDescription) (continuing)")
            }

            // Try legacy receipt after sync
            if let args = self.loadLegacyReceiptArgs() {
                self.log("appStoreRefreshReceipt: Returning refreshed legacy receipt")
                let result = CDVPluginResult(status: .ok, messageAs: args)
                self.commandDelegate.send(result, callbackId: command.callbackId)
                return
            }

            // StoreKit 2 fallback: return empty receipt (JWS tokens are sent per-transaction)
            self.log("appStoreRefreshReceipt: No legacy receipt after sync — returning empty receipt for StoreKit 2 JWS flow")
            let args = self.buildReceiptArgs(base64Receipt: "")
            let result = CDVPluginResult(status: .ok, messageAs: args)
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    // MARK: - Restore Transactions

    @objc func restoreCompletedTransactions(_ command: CDVInvokedUrlCommand) {
        log("restoreCompletedTransactions: Starting restore...")

        Task {
            do {
                try await AppStore.sync()

                var restoredCount = 0
                for await result in Transaction.currentEntitlements {
                    do {
                        let transaction = try self.checkVerified(result)
                        let jwsRepresentation = result.jwsRepresentation

                        // Emit restore-specific callback with JWS token
                        self.emitRestoreTransactionUpdated(transaction, jwsRepresentation: jwsRepresentation)
                        restoredCount += 1
                    } catch {
                        self.log("restoreCompletedTransactions: Verification failed - \(error)")
                    }
                }

                self.log("restoreCompletedTransactions: Restored \(restoredCount) transactions")
                self.commandDelegate.evalJs("window.storekit.restoreCompletedTransactionsFinished()")

                let result = CDVPluginResult(status: .ok, messageAs: "Restore completed")
                self.commandDelegate.send(result, callbackId: command.callbackId)

            } catch {
                self.log("restoreCompletedTransactions: Error - \(error.localizedDescription)")
                self.commandDelegate.evalJs("window.storekit.restoreCompletedTransactionsFailed(\(ERR_REFRESH_RECEIPTS))")

                let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                self.commandDelegate.send(result, callbackId: command.callbackId)
            }
        }
    }

    /// Silently read current active entitlements from StoreKit 2 without triggering
    /// AppStore.sync(), so no sign-in dialog is shown. Returns an array of
    /// { productId, expirationDate (ms) } objects for currently active transactions.
    ///
    /// Uses two sources and merges them so sandbox timing gaps don't cause false misses:
    ///   1. Transaction.currentEntitlements  — the primary source
    ///   2. subscription.status              — fallback for each registered product;
    ///      catches the brief window between a sandbox expiry and its renewal transaction
    ///      landing in currentEntitlements, where source 1 would otherwise return nothing.
    @objc func getCurrentEntitlements(_ command: CDVInvokedUrlCommand) {
        log("getCurrentEntitlements: Checking live entitlements silently...")

        Task {
            let liveEntitlements = await self.fetchLiveEntitlements()

            // Convert to the [[String: Any]] format expected by the JS bridge
            let entitlements: [[String: Any]] = liveEntitlements.map { entitlement in
                var entry: [String: Any] = ["productId": entitlement.productId]
                if let result = entitlement.verificationResult,
                   let tx = try? result.payloadValue {
                    self.logTransaction(tx, label: "getCurrentEntitlements")
                    entry["transactionId"] = String(tx.id)
                    entry["originalTransactionId"] = String(tx.originalID)
                    entry["purchaseDate"] = tx.purchaseDate.timeIntervalSince1970 * 1000
                    if let exp = tx.expirationDate {
                        entry["expirationDate"] = exp.timeIntervalSince1970 * 1000
                        entry["isExpired"] = exp < Date()
                    }
                    if let revoked = tx.revocationDate {
                        entry["revocationDate"] = revoked.timeIntervalSince1970 * 1000
                    }
                    entry["isUpgraded"] = tx.isUpgraded
                    entry["productType"] = "\(tx.productType)"
                    if let offerID = tx.offerID {
                        entry["offerID"] = offerID
                    }
                    entry["jwsRepresentation"] = result.jwsRepresentation
                }
                return entry
            }

            self.log("getCurrentEntitlements: found \(entitlements.count) active entitlement(s)")
            let pluginResult = CDVPluginResult(status: .ok, messageAs: entitlements)
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
        }
    }

    /// Emit a restore transaction update to JavaScript with JWS token
    private func emitRestoreTransactionUpdated(_ transaction: Transaction, jwsRepresentation: String) {
        let transactionId = String(transaction.id)
        let originalTransactionId = transaction.originalID != transaction.id ? String(transaction.originalID) : ""
        let transactionDate = String(transaction.purchaseDate.timeIntervalSince1970 * 1000)

        // Get expiration date for subscriptions (milliseconds since epoch)
        var expirationDate = ""
        if let expiresDate = transaction.expirationDate {
            expirationDate = String(expiresDate.timeIntervalSince1970 * 1000)
        }

        // Escape the JWS for JavaScript string
        let escapedJws = jwsRepresentation.replacingOccurrences(of: "\\", with: "\\\\")
                                           .replacingOccurrences(of: "'", with: "\\'")

        let js = "window.storekit.restoreTransactionUpdated('\(transactionId)', '\(transaction.productID)', '\(escapedJws)', '\(originalTransactionId)', '\(transactionDate)', '\(expirationDate)')"
        commandDelegate.evalJs(js)
    }

    // MARK: - Product Dictionary Conversion

    private func productToDictionary(_ product: Product) -> [String: Any] {
        var dict: [String: Any] = [
            "id": product.id,
            "title": product.displayName,
            "description": product.description,
            "price": product.displayPrice,
            "priceMicros": Int(truncating: product.price as NSNumber) * 1000000,
            "currency": product.priceFormatStyle.currencyCode
        ]

        // Add subscription info if applicable
        if let subscription = product.subscription {
            dict["subscriptionPeriod"] = periodToDictionary(subscription.subscriptionPeriod)

            if let intro = subscription.introductoryOffer {
                dict["introductoryPrice"] = discountToDictionary(intro, product: product)
            }

            var discounts: [[String: Any]] = []
            for discount in subscription.promotionalOffers {
                discounts.append(discountToDictionary(discount, product: product))
            }
            if !discounts.isEmpty {
                dict["discounts"] = discounts
            }

            dict["group"] = subscription.subscriptionGroupID
        }

        // Product type
        switch product.type {
        case .consumable:
            dict["type"] = "consumable"
        case .nonConsumable:
            dict["type"] = "non-consumable"
        case .autoRenewable:
            dict["type"] = "auto-renewable-subscription"
        case .nonRenewable:
            dict["type"] = "non-renewing-subscription"
        default:
            dict["type"] = "unknown"
        }

        return dict
    }

    private func periodToDictionary(_ period: Product.SubscriptionPeriod) -> [String: Any] {
        var unitStr: String
        switch period.unit {
        case .day:
            unitStr = "Day"
        case .week:
            unitStr = "Week"
        case .month:
            unitStr = "Month"
        case .year:
            unitStr = "Year"
        @unknown default:
            unitStr = "Unknown"
        }

        return [
            "unit": unitStr,
            "numberOfUnits": period.value
        ]
    }

    private func discountToDictionary(_ offer: Product.SubscriptionOffer, product: Product) -> [String: Any] {
        var dict: [String: Any] = [
            "price": offer.displayPrice,
            "priceMicros": Int(truncating: offer.price as NSNumber) * 1000000
        ]

        // period is not optional in SubscriptionOffer
        dict["period"] = periodToDictionary(offer.period)
        dict["periodCount"] = offer.periodCount

        if let id = offer.id {
            dict["id"] = id
        }

        var paymentModeStr: String
        switch offer.paymentMode {
        case .freeTrial:
            paymentModeStr = "FreeTrial"
        case .payAsYouGo:
            paymentModeStr = "PayAsYouGo"
        case .payUpFront:
            paymentModeStr = "PayUpFront"
        default:
            paymentModeStr = "Unknown"
        }
        dict["paymentMode"] = paymentModeStr

        var typeStr: String
        switch offer.type {
        case .introductory:
            typeStr = "Introductory"
        case .promotional:
            typeStr = "Promotional"
        default:
            // Handles .winBack (iOS 18+) and any future cases
            typeStr = "Unknown"
        }
        dict["type"] = typeStr

        return dict
    }
}
