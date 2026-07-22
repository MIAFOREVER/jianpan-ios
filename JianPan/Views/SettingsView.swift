import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "viewfinder.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(JPTheme.primaryText)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("简盘")
                                .font(.headline)
                                .foregroundStyle(JPTheme.primaryText)
                            Text("专注价格，少一点噪音")
                                .font(.caption)
                                .foregroundStyle(JPTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("行情") {
                    LabeledContent("覆盖市场", value: "A 股 · 港股 · 美股 · 加密")
                    LabeledContent("数据模式", value: "网络行情 + 本地缓存")
                    LabeledContent("刷新方式", value: "下拉刷新")
                }

                Section("隐私") {
                    Label("不需要登录", systemImage: "person.crop.circle.badge.xmark")
                    Label("不收集个人数据", systemImage: "hand.raised")
                    Label("自选列表仅保存在本机", systemImage: "iphone")
                }

                Section {
                    Text("行情来自公开网络接口，可能存在延迟、中断或数据差异。简盘仅用于信息展示，不构成投资建议，也不应作为交易下单的唯一依据。")
                        .font(.footnote)
                        .foregroundStyle(JPTheme.secondaryText)
                } header: {
                    Text("风险提示")
                }

                Section {
                    LabeledContent("版本", value: "1.1.0")
                    LabeledContent("开源协议", value: "MIT")
                }
            }
            .scrollContentBackground(.hidden)
            .background(JPTheme.background)
            .navigationTitle("关于简盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(JPTheme.primaryText)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
