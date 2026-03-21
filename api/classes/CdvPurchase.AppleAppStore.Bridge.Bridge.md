# Class: Bridge

[AppleAppStore](../modules/CdvPurchase.AppleAppStore.md).[Bridge](../modules/CdvPurchase.AppleAppStore.Bridge.md).Bridge

## Table of contents

### Constructors

- [constructor](CdvPurchase.AppleAppStore.Bridge.Bridge.md#constructor)

### Properties

- [appStoreReceipt](CdvPurchase.AppleAppStore.Bridge.Bridge.md#appstorereceipt)
- [onFailed](CdvPurchase.AppleAppStore.Bridge.Bridge.md#onfailed)
- [onPurchased](CdvPurchase.AppleAppStore.Bridge.Bridge.md#onpurchased)
- [onRestored](CdvPurchase.AppleAppStore.Bridge.Bridge.md#onrestored)
- [options](CdvPurchase.AppleAppStore.Bridge.Bridge.md#options)
- [restoredTransactions](CdvPurchase.AppleAppStore.Bridge.Bridge.md#restoredtransactions)
- [transactionsForProduct](CdvPurchase.AppleAppStore.Bridge.Bridge.md#transactionsforproduct)

### Methods

- [canMakePayments](CdvPurchase.AppleAppStore.Bridge.Bridge.md#canmakepayments)
- [clearRestoredTransactions](CdvPurchase.AppleAppStore.Bridge.Bridge.md#clearrestoredtransactions)
- [finalizeTransactionUpdates](CdvPurchase.AppleAppStore.Bridge.Bridge.md#finalizetransactionupdates)
- [finish](CdvPurchase.AppleAppStore.Bridge.Bridge.md#finish)
- [getCurrentEntitlements](CdvPurchase.AppleAppStore.Bridge.Bridge.md#getcurrententitlements)
- [getRestoredTransactions](CdvPurchase.AppleAppStore.Bridge.Bridge.md#getrestoredtransactions)
- [init](CdvPurchase.AppleAppStore.Bridge.Bridge.md#init)
- [lastTransactionUpdated](CdvPurchase.AppleAppStore.Bridge.Bridge.md#lasttransactionupdated)
- [load](CdvPurchase.AppleAppStore.Bridge.Bridge.md#load)
- [loadReceipts](CdvPurchase.AppleAppStore.Bridge.Bridge.md#loadreceipts)
- [manageBilling](CdvPurchase.AppleAppStore.Bridge.Bridge.md#managebilling)
- [manageSubscriptions](CdvPurchase.AppleAppStore.Bridge.Bridge.md#managesubscriptions)
- [parseReceiptArgs](CdvPurchase.AppleAppStore.Bridge.Bridge.md#parsereceiptargs)
- [presentCodeRedemptionSheet](CdvPurchase.AppleAppStore.Bridge.Bridge.md#presentcoderedemptionsheet)
- [processPendingTransactions](CdvPurchase.AppleAppStore.Bridge.Bridge.md#processpendingtransactions)
- [purchase](CdvPurchase.AppleAppStore.Bridge.Bridge.md#purchase)
- [refreshReceipts](CdvPurchase.AppleAppStore.Bridge.Bridge.md#refreshreceipts)
- [restore](CdvPurchase.AppleAppStore.Bridge.Bridge.md#restore)
- [restoreCompletedTransactionsFailed](CdvPurchase.AppleAppStore.Bridge.Bridge.md#restorecompletedtransactionsfailed)
- [restoreCompletedTransactionsFinished](CdvPurchase.AppleAppStore.Bridge.Bridge.md#restorecompletedtransactionsfinished)
- [restoreTransactionUpdated](CdvPurchase.AppleAppStore.Bridge.Bridge.md#restoretransactionupdated)
- [transactionUpdated](CdvPurchase.AppleAppStore.Bridge.Bridge.md#transactionupdated)

## Constructors

### constructor

• **new Bridge**(): [`Bridge`](CdvPurchase.AppleAppStore.Bridge.Bridge.md)

#### Returns

[`Bridge`](CdvPurchase.AppleAppStore.Bridge.Bridge.md)

## Properties

### appStoreReceipt

• `Optional` **appStoreReceipt**: ``null`` \| [`ApplicationReceipt`](../interfaces/CdvPurchase.AppleAppStore.ApplicationReceipt.md)

The application receipt from AppStore, cached in javascript

___

### onFailed

• **onFailed**: `boolean` = `false`

**`Deprecated`**

___

### onPurchased

• **onPurchased**: `boolean` = `false`

**`Deprecated`**

___

### onRestored

• **onRestored**: `boolean` = `false`

**`Deprecated`**

___

### options

• **options**: [`BridgeCallbacks`](../interfaces/CdvPurchase.AppleAppStore.Bridge.BridgeCallbacks.md)

Callbacks set by the adapter

___

### restoredTransactions

• **restoredTransactions**: \{ `expirationDate?`: `string` ; `jwsRepresentation`: `string` ; `originalTransactionIdentifier?`: `string` ; `productId`: `string` ; `transactionDate?`: `string` ; `transactionIdentifier`: `string`  }[] = `[]`

Transactions collected during restore (with JWS tokens)

___

### transactionsForProduct

• **transactionsForProduct**: `Object` = `{}`

Transactions for a given product

#### Index signature

▪ [productId: `string`]: `string`[]

## Methods

### canMakePayments

▸ **canMakePayments**(`success`, `error`): `void`

Checks if device/user is allowed to make in-app purchases

#### Parameters

| Name | Type |
| :------ | :------ |
| `success` | () => `void` |
| `error` | (`message`: `string`) => `void` |

#### Returns

`void`

___

### clearRestoredTransactions

▸ **clearRestoredTransactions**(): `void`

Clear the collected restore transactions.
Call this before starting a new restore.

#### Returns

`void`

___

### finalizeTransactionUpdates

▸ **finalizeTransactionUpdates**(): `void`

#### Returns

`void`

___

### finish

▸ **finish**(`transactionId`, `success`, `error`): `void`

#### Parameters

| Name | Type |
| :------ | :------ |
| `transactionId` | `string` |
| `success` | () => `void` |
| `error` | (`msg`: `string`) => `void` |

#### Returns

`void`

___

### getCurrentEntitlements

▸ **getCurrentEntitlements**(`success`, `error`): `void`

Silently fetch current active entitlements from StoreKit 2
without triggering AppStore.sync() (no sign-in dialog).

Callback receives an array of { productId, expirationDate } objects.

#### Parameters

| Name | Type |
| :------ | :------ |
| `success` | (`entitlements`: \{ `expirationDate?`: `string` ; `productId`: `string`  }[]) => `void` |
| `error` | (`msg`: `string`) => `void` |

#### Returns

`void`

___

### getRestoredTransactions

▸ **getRestoredTransactions**(): \{ `expirationDate?`: `string` ; `jwsRepresentation`: `string` ; `originalTransactionIdentifier?`: `string` ; `productId`: `string` ; `transactionDate?`: `string` ; `transactionIdentifier`: `string`  }[]

Get all collected restore transactions with JWS tokens.

#### Returns

\{ `expirationDate?`: `string` ; `jwsRepresentation`: `string` ; `originalTransactionIdentifier?`: `string` ; `productId`: `string` ; `transactionDate?`: `string` ; `transactionIdentifier`: `string`  }[]

___

### init

▸ **init**(`options`, `success`, `error`): `void`

Initialize the AppStore bridge.

This calls the native "setup" method from the "InAppPurchase" Objective-C class.

#### Parameters

| Name | Type | Description |
| :------ | :------ | :------ |
| `options` | `Partial`\<[`BridgeOptions`](../interfaces/CdvPurchase.AppleAppStore.Bridge.BridgeOptions.md)\> | Options for the bridge |
| `success` | () => `void` | Called when the bridge is ready |
| `error` | (`code`: [`ErrorCode`](../enums/CdvPurchase.ErrorCode.md), `message`: `string`) => `void` | Called when the bridge failed to initialize |

#### Returns

`void`

___

### lastTransactionUpdated

▸ **lastTransactionUpdated**(): `void`

#### Returns

`void`

___

### load

▸ **load**(`productIds`, `success`, `error`): `void`

Retrieves localized product data, including price (as localized
string), name, description of multiple products.

#### Parameters

| Name | Type | Description |
| :------ | :------ | :------ |
| `productIds` | `string`[] | An array of product identifier strings. |
| `success` | (`validProducts`: [`ValidProduct`](../interfaces/CdvPurchase.AppleAppStore.Bridge.ValidProduct.md)[], `invalidProductIds`: `string`[]) => `void` | Called once with the result of the products request. Receives `(validProducts, invalidProductIds)` where validProducts is an array of [ValidProduct](../interfaces/CdvPurchase.AppleAppStore.Bridge.ValidProduct.md) objects and invalidProductIds is an array of product identifier strings rejected by the store. |
| `error` | (`code`: [`ErrorCode`](../enums/CdvPurchase.ErrorCode.md), `message`: `string`) => `void` | Called when loading fails. |

#### Returns

`void`

___

### loadReceipts

▸ **loadReceipts**(`callback`, `errorCb`): `void`

#### Parameters

| Name | Type |
| :------ | :------ |
| `callback` | (`receipt`: [`ApplicationReceipt`](../interfaces/CdvPurchase.AppleAppStore.ApplicationReceipt.md)) => `void` |
| `errorCb` | (`code`: [`ErrorCode`](../enums/CdvPurchase.ErrorCode.md), `message`: `string`) => `void` |

#### Returns

`void`

___

### manageBilling

▸ **manageBilling**(`callback?`): `void`

#### Parameters

| Name | Type |
| :------ | :------ |
| `callback?` | [`Callback`](../modules/CdvPurchase.md#callback)\<`any`\> |

#### Returns

`void`

___

### manageSubscriptions

▸ **manageSubscriptions**(`callback?`): `void`

#### Parameters

| Name | Type |
| :------ | :------ |
| `callback?` | [`Callback`](../modules/CdvPurchase.md#callback)\<`any`\> |

#### Returns

`void`

___

### parseReceiptArgs

▸ **parseReceiptArgs**(`args`): [`ApplicationReceipt`](../interfaces/CdvPurchase.AppleAppStore.ApplicationReceipt.md)

#### Parameters

| Name | Type |
| :------ | :------ |
| `args` | `RawReceiptArgs` |

#### Returns

[`ApplicationReceipt`](../interfaces/CdvPurchase.AppleAppStore.ApplicationReceipt.md)

___

### presentCodeRedemptionSheet

▸ **presentCodeRedemptionSheet**(`callback?`): `void`

#### Parameters

| Name | Type |
| :------ | :------ |
| `callback?` | [`Callback`](../modules/CdvPurchase.md#callback)\<`any`\> |

#### Returns

`void`

___

### processPendingTransactions

▸ **processPendingTransactions**(): `void`

#### Returns

`void`

___

### purchase

▸ **purchase**(`productId`, `quantity`, `applicationUsername`, `discount`, `success`, `error`, `canPurchase?`): `void`

Makes an in-app purchase.

#### Parameters

| Name | Type | Default value | Description |
| :------ | :------ | :------ | :------ |
| `productId` | `string` | `undefined` | The product identifier. e.g. "com.example.MyApp.myproduct" |
| `quantity` | `number` | `undefined` | Quantity of product to purchase |
| `applicationUsername` | `undefined` \| `string` | `undefined` | - |
| `discount` | `undefined` \| [`PaymentDiscount`](../interfaces/CdvPurchase.AppleAppStore.PaymentDiscount.md) | `undefined` | - |
| `success` | () => `void` | `undefined` | - |
| `error` | (`message?`: `string`) => `void` | `undefined` | - |
| `canPurchase` | `boolean` | `true` | - |

#### Returns

`void`

___

### refreshReceipts

▸ **refreshReceipts**(`successCb`, `errorCb`): `void`

#### Parameters

| Name | Type |
| :------ | :------ |
| `successCb` | (`receipt`: [`ApplicationReceipt`](../interfaces/CdvPurchase.AppleAppStore.ApplicationReceipt.md)) => `void` |
| `errorCb` | (`code`: [`ErrorCode`](../enums/CdvPurchase.ErrorCode.md), `message`: `string`) => `void` |

#### Returns

`void`

___

### restore

▸ **restore**(`callback?`): `void`

Asks the payment queue to restore previously completed purchases.

The restored transactions are passed to the onRestored callback, so make sure you define a handler for that first.

#### Parameters

| Name | Type |
| :------ | :------ |
| `callback?` | [`Callback`](../modules/CdvPurchase.md#callback)\<`any`\> |

#### Returns

`void`

___

### restoreCompletedTransactionsFailed

▸ **restoreCompletedTransactionsFailed**(`errorCode`): `void`

#### Parameters

| Name | Type |
| :------ | :------ |
| `errorCode` | [`ErrorCode`](../enums/CdvPurchase.ErrorCode.md) |

#### Returns

`void`

___

### restoreCompletedTransactionsFinished

▸ **restoreCompletedTransactionsFinished**(): `void`

#### Returns

`void`

___

### restoreTransactionUpdated

▸ **restoreTransactionUpdated**(`transactionIdentifier`, `productId`, `jwsRepresentation`, `originalTransactionIdentifier?`, `transactionDate?`, `expirationDate?`): `void`

Called from native for each transaction during restore.
Collects the JWS token for server-side verification.

#### Parameters

| Name | Type |
| :------ | :------ |
| `transactionIdentifier` | `string` |
| `productId` | `string` |
| `jwsRepresentation` | `string` |
| `originalTransactionIdentifier?` | `string` |
| `transactionDate?` | `string` |
| `expirationDate?` | `string` |

#### Returns

`void`

___

### transactionUpdated

▸ **transactionUpdated**(`state`, `errorCode`, `errorText`, `transactionIdentifier`, `productId`, `jwsRepresentation`, `originalTransactionIdentifier`, `transactionDate`, `discountId`, `expirationDate`): `void`

#### Parameters

| Name | Type |
| :------ | :------ |
| `state` | [`TransactionState`](../modules/CdvPurchase.AppleAppStore.Bridge.md#transactionstate) |
| `errorCode` | `undefined` \| [`ErrorCode`](../enums/CdvPurchase.ErrorCode.md) |
| `errorText` | `undefined` \| `string` |
| `transactionIdentifier` | `string` |
| `productId` | `string` |
| `jwsRepresentation` | `undefined` \| `string` |
| `originalTransactionIdentifier` | `undefined` \| `string` |
| `transactionDate` | `undefined` \| `string` |
| `discountId` | `undefined` \| `string` |
| `expirationDate` | `undefined` \| `string` |

#### Returns

`void`
