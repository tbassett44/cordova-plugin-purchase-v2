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
    private var transactionObserverTask: Task<Void, Never>?
    
    private var isInitialized = false
    private var debugEnabled = false
    private var autoFinishEnabled = false
    
    // MARK: - Plugin Lifecycle
    
    override public func pluginInitialize() {
        super.pluginInitialize()
        log("StoreKit 2 Plugin Initializing...")
        startTransactionObserver()
        log("StoreKit 2 Plugin Initialized.")
    }
    
    private func startTransactionObserver() {
        transactionObserverTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransactionUpdate(result)
            }
        }
    }
    
    override public func dispose() {
        transactionObserverTask?.cancel()
        transactionObserverTask = nil
        products.removeAll()
        unfinishedTransactions.removeAll()
        pendingTransactionUpdates.removeAll()
        isInitialized = false
        debugEnabled = false
        autoFinishEnabled = false
        super.dispose()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        if debugEnabled || !isInitialized {
            NSLog("[CdvPurchase.AppleAppStore.swift] %@", message)
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
        isInitialized = true
        log("setup: OK")
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

        log("purchase: About to purchase \(productId)")

        Task {
            do {
                var purchaseOptions: Set<Product.PurchaseOption> = []

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

                let result = try await product.purchase(options: purchaseOptions)

                switch result {
                case .success(let verification):
                    let transaction = try self.checkVerified(verification)
                    let jwsRepresentation = verification.jwsRepresentation
                    self.log("purchase: Success - \(transaction.id)")
                    await self.handleVerifiedTransaction(transaction, jwsRepresentation: jwsRepresentation)

                case .userCancelled:
                    self.log("purchase: User cancelled")
                    self.emitTransactionUpdate(
                        state: "PaymentTransactionStateFailed",
                        errorCode: ERR_PAYMENT_CANCELLED,
                        error: "User cancelled",
                        productId: productId
                    )

                case .pending:
                    self.log("purchase: Pending (Ask to Buy)")
                    self.emitTransactionUpdate(
                        state: "PaymentTransactionStateDeferred",
                        productId: productId
                    )

                @unknown default:
                    self.log("purchase: Unknown result")
                    self.emitTransactionUpdate(
                        state: "PaymentTransactionStateFailed",
                        errorCode: ERR_UNKNOWN,
                        error: "Unknown purchase result",
                        productId: productId
                    )
                }

                let pluginResult = CDVPluginResult(status: .ok, messageAs: "Payment added to queue")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)

            } catch StoreKitError.userCancelled {
                self.emitTransactionUpdate(
                    state: "PaymentTransactionStateFailed",
                    errorCode: ERR_PAYMENT_CANCELLED,
                    error: "User cancelled",
                    productId: productId
                )
                let pluginResult = CDVPluginResult(status: .ok, messageAs: "Payment cancelled")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)

            } catch StoreKitError.notAvailableInStorefront {
                self.emitTransactionUpdate(
                    state: "PaymentTransactionStateFailed",
                    errorCode: ERR_PRODUCT_NOT_AVAILABLE,
                    error: "Product not available in storefront",
                    productId: productId
                )
                let pluginResult = CDVPluginResult(status: .error, messageAs: "Product not available")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)

            } catch {
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
        do {
            let transaction = try checkVerified(result)
            // Extract JWS representation from the VerificationResult
            let jwsRepresentation = result.jwsRepresentation
            await handleVerifiedTransaction(transaction, jwsRepresentation: jwsRepresentation)
        } catch {
            log("Transaction verification failed: \(error)")
        }
    }

    private func handleVerifiedTransaction(_ transaction: Transaction, jwsRepresentation: String) async {
        let state: String
        if transaction.revocationDate != nil {
            state = "PaymentTransactionStateRestored"
        } else if transaction.isUpgraded {
            state = "PaymentTransactionStateRestored"
        } else {
            state = "PaymentTransactionStatePurchased"
        }

        let transactionId = String(transaction.id)
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
            emitTransactionUpdateRaw(args, transaction: transaction)
        } else {
            pendingTransactionUpdates.append([
                "args": args,
                "transactionId": transactionId,
                "jwsRepresentation": jwsRepresentation
            ])
            unfinishedTransactions[transactionId] = transaction
        }
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
        guard let jsonData = try? JSONSerialization.data(withJSONObject: args),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let js = "window.storekit.transactionUpdated.apply(window.storekit, \(jsonString))"
        commandDelegate.evalJs(js)

        let transactionId = String(transaction.id)

        if autoFinishEnabled {
            Task {
                await transaction.finish()
                self.emitTransactionFinished(transaction)
            }
        } else {
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
        log("processPendingTransactions: \(pendingTransactionUpdates.count) pending")

        for pending in pendingTransactionUpdates {
            if let args = pending["args"] as? [Any],
               let transactionId = pending["transactionId"] as? String,
               let transaction = unfinishedTransactions[transactionId] {
                emitTransactionUpdateRaw(args, transaction: transaction)
            }
        }
        pendingTransactionUpdates.removeAll()

        // Also emit last transaction update signal
        commandDelegate.evalJs("window.storekit.lastTransactionUpdated()")

        let result = CDVPluginResult(status: .ok)
        commandDelegate.send(result, callbackId: command.callbackId)
    }

    // MARK: - Receipt Methods

    @objc func appStoreReceipt(_ command: CDVInvokedUrlCommand) {
        log("appStoreReceipt: Reading app store receipt...")

        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path) else {
            log("appStoreReceipt: No receipt found")
            let result = CDVPluginResult(status: .error, messageAs: "No receipt available")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        do {
            let receiptData = try Data(contentsOf: receiptURL)
            let base64Receipt = receiptData.base64EncodedString()
            log("appStoreReceipt: Receipt read successfully (\(base64Receipt.count) chars)")

            let result = CDVPluginResult(status: .ok, messageAs: base64Receipt)
            commandDelegate.send(result, callbackId: command.callbackId)
        } catch {
            log("appStoreReceipt: Error reading receipt - \(error.localizedDescription)")
            let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    @objc func appStoreRefreshReceipt(_ command: CDVInvokedUrlCommand) {
        log("appStoreRefreshReceipt: Refreshing receipt...")

        Task {
            do {
                try await AppStore.sync()
                self.log("appStoreRefreshReceipt: Sync completed")

                // Now read the refreshed receipt
                if let receiptURL = Bundle.main.appStoreReceiptURL,
                   FileManager.default.fileExists(atPath: receiptURL.path) {
                    let receiptData = try Data(contentsOf: receiptURL)
                    let base64Receipt = receiptData.base64EncodedString()

                    let result = CDVPluginResult(status: .ok, messageAs: base64Receipt)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                } else {
                    let result = CDVPluginResult(status: .error, messageAs: "No receipt after refresh")
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                }
            } catch {
                self.log("appStoreRefreshReceipt: Error - \(error.localizedDescription)")
                let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                self.commandDelegate.send(result, callbackId: command.callbackId)
            }
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