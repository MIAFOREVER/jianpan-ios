import SwiftUI

struct AddSymbolView: View {
    @EnvironmentObject private var store: MarketStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var customMarket: Market = .aShare

    private var matches: [AssetDefinition] {
        guard !query.isEmpty else { return AssetCatalog.all }
        let needle = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return AssetCatalog.all.filter { asset in
            asset.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle)
                || asset.symbol.localizedCaseInsensitiveContains(needle)
                || asset.displaySymbol.localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !query.isEmpty {
                    Section("自定义代码") {
                        HStack {
                            Picker("市场", selection: $customMarket) {
                                ForEach(Market.allCases) { market in
                                    Text(market.title).tag(market)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(JPTheme.primaryText)

                            Spacer()

                            Button {
                                guard let asset = AssetCatalog.customAsset(code: query, market: customMarket) else { return }
                                store.add(asset)
                                query = ""
                            } label: {
                                Label("添加 \(query.uppercased())", systemImage: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .tint(JPTheme.primaryText)
                        }
                    }
                }

                ForEach(Market.allCases) { market in
                    let assets = matches.filter { $0.market == market }
                    if !assets.isEmpty {
                        Section(market.title) {
                            ForEach(assets) { asset in
                                Button {
                                    if !store.contains(asset) { store.add(asset) }
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(asset.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(JPTheme.primaryText)
                                            Text(asset.symbol)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(JPTheme.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: store.contains(asset) ? "checkmark.circle.fill" : "plus.circle")
                                            .font(.title3)
                                            .foregroundStyle(store.contains(asset) ? JPTheme.positive : JPTheme.primaryText)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(store.contains(asset))
                            }
                        }
                    }
                }

                if matches.isEmpty && query.isEmpty == false {
                    Section {
                        ContentUnavailableView("没有预设结果", systemImage: "magnifyingglass", description: Text("可使用上方“自定义代码”直接添加"))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(JPTheme.background)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "名称或代码")
            .navigationTitle("添加行情")
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

