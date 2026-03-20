# Interface: ApiValidatorBodyTransactionApple

[Validator](../modules/CdvPurchase.Validator.md).[Request](../modules/CdvPurchase.Validator.Request.md).ApiValidatorBodyTransactionApple

Transaction type from an Apple powered device

## Table of contents

### Properties

- [appStoreReceipt](CdvPurchase.Validator.Request.ApiValidatorBodyTransactionApple.md#appstorereceipt)
- [id](CdvPurchase.Validator.Request.ApiValidatorBodyTransactionApple.md#id)
- [signedTransaction](CdvPurchase.Validator.Request.ApiValidatorBodyTransactionApple.md#signedtransaction)
- [transactionReceipt](CdvPurchase.Validator.Request.ApiValidatorBodyTransactionApple.md#transactionreceipt)
- [type](CdvPurchase.Validator.Request.ApiValidatorBodyTransactionApple.md#type)

## Properties

### appStoreReceipt

• `Optional` **appStoreReceipt**: `string`

Apple appstore receipt, base64 encoded (StoreKit 1).

___

### id

• `Optional` **id**: `string`

Identifier of the transaction to evaluate, or set it to your application identifier if id has been set so.

**`Required`**

___

### signedTransaction

• `Optional` **signedTransaction**: `string`

JWS signed transaction from StoreKit 2.

When present, use App Store Server API for validation instead of the legacy verifyReceipt endpoint.

___

### transactionReceipt

• `Optional` **transactionReceipt**: `undefined`

Apple ios 6 transaction receipt.

**`Deprecated`**

Use `appStoreReceipt` or `signedTransaction`

___

### type

• **type**: ``"ios-appstore"``

Value `"ios-appstore"`
