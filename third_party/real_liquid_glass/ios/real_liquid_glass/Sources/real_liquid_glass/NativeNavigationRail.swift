import Flutter
import UIKit

final class NativeNavigationRailViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeNavigationRailPlatformView(frame: frame, viewId: viewId,
      args: args as? [String: Any] ?? [:], messenger: messenger)
  }
}

private final class NativeNavigationRailPlatformView: NSObject, FlutterPlatformView {
  private let host: NavigationRailHostView
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, args: [String: Any], messenger: FlutterBinaryMessenger) {
    host = NavigationRailHostView(frame: frame)
    channel = FlutterMethodChannel(name: "real_liquid_glass/navigation_rail_\(viewId)", binaryMessenger: messenger)
    super.init()
    host.onSelection = { [weak self] index in
      self?.channel.invokeMethod("selected", arguments: ["index": index])
    }
    host.apply(args)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(FlutterMethodNotImplemented) }
      guard call.method == "update" else { return result(FlutterMethodNotImplemented) }
      self.host.apply(call.arguments as? [String: Any] ?? [:])
      result(nil)
    }
  }

  func view() -> UIView { host }
  deinit { channel.setMethodCallHandler(nil) }
}

/// Public UIButton glass configurations supply the material and press response;
/// an opaque Flutter NavigationRail must not cover these buttons.
private final class NavigationRailHostView: UIView {
  private let scrollView = UIScrollView()
  private var buttons: [UIButton] = []
  private var badges: [UIView] = []
  private var lastArgs: NSDictionary?
  private var itemHeight: CGFloat = 72
  var onSelection: ((Int) -> Void)?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    scrollView.backgroundColor = .clear
    scrollView.showsVerticalScrollIndicator = false
    scrollView.contentInsetAdjustmentBehavior = .never
    addSubview(scrollView)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func apply(_ args: [String: Any]) {
    let values = args as NSDictionary
    guard lastArgs != values, let items = args["items"] as? [[String: Any]] else { return }
    lastArgs = values
    let current = (args["currentIndex"] as? NSNumber)?.intValue ?? 0
    let fontSize = CGFloat((args["fontSize"] as? NSNumber)?.doubleValue ?? 12)
    itemHeight = max(72, 48 + ceil(fontSize * 1.3))
    if let dark = args["dark"] as? Bool { overrideUserInterfaceStyle = dark ? .dark : .light }
    semanticContentAttribute = (args["rtl"] as? Bool ?? false) ? .forceRightToLeft : .forceLeftToRight
    if buttons.count != items.count {
      buttons.forEach { $0.removeFromSuperview() }
      badges.forEach { $0.removeFromSuperview() }
      buttons = items.indices.map { index in
        let button = UIButton(type: .system)
        button.tag = index
        button.addTarget(self, action: #selector(didSelect(_:)), for: .primaryActionTriggered)
        scrollView.addSubview(button)
        return button
      }
      badges = items.map { _ in
        let badge = UIView()
        badge.isUserInteractionEnabled = false
        badge.isAccessibilityElement = false
        badge.layer.cornerRadius = 4
        scrollView.addSubview(badge)
        return badge
      }
    }
    for (index, item) in items.enumerated() {
      let button = buttons[index]
      let selected = index == current
      let label = item["label"] as? String ?? ""
      let symbol = item[selected ? "selectedSymbol" : "symbol"] as? String ?? "circle"
      let foreground = (args[selected ? "selectedColor" : "foregroundColor"] as? NSNumber)?.int64Value ?? 0xFF000000
      if #available(iOS 26.0, *) {
        var config: UIButton.Configuration = selected ? .prominentGlass() : .glass()
        config.cornerStyle = .capsule
        config.baseForegroundColor = GlassHostView.color(argb: foreground)
        if selected, let tint = args["selectedBackgroundColor"] as? NSNumber {
          config.baseBackgroundColor = GlassHostView.color(argb: tint.int64Value)
        }
        config.image = UIImage(systemName: symbol,
          withConfiguration: UIImage.SymbolConfiguration(pointSize: 24))
        config.imagePlacement = .top
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        config.title = selected ? label : nil
        config.titleLineBreakMode = .byTruncatingTail
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
          var outgoing = incoming
          outgoing.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
          return outgoing
        }
        button.configuration = config
      }
      button.accessibilityLabel = label
      button.accessibilityTraits = selected ? [.button, .selected] : [.button]
      badges[index].isHidden = (args["badgeIndex"] as? NSNumber)?.intValue != index
      let badgeColor = (args["badgeColor"] as? NSNumber)?.int64Value ?? 0xFFFF0000
      badges[index].backgroundColor = GlassHostView.color(argb: badgeColor)
    }
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    scrollView.frame = bounds
    for index in buttons.indices {
      let y = 8 + CGFloat(index) * (itemHeight + 8)
      buttons[index].frame = CGRect(x: 8, y: y, width: max(0, bounds.width - 16), height: itemHeight)
      badges[index].frame = CGRect(x: bounds.width - 23, y: y + 10, width: 8, height: 8)
    }
    scrollView.contentSize = CGSize(width: bounds.width, height: 8 + CGFloat(buttons.count) * (itemHeight + 8))
    scrollView.isScrollEnabled = scrollView.contentSize.height > bounds.height
    scrollView.delaysContentTouches = scrollView.isScrollEnabled
  }

  @objc private func didSelect(_ sender: UIButton) { onSelection?(sender.tag) }
}
