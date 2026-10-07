//
//  AXInjectDemoApp.swift — SwiftUI 界面：破解态成品（四项全绿 · 功能解锁）
//
//  结构：对抗台（启动即注入=破解态，可复位/再注入逐步拆解）
//        功能台（自动化任务 + 快捷指令，统一受许可门禁）
//        日志台（全功能审计日志）
//        关于（设备 / 密钥指纹 / 取证对应）
//
import SwiftUI
import UIKit
import UserNotifications
import CryptoKit

@main
struct AXInjectDemoApp: App {
    init() {
        NotificationManager.shared.setup()
        AppState.shared.log("系统", "App 启动（破解态成品）")
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("对抗台", systemImage: "shield.lefthalf.filled") }
                FeaturesView()
                    .tabItem { Label("功能台", systemImage: "bolt.horizontal.circle") }
                LogView()
                    .tabItem { Label("日志台", systemImage: "list.bullet.rectangle") }
                AboutView()
                    .tabItem { Label("关于", systemImage: "info.circle") }
            }
            .environmentObject(AppState.shared)
        }
    }
}

// MARK: - 本地通知（自动化任务 / 快捷指令用）
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() {}

    func setup() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func send(_ title: String, _ body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                AppState.shared.log("通知", "未授权通知权限，无法发送")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let req = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
            center.add(req) { err in
                DispatchQueue.main.async {
                    if let err {
                        AppState.shared.log("通知", "发送失败：\(err.localizedDescription)")
                    } else {
                        AppState.shared.log("通知", "已发送：“\(title)”")
                    }
                }
            }
        }
    }
}

// MARK: - 对抗台（启动即破解态）
struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @State private var injected = false
    @State private var results: [CheckResult] = []
    @State private var events: [String] = []
    @State private var verdictText = ""
    @State private var verdictColor: Color = .gray

    private let injector = Injector.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // 状态徽标
                    HStack {
                        Image(systemName: injected ? "lock.open.fill" : "lock.fill")
                            .foregroundColor(injected ? .red : .gray)
                        Text(injected ? "已注入 · 破解态（四项全绿）" : "未注入 · 原始校验态（已到期）")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // 四项校验
                    VStack(spacing: 10) {
                        ForEach(results) { r in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: r.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(r.ok ? .green : .red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.name).font(.system(size: 15, weight: .semibold))
                                    Text(r.detail).font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // 结论横幅
                    Text(verdictText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(verdictColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    // 操作（供逐步拆解：复位看原始校验态 → 再注入看破解态）
                    HStack(spacing: 12) {
                        Button(action: doInject) {
                            Label("注入 hook（破解载荷）", systemImage: "syringe")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(injected)

                        Button("复位（看原始态）", action: doReset)
                            .buttonStyle(.bordered)
                            .disabled(!injected)
                    }
                    .frame(maxWidth: .infinity)

                    // 事件日志
                    if !events.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("注入日志").font(.system(size: 13, weight: .semibold))
                            ForEach(events, id: \.self) { e in
                                Text(e).font(.system(size: 12, design: .monospaced)).foregroundColor(.red)
                            }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Text("说明：本 App 复刻 AX Pro 取证发现的防御结构（__axseal ECDSA 封签 / 授权令牌验签 / 镜像白名单 / 到期判定）。“注入”= 把校验函数指针替换为恒真实现，即 fishhook / MSHookFunction 在真机破解包中的等价机制（H1 单点验签钩 + H2 时间钩 + 拆盾）。启动时已自动注入 → 打开即为破解态成品。仅供自有软件防御性验证。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("红队背景：破解者走全能签（企业证书）分发自包含注入包，非越狱设备可安装——内嵌 dylib 启动时先钩掉校验。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("AX 对抗台")
        }
        .onAppear {
            if !injector.applied { doInject() } else { rerun() }
        }
    }

    private func rerun() {
        results = naiveRun()
        let allOK = results.allSatisfy { $0.ok }
        if allOK {
            verdictText = ">>> 破解成功：全部校验被绕过，功能解锁"
            verdictColor = .red
        } else {
            verdictText = ">>> 功能受限（存在未通过的校验）"
            verdictColor = .gray
        }
        injected = injector.applied
        state.log("校验", allOK ? "四项全绿（破解态）" : "存在未通过项（受限态）")
    }

    private func doInject() {
        injector.inject()
        injected = injector.applied
        events = injector.events
        rerun()
    }

    private func doReset() {
        injector.reset()
        injected = false
        events = []
        rerun()
    }
}

// MARK: - 功能台（统一许可门禁：破解态全解锁 / 未注入全受限）
struct FeaturesView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: state.premiumUnlocked ? "lock.open.fill" : "lock.fill")
                            .foregroundColor(state.premiumUnlocked ? .green : .gray)
                        Text(state.premiumUnlocked ? "许可状态：已解锁（破解态）" : "许可状态：功能受限（未注入）")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                }

                Section("高级自动化任务（受许可门禁）") {
                    Button { runPremium("打开网页（Safari）") { FeaturesView.openURL("https://www.apple.com") } } label: {
                        row("safari", "打开网页（Safari）")
                    }
                    Button { runPremium("复制文本到剪贴板") { FeaturesView.copyToClipboard() } } label: {
                        row("doc.on.doc", "复制文本到剪贴板")
                    }
                    Button { runPremium("读取剪贴板内容") { FeaturesView.readClipboard() } } label: {
                        row("doc.text.magnifyingglass", "读取剪贴板内容")
                    }
                    Button { runPremium("发送本地通知") { FeaturesView.sendNotification() } } label: {
                        row("bell.badge", "发送本地通知")
                    }
                    Button { runPremium("触感反馈") { FeaturesView.haptic() } } label: {
                        row("iphone.radiowaves.left.and.right", "触感反馈")
                    }
                }

                Section("免费功能（不受门禁）") {
                    Button { state.bump("基础计数器") } label: {
                        row("plus.circle", "基础计数器 +1（当前 \(state.counters["基础计数器"] ?? 0)）")
                    }
                    Button { state.clearLog() } label: {
                        row("trash", "清空审计日志")
                    }
                }

                Section("快捷指令（模拟悬浮球面板）") {
                    Button { FeaturesView.openURL(UIApplication.openSettingsURLString) } label: {
                        row("gearshape", "打开系统设置")
                    }
                    Button { FeaturesView.openURL("https://www.baidu.com") } label: {
                        row("magnifyingglass", "打开百度搜索")
                    }
                    Button { FeaturesView.copyToClipboard() } label: {
                        row("doc.on.doc.fill", "复制“AX-PRO-DEMO”")
                    }
                }
            }
            .navigationTitle("AX 功能台")
        }
        .onAppear {
            state.log("门禁", state.premiumUnlocked ? "功能台进入：已解锁" : "功能台进入：受限")
        }
    }

    private func runPremium(_ name: String, _ action: () -> Void) {
        if state.premiumUnlocked {
            action()
            state.log("任务", "\(name) → 已执行（破解态解锁）")
        } else {
            state.log("任务", "\(name) → 门禁拒绝：功能受限（未注入）")
        }
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 28)
            Text(text).foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: 任务实现（真实 iOS 能力）
    private static func openURL(_ s: String) {
        guard let url = URL(string: s) else {
            AppState.shared.log("任务", "URL 无效：\(s)")
            return
        }
        UIApplication.shared.open(url) { ok in
            AppState.shared.log("任务", ok ? "已打开 \(s)" : "打开失败 \(s)")
        }
    }

    private static func copyToClipboard() {
        UIPasteboard.general.string = "AX-DEMO-\(Int(Date().timeIntervalSince1970))"
        AppState.shared.log("任务", "已复制演示文本到剪贴板")
    }

    private static func readClipboard() {
        let s = UIPasteboard.general.string ?? "（剪贴板为空）"
        AppState.shared.log("任务", "剪贴板内容：\(s)")
    }

    private static func sendNotification() {
        NotificationManager.shared.send("AX 自动化任务", "任务完成：\(Date())")
    }

    private static func haptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AppState.shared.log("任务", "触感反馈已触发")
    }
}

// MARK: - 日志台
struct LogView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationStack {
            List(state.events) { e in
                Text(e.text)
                    .font(.system(size: 12, design: .monospaced))
            }
            .navigationTitle("AX 审计日志")
        }
    }
}

// MARK: - 关于
struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("App") {
                    row("名称", "AX Inject Demo")
                    row("版本", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                    row("Bundle ID", Bundle.main.bundleIdentifier ?? "?")
                    row("部署目标", "iOS 16.0+")
                }
                Section("设备") {
                    row("机型", UIDevice.current.model)
                    row("系统", "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                }
                Section("密钥指纹（SHA-256）") {
                    row("封签公钥", fingerprint(Embedded.sealPubB64))
                    row("令牌公钥", fingerprint(Embedded.tokPubB64))
                }
                Section("取证对应") {
                    Text("__axseal（AXSLV001 + ECDSA P-256）→ 封签验签\n授权令牌 → 与封签共用验签入口（单点）\n_expirationTime → 到期判定\n镜像白名单 → load-command / _dyld 扫描\n\n破解机制：HookTable 等价于 GOT 重绑定（fishhook / MSHookFunction）——H1 单点验签钩一钩双废，H2 拨表回试用期，拆盾使镜像白名单失明。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("AX 关于")
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundColor(.secondary)
            Spacer()
            Text(v).font(.system(size: 13, design: .monospaced))
        }
    }

    private func fingerprint(_ b64: String) -> String {
        let digest = SHA256.hash(data: Data(b64.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
