import SwiftUI
import WebKit

struct CandlestickChart: View {
    let candles: [Candle]
    let timeZoneIdentifier: String

    var body: some View {
        LightweightChartView(candles: candles, timeZoneIdentifier: timeZoneIdentifier)
        .accessibilityLabel("\(candles.count) 根 K 线")
        .accessibilityHint("可横向拖动、双指缩放，长按查看开高低收")
    }
}

private struct LightweightChartView: UIViewRepresentable {
    let candles: [Candle]
    let timeZoneIdentifier: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "chartLogger")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.accessibilityLabel = "\(candles.count) 根 K 线"

        context.coordinator.render(
            candles: candles,
            timeZoneIdentifier: timeZoneIdentifier,
            in: webView
        )
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.render(
            candles: candles,
            timeZoneIdentifier: timeZoneIdentifier,
            in: webView
        )
        webView.accessibilityLabel = "\(candles.count) 根 K 线"
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private var renderedSignature: Int?

        func render(candles: [Candle], timeZoneIdentifier: String, in webView: WKWebView) {
            var hasher = Hasher()
            hasher.combine(candles)
            hasher.combine(timeZoneIdentifier)
            let signature = hasher.finalize()
            guard signature != renderedSignature else { return }
            renderedSignature = signature

            guard let scriptURL = Bundle.main.url(
                forResource: "lightweight-charts.standalone.production",
                withExtension: "js"
            ) else {
                webView.loadHTMLString(Self.unavailableDocument, baseURL: nil)
                return
            }

            let document = ChartDocument(
                candles: candles,
                timeZoneIdentifier: timeZoneIdentifier
            ).html
            webView.loadHTMLString(document, baseURL: scriptURL.deletingLastPathComponent())
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               url.scheme == "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url,
               url.scheme == "https" {
                UIApplication.shared.open(url)
            }
            return nil
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "chartLogger" else { return }
            print("Lightweight Charts:", message.body)
        }

        private static let unavailableDocument = """
        <!doctype html>
        <html lang="zh-CN">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          html,body{height:100%;margin:0;background:#14161A;color:#8C909A}
          body{display:grid;place-items:center;font:13px -apple-system,sans-serif}
        </style>
        <body>图表组件暂时不可用</body>
        </html>
        """
    }
}

private struct ChartDocument {
    private struct Bar: Encodable {
        let time: Int64
        let open: Double
        let high: Double
        let low: Double
        let close: Double
        let volume: Double
    }

    let candles: [Candle]
    let timeZoneIdentifier: String

    var html: String {
        let bars = normalizedBars
        let data = (try? JSONEncoder().encode(bars)) ?? Data("[]".utf8)
        let json = String(decoding: data, as: UTF8.self)
        let intraday = isIntraday ? "true" : "false"
        let precision = pricePrecision(for: bars.last?.close ?? 0)
        let minMove = pow(10, -Double(precision))

        return """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
          <style>
            :root { color-scheme: dark; }
            * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
            html, body {
              width: 100%; height: 100%; margin: 0; overflow: hidden;
              background: #14161A; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              -webkit-user-select: none; user-select: none; -webkit-touch-callout: none;
            }
            #chart { position: absolute; inset: 0; }
            #legend {
              position: absolute; z-index: 4; top: 7px; left: 9px; right: 62px;
              display: flex; align-items: center; gap: 8px; min-height: 20px;
              color: #8C909A; font-size: 10px; line-height: 1.2; pointer-events: none;
              font-variant-numeric: tabular-nums;
            }
            #legend .date { color: #696E78; }
            #legend .value { color: #D8D9D6; }
            #error {
              display: none; position: absolute; z-index: 5; inset: 0;
              place-items: center; padding: 20px; text-align: center;
              color: #8C909A; font-size: 12px; background: #14161A;
            }
          </style>
        </head>
        <body>
          <div id="chart"></div>
          <div id="legend" aria-hidden="true"></div>
          <div id="error">图表暂时无法显示</div>
          <script>
            function reportChartError(message) {
              const error = document.getElementById('error');
              error.style.display = 'grid';
              window.webkit?.messageHandlers?.chartLogger?.postMessage(String(message));
            }
            window.addEventListener('error', event => {
              reportChartError(event.error?.stack || event.message || '脚本加载失败');
            });
          </script>
          <script src="lightweight-charts.standalone.production.js"></script>
          <script>
            (() => {
              try {
              const bars = \(json);
              const intraday = \(intraday);
              const precision = \(precision);
              const minMove = \(minMove);
              const up = '#35E88F';
              const down = '#FF5C66';
              const chart = LightweightCharts.createChart(document.getElementById('chart'), {
                autoSize: true,
                layout: {
                  background: { type: LightweightCharts.ColorType.Solid, color: '#14161A' },
                  textColor: '#777C86',
                  fontSize: 11,
                  fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif',
                  attributionLogo: true
                },
                grid: {
                  vertLines: { color: 'rgba(255,255,255,0.045)' },
                  horzLines: { color: 'rgba(255,255,255,0.055)' }
                },
                crosshair: {
                  mode: LightweightCharts.CrosshairMode.Normal,
                  vertLine: {
                    color: 'rgba(226,228,232,0.46)',
                    width: 1,
                    style: LightweightCharts.LineStyle.Dashed,
                    labelBackgroundColor: '#292D34'
                  },
                  horzLine: {
                    color: 'rgba(226,228,232,0.46)',
                    width: 1,
                    style: LightweightCharts.LineStyle.Dashed,
                    labelBackgroundColor: '#292D34'
                  }
                },
                rightPriceScale: {
                  borderVisible: false,
                  entireTextOnly: true,
                  scaleMargins: { top: 0.12, bottom: 0.25 }
                },
                timeScale: {
                  borderVisible: false,
                  timeVisible: intraday,
                  secondsVisible: false,
                  rightOffset: 3,
                  barSpacing: intraday ? 8 : 7,
                  minBarSpacing: 3,
                  fixLeftEdge: true,
                  lockVisibleTimeRangeOnResize: true
                },
                handleScroll: {
                  mouseWheel: true,
                  pressedMouseMove: true,
                  horzTouchDrag: true,
                  vertTouchDrag: false
                },
                handleScale: {
                  axisPressedMouseMove: true,
                  mouseWheel: true,
                  pinch: true
                },
                kineticScroll: { mouse: true, touch: true },
                localization: { locale: 'zh-CN' }
              });

              const candleSeries = chart.addSeries(LightweightCharts.CandlestickSeries, {
                upColor: up,
                downColor: down,
                wickUpColor: up,
                wickDownColor: down,
                borderVisible: false,
                priceFormat: { type: 'price', precision, minMove },
                priceLineVisible: true,
                lastValueVisible: true
              });

              const volumeSeries = chart.addSeries(LightweightCharts.HistogramSeries, {
                priceScaleId: 'volume',
                priceFormat: { type: 'volume' },
                priceLineVisible: false,
                lastValueVisible: false
              });
              chart.priceScale('volume').applyOptions({
                visible: false,
                scaleMargins: { top: 0.79, bottom: 0.02 }
              });

              candleSeries.setData(bars.map(({ time, open, high, low, close }) => ({
                time, open, high, low, close
              })));
              volumeSeries.setData(bars.map(({ time, open, close, volume }) => ({
                time,
                value: volume,
                color: close >= open ? 'rgba(53,232,143,0.24)' : 'rgba(255,92,102,0.24)'
              })));

              const legend = document.getElementById('legend');
              const number = new Intl.NumberFormat('zh-CN', {
                minimumFractionDigits: 0,
                maximumFractionDigits: precision
              });
              const date = new Intl.DateTimeFormat('zh-CN', intraday
                ? { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'UTC' }
                : { year: 'numeric', month: '2-digit', day: '2-digit', timeZone: 'UTC' }
              );

              function updateLegend(bar) {
                if (!bar) return;
                const tone = bar.close >= bar.open ? up : down;
                legend.innerHTML =
                  `<span class="date">${date.format(new Date(bar.time * 1000))}</span>` +
                  `<span>开 <b class="value">${number.format(bar.open)}</b></span>` +
                  `<span>高 <b class="value">${number.format(bar.high)}</b></span>` +
                  `<span>低 <b class="value">${number.format(bar.low)}</b></span>` +
                  `<span>收 <b style="color:${tone}">${number.format(bar.close)}</b></span>`;
              }

              updateLegend(bars[bars.length - 1]);
              chart.subscribeCrosshairMove(param => {
                if (!param.time || !param.point ||
                    param.point.x < 0 || param.point.y < 0 ||
                    param.point.x > document.body.clientWidth ||
                    param.point.y > document.body.clientHeight) {
                  updateLegend(bars[bars.length - 1]);
                  return;
                }
                updateLegend(param.seriesData.get(candleSeries));
              });
              chart.timeScale().fitContent();
              } catch (error) {
                reportChartError(error?.stack || String(error));
              }
            })();
          </script>
        </body>
        </html>
        """
    }

    private var normalizedBars: [Bar] {
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        var byTimestamp: [Int64: Candle] = [:]
        for candle in candles {
            let unixTime = Int64(candle.date.timeIntervalSince1970)
            let offset = Int64(timeZone.secondsFromGMT(for: candle.date))
            byTimestamp[unixTime + offset] = candle
        }
        return byTimestamp
            .sorted { $0.key < $1.key }
            .map { timestamp, candle in
                Bar(
                    time: timestamp,
                    open: candle.open,
                    high: candle.high,
                    low: candle.low,
                    close: candle.close,
                    volume: candle.volume
                )
            }
    }

    private var isIntraday: Bool {
        guard let first = candles.min(by: { $0.date < $1.date })?.date,
              let last = candles.max(by: { $0.date < $1.date })?.date else {
            return false
        }
        return last.timeIntervalSince(first) < 60 * 60 * 48
    }

    private func pricePrecision(for value: Double) -> Int {
        let magnitude = abs(value)
        if magnitude >= 1 { return 2 }
        if magnitude >= 0.01 { return 4 }
        return 6
    }
}
