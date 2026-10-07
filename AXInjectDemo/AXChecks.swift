//
//  AXChecks.swift — 校验逻辑 + 注入器（复刻取证发现的防御结构与红队钩子）
//
//  与 AX Pro 取证证据的对应关系：
//    __axseal（AXSLV001 + ECDSA P-256 封签）   -> ecdsaVerify(SEAL 公钥, "AXSLV001-seal")
//    ECDSA 授权令牌（与封签共用验签入口=单点）   -> ecdsaVerify(TOK 公钥, "AX-LICENSE-TOKEN")
//    load-command 扫描 / _dyld 镜像监控          -> imageScan()
//    _expirationTime 到期判定                    -> currentTime() < TRIAL_END
//
//  注入机制说明：程序通过 HookTable（模拟 GOT / 导入符号表）间接调用校验，
//  注入器把表项替换为恒真实现 —— 这正是 fishhook 重绑定 / MSHookFunction 在真机破解包里的等价物。
//
import Foundation
import Security
import Combine

// MARK: - 内嵌常量（构建时由脚本生成的真实 EC P-256 公钥与 DER 签名）
enum Embedded {
    static let sealPubB64 = "BBzUNUH9Kvk0MMsRpqqeuv2wN+lNeSHR+CbVRwV30fGNzf5e0dog78+puiKZYaiM85+wBV7RYGeqBcQq0/gFso0="
    static let sealSigB64 = "MEUCIHLBLkoM0YSOFCihu2XUnWAA2CrMAmS58cxPwwSmycxhAiEAvqtpNfDKnT0d5tmAa8qrTvDe8opqGetr+r0f8W9BKJM="
    static let tokPubB64  = "BOc9G8hAonLS0TEM43g1lr+blT7BtYtG4040jQoFhV5iL4997d1eOADHe8U1aPZtvKhjZFiwMzK64qzxphg5ecY="
    static let tokSigB64  = "MEQCICp2aqctTDHFvY9MM41uanP0stn50wNVt9euIDDp1ViHAiBqU+MDXmOphbGtZezhOefLYXB6ybe58iOkfiLRaaRhwg=="
    static let trialEnd: TimeInterval = 1780272000   // 2026-06-01 00:00 UTC（演示试用截止）
    static let hookTime: TimeInterval  = 1700000000   // 2023-11-14（H2 拨表目标）
}

enum Checks {
    static func secKey(from b64: String) -> SecKey? {
        guard let data = Data(base64Encoded: b64) else { return nil }
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
        ]
        return SecKeyCreateWithData(data as CFData, attrs as CFDictionary, nil)
    }

    static func ecdsaVerify(pubKey: SecKey, message: String, sigB64: String) -> Bool {
        guard let sig = Data(base64Encoded: sigB64) else { return false }
        let msg = Data(message.utf8)
        var err: Unmanaged<CFError>?
        return SecKeyVerifySignature(pubKey, .ecdsaSignatureMessageX962SHA256, msg as CFData, sig as CFData, &err)
    }

    static let sealKey = secKey(from: Embedded.sealPubB64)
    static let tokKey  = secKey(from: Embedded.tokPubB64)
}

// MARK: - Hook 表（模拟 GOT / 可被重绑定的导入符号）
final class HookTable {
    var verifySignature: (_ message: String, _ sigB64: String) -> Bool
    var currentTime: () -> TimeInterval
    var imageScan: () -> Bool

    init() {
        verifySignature = { message, sigB64 in
            let key = message.hasPrefix("AXSLV") ? Checks.sealKey : Checks.tokKey
            guard let key else { return false }
            return Checks.ecdsaVerify(pubKey: key, message: message, sigB64: sigB64)
        }
        currentTime = { Date().timeIntervalSince1970 }
        imageScan = { true } // naive 版示意：无注入时镜像干净
    }
}

// MARK: - 注入器（红队载荷）
final class Injector {
    static let shared = Injector()

    private let table = HookTable()
    private var originals: (verify: (String, String) -> Bool, time: () -> TimeInterval, scan: () -> Bool)?
    private(set) var applied = false
    private(set) var events: [String] = []

    var naive: HookTable { table }

    func inject() {
        guard !applied else { return }
        originals = (table.verifySignature, table.currentTime, table.imageScan)

        table.verifySignature = { _, _ in true }  // H1：单点验签钩 → 封签 + 授权令牌 一钩双废
        table.currentTime = { Embedded.hookTime } // H2：时间钩 → 拨回试用期内
        table.imageScan = { true }                // 拆盾：镜像白名单失明
        applied = true

        events = [
            "[H1] 单点验签钩：verifySignature → 恒真（封签+授权令牌 一钩双废）",
            "[H2] 时间钩：currentTime → 固定 2023-11-14（试用期内）",
            "[拆盾] 镜像扫描 → 恒真（白名单失明）",
        ]
    }

    func reset() {
        guard let o = originals else { return }
        table.verifySignature = o.verify
        table.currentTime = o.time
        table.imageScan = o.scan
        originals = nil
        applied = false
        events = []
    }
}

// MARK: - 四项校验结果
struct CheckResult: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let ok: Bool
    let detail: String
}

// MARK: - 校验路径（走 HookTable，可被注入）
func naiveRun() -> [CheckResult] {
    let t = Injector.shared.naive
    let sealOK = t.verifySignature("AXSLV001-seal", Embedded.sealSigB64)
    let tokOK  = t.verifySignature("AX-LICENSE-TOKEN", Embedded.tokSigB64)
    let imgOK  = t.imageScan()
    let now    = t.currentTime()
    let expOK  = now < Embedded.trialEnd

    return [
        CheckResult(name: "封签 __axseal", ok: sealOK,
                    detail: sealOK ? "ECDSA 验签通过" : "验签失败（二进制被改/被拒）"),
        CheckResult(name: "授权令牌 ECDSA", ok: tokOK,
                    detail: tokOK ? "令牌有效" : "令牌无效"),
        CheckResult(name: "镜像白名单", ok: imgOK,
                    detail: imgOK ? "干净" : "发现注入 → 熔断"),
        CheckResult(name: "到期校验", ok: expOK,
                    detail: expOK ? "试用期内（本地时钟 \(Int(now))）" : "已到期（本地时钟 \(Int(now))）"),
    ]
}

// MARK: - 全局门禁 + 审计日志（破解态 = 全功能解锁；未注入 = 受限，所有功能行为一致）
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var events: [AuditEvent] = []
    @Published var counters: [String: Int] = [:]

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// 许可门禁：注入破解态 → 全部高级功能解锁；复位后 → 受限
    var premiumUnlocked: Bool { Injector.shared.applied }

    func log(_ category: String, _ text: String) {
        let line = "[\(fmt.string(from: Date()))] [\(category)] \(text)"
        events.insert(AuditEvent(id: UUID(), text: line), at: 0)
        if events.count > 300 { events.removeLast(events.count - 300) }
    }

    func bump(_ key: String) {
        counters[key, default: 0] += 1
        log("计数", "\(key) → \(counters[key]!)")
    }

    func clearLog() {
        events.removeAll()
        log("系统", "审计日志已清空")
    }
}

struct AuditEvent: Identifiable {
    let id: UUID
    let text: String
}
