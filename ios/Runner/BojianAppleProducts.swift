import Flutter
import StoreKit

@MainActor
final class BojianAppleProducts {
  private struct BridgeError: Error {
    let code: String
    let message: String
  }

  private let channel: FlutterMethodChannel
  private var updatesTask: Task<Void, Never>?
  private var verifiedTransactions: [String: Transaction] = [:]
  private var purchasing = false
  /// One-time memberships are non-renewing; the auto-renew choice buys the
  /// auto-renewable products of the same plan.
  private static let productTypes: [String: Product.ProductType] = [
    "cn.kelance.bojian.membership.month": .nonRenewable,
    "cn.kelance.bojian.membership.year": .nonRenewable,
    "cn.kelance.bojian.membership.month.auto": .autoRenewable,
    "cn.kelance.bojian.membership.year.auto": .autoRenewable,
    "cn.kelance.bojian.template.9": .nonConsumable,
    "cn.kelance.bojian.template.10": .nonConsumable,
    "cn.kelance.bojian.template.11": .nonConsumable,
    "cn.kelance.bojian.template.12": .nonConsumable,
    // Members buy extra AI uses as fixed consumable packs.
    "cn.kelance.bojian.ai.create.1": .consumable,
    "cn.kelance.bojian.ai.create.5": .consumable,
    "cn.kelance.bojian.ai.create.10": .consumable,
    "cn.kelance.bojian.ai.polish.1": .consumable,
    "cn.kelance.bojian.ai.polish.5": .consumable,
    "cn.kelance.bojian.ai.polish.10": .consumable,
    "cn.kelance.bojian.ai.text.10": .consumable,
    "cn.kelance.bojian.ai.text.50": .consumable,
    "cn.kelance.bojian.ai.text.100": .consumable,
  ]
  private static let productIDs = Set(productTypes.keys)

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "cn.kelance.bojian/apple_products",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      Task { @MainActor in
        do {
          switch call.method {
          case "products": try await self.products(call, result)
          case "purchase": try await self.purchase(call, result)
          case "unfinished": result(await self.transactions(restoring: false))
          case "restore":
            // User initiated only; may ask for Apple account authentication.
            try await AppStore.sync()
            result(await self.transactions(restoring: true))
          case "finish": try await self.finish(call, result)
          case "manageSubscriptions": try await self.manageSubscriptions(result)
          default: result(FlutterMethodNotImplemented)
          }
        } catch let error as BridgeError {
          result(FlutterError(code: error.code, message: error.message, details: nil))
        } catch {
          result(FlutterError(
            code: "STORE_UNAVAILABLE",
            message: "无法连接 App Store，请稍后重试或恢复购买",
            details: nil
          ))
        }
      }
    }
    updatesTask = Task { [weak self] in
      for await verification in Transaction.updates {
        guard !Task.isCancelled, let self else { return }
        switch verification {
        case .verified(let transaction):
          if let value = self.transactionValue(transaction) {
            self.channel.invokeMethod("transaction", arguments: value)
          }
        case .unverified(let transaction, _):
          if Self.productIDs.contains(transaction.productID) {
            self.channel.invokeMethod("transactionError", arguments: ["code": "UNVERIFIED"])
          }
        }
      }
    }
  }

  deinit { updatesTask?.cancel() }

  private func products(_ call: FlutterMethodCall, _ result: FlutterResult) async throws {
    guard let args = call.arguments as? [String: Any],
          let identifiers = args["productIDs"] as? [String],
          !identifiers.isEmpty,
          identifiers.count <= Self.productIDs.count,
          Set(identifiers).isSubset(of: Self.productIDs) else {
      throw BridgeError(code: "INVALID_PRODUCTS", message: "商品参数无效")
    }
    let products = try await Product.products(for: Set(identifiers))
    guard products.allSatisfy({ Self.productTypes[$0.id] == $0.type }) else {
      throw BridgeError(code: "INVALID_PRODUCT_TYPE", message: "商品暂不可用")
    }
    let foundIDs = Set(products.map(\.id))
    let values: [[String: Any]] = products.sorted { $0.id < $1.id }.map { product in
      [
        "id": product.id,
        "displayName": product.displayName,
        "description": product.description,
        "displayPrice": product.displayPrice,
        "price": NSDecimalNumber(decimal: product.price).stringValue,
        "currencyCode": product.priceFormatStyle.currencyCode,
      ]
    }
    result([
      "products": values,
      "unavailableProductIDs": Set(identifiers).subtracting(foundIDs).sorted(),
    ])
  }

  private func purchase(_ call: FlutterMethodCall, _ result: FlutterResult) async throws {
    guard !purchasing,
          let args = call.arguments as? [String: Any],
          let identifier = args["productID"] as? String,
          Self.productIDs.contains(identifier),
          let rawToken = args["appAccountToken"] as? String,
          let token = UUID(uuidString: rawToken) else {
      throw BridgeError(code: "INVALID_PURCHASE", message: "购买参数无效或订单仍在处理中")
    }
    purchasing = true
    defer { purchasing = false }
    guard let product = try await Product.products(for: [identifier]).first,
          product.id == identifier, Self.productTypes[identifier] == product.type else {
      throw BridgeError(code: "PRODUCT_UNAVAILABLE", message: "该商品暂不可购买，请稍后刷新")
    }
    switch try await product.purchase(options: [.appAccountToken(token)]) {
    case .success(let verification):
      switch verification {
      case .verified(let transaction):
        guard let value = transactionValue(transaction) else {
          throw BridgeError(code: "INVALID_TRANSACTION", message: "交易信息暂不可用，请恢复购买重试")
        }
        // Dart submits the transaction to our server. Never finish here.
        result(["status": "verified", "transaction": value])
      case .unverified:
        result(["status": "unverified"])
      }
    case .pending: result(["status": "pending"])
    case .userCancelled: result(["status": "cancelled"])
    @unknown default:
      throw BridgeError(code: "UNKNOWN_PURCHASE", message: "购买状态待确认，请恢复购买重试")
    }
  }

  private func environment(_ transaction: Transaction) -> String? {
    let value: String
    if #available(iOS 16.0, *) {
      value = transaction.environment.rawValue
    } else {
      // StoreKit 2's signed transaction JSON also includes environment on iOS 15.
      let object = try? JSONSerialization.jsonObject(with: transaction.jsonRepresentation)
      value = (object as? [String: Any])?["environment"] as? String ?? ""
    }
    return ["Production", "Sandbox"].contains(value) ? value : nil
  }

  /// Called exclusively with .verified StoreKit results. Unverified payloads
  /// never cross the bridge and never get stored in the finishable queue.
  private func transactionValue(_ transaction: Transaction) -> [String: Any]? {
    guard Self.productIDs.contains(transaction.productID),
          Self.productTypes[transaction.productID] == transaction.productType,
          let environment = environment(transaction) else { return nil }
    let identifier = String(transaction.id)
    verifiedTransactions["\(environment):\(identifier)"] = transaction
    var value: [String: Any] = [
      "transactionID": identifier,
      "productID": transaction.productID,
      "environment": environment,
    ]
    if let token = transaction.appAccountToken {
      value["appAccountToken"] = token.uuidString.lowercased()
    }
    return value
  }

  private func transactions(restoring: Bool) async -> [String: Any] {
    var values: [[String: Any]] = []
    var unverified = false
    // Non-renewing memberships can disappear from currentEntitlements after a
    // year, and every auto-renewal is its own transaction. Restore uses the
    // full history; the backend computes real expiry.
    let sequence = restoring ? Transaction.all : Transaction.unfinished
    for await verification in sequence {
      switch verification {
      case .verified(let transaction):
        if let value = transactionValue(transaction) { values.append(value) }
      case .unverified(let transaction, _):
        if Self.productIDs.contains(transaction.productID) { unverified = true }
      }
    }
    return ["transactions": values, "unverified": unverified]
  }

  /// Auto-renewal can only be turned off in the App Store's subscription sheet.
  private func manageSubscriptions(_ result: FlutterResult) async throws {
    guard let scene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive }) else {
      throw BridgeError(code: "STORE_UNAVAILABLE", message: "暂时无法打开订阅管理，请在系统设置中管理")
    }
    try await AppStore.showManageSubscriptions(in: scene)
    result(nil)
  }

  private func finish(_ call: FlutterMethodCall, _ result: FlutterResult) async throws {
    guard let args = call.arguments as? [String: Any],
          let identifier = args["transactionID"] as? String,
          let environment = args["environment"] as? String,
          let rawToken = args["appAccountToken"] as? String,
          let token = UUID(uuidString: rawToken),
          let transaction = verifiedTransactions["\(environment):\(identifier)"],
          transaction.appAccountToken == token else {
      throw BridgeError(code: "INVALID_TRANSACTION", message: "订单尚未确认，请恢复购买重试")
    }
    await transaction.finish()
    // Keep the verified value for idempotent acknowledgements: purchase() and
    // Transaction.updates can both deliver the same transaction to Dart.
    result(nil)
  }
}
