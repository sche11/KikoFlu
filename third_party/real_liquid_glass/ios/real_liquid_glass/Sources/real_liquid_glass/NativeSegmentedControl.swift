import Flutter
import UIKit

final class NativeSegmentedControlViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    NativeSegmentedControlPlatformView(
      frame: frame, viewId: viewId, args: args as? [String: Any] ?? [:], messenger: messenger)
  }
}

private final class NativeSegmentedControlPlatformView: NSObject, FlutterPlatformView {
  private let host: SegmentedControlHostView
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, args: [String: Any], messenger: FlutterBinaryMessenger) {
    host = SegmentedControlHostView(frame: frame)
    channel = FlutterMethodChannel(
      name: "real_liquid_glass/segmented_control_\(viewId)", binaryMessenger: messenger)
    super.init()
    host.onSelection = { [weak self] id in
      self?.channel.invokeMethod("selected", arguments: ["id": id])
    }
    host.apply(args)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(FlutterMethodNotImplemented) }
      switch call.method {
      case "update":
        self.host.apply(call.arguments as? [String: Any] ?? [:])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { host }

  deinit { channel.setMethodCallHandler(nil) }
}

/// Let UIKit own the entire control: the glass, pressed selection lens, touch
/// tracking and animation. Do not overlay Flutter labels or a second glass
/// background; those cannot participate in the system's content magnification.
private final class SegmentedControlHostView: UIView {
  private struct Item: Equatable {
    let id: String
    let label: String
    let symbol: String?
  }

  private let scrollView = SegmentedControlScrollView()
  private let control = UISegmentedControl()
  private var items: [Item] = []
  private var widths: [CGFloat] = []
  private var normalImages: [UIImage] = []
  private var selectedImages: [UIImage] = []
  private var segments: [SegmentAccessibilityElement] = []
  private var selectedId: String?
  private var fontSize: CGFloat = 14
  private var normalColor: Int64 = 0xFF000000
  private var selectedColor: Int64 = 0xFF000000
  private var rtl = false
  private var revealSelection = false
  var onSelection: ((String) -> Void)?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    scrollView.backgroundColor = .clear
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.alwaysBounceVertical = false
    // A quick swipe scrolls an overflowing group. After a stationary press,
    // UIScrollView's standard UIControl handling lets the control keep tracking.
    scrollView.delaysContentTouches = true
    scrollView.addSubview(control)
    addSubview(scrollView)
    control.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)
    control.isAccessibilityElement = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func apply(_ args: [String: Any]) {
    guard let rawItems = args["items"] as? [[String: Any]] else { return }
    let nextItems = rawItems.compactMap { item -> Item? in
      guard let id = item["id"] as? String, let label = item["label"] as? String else {
        return nil
      }
      return Item(id: id, label: label, symbol: item["symbol"] as? String)
    }
    guard nextItems.count >= 2 else { return }
    let nextFontSize = CGFloat((args["fontSize"] as? NSNumber)?.doubleValue ?? 14)
    let nextNormalColor = (args["foregroundColor"] as? NSNumber)?.int64Value ?? normalColor
    let nextSelectedColor = (args["selectedColor"] as? NSNumber)?.int64Value ?? selectedColor
    let nextRTL = args["rtl"] as? Bool ?? false
    let itemsChanged = items != nextItems
    let imagesChanged = itemsChanged || fontSize != nextFontSize
      || normalColor != nextNormalColor || selectedColor != nextSelectedColor || rtl != nextRTL
    let nextId = args["selectedId"] as? String
    let index = nextItems.firstIndex(where: { $0.id == nextId }) ?? 0
    let selectionChanged = selectedId != nextItems[index].id
    if control.isTracking && (itemsChanged || control.selectedSegmentIndex != index) {
      control.cancelTracking(with: nil)
    }
    items = nextItems
    fontSize = nextFontSize
    normalColor = nextNormalColor
    selectedColor = nextSelectedColor
    rtl = nextRTL
    selectedId = items[index].id
    if let dark = args["dark"] as? Bool {
      overrideUserInterfaceStyle = dark ? .dark : .light
    }
    control.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight

    if itemsChanged {
      control.removeAllSegments()
      for (index, item) in items.enumerated() {
        control.insertSegment(withTitle: item.label, at: index, animated: false)
      }
      buildAccessibilityElements()
    }
    if imagesChanged {
      normalImages = items.map { image(for: $0, color: normalColor) }
      selectedImages = items.map { image(for: $0, color: selectedColor) }
    }
    let requestedWidths = args["widths"] as? [NSNumber] ?? []
    let nextWidths = items.indices.map { index in
      let requested = requestedWidths.indices.contains(index)
        ? CGFloat(requestedWidths[index].doubleValue) : 0
      return max(requested, normalImages[index].size.width + 24)
    }
    if itemsChanged || widths != nextWidths {
      widths = nextWidths
      for index in items.indices { control.setWidth(widths[index], forSegmentAt: index) }
    }
    if control.selectedSegmentIndex != index { control.selectedSegmentIndex = index }
    if imagesChanged || selectionChanged { updateSelectionAppearance() }
    revealSelection = revealSelection || itemsChanged || selectionChanged
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    scrollView.frame = bounds
    control.frame = CGRect(
      x: 4, y: 4, width: widths.reduce(0, +), height: max(0, bounds.height - 8))
    scrollView.contentSize = CGSize(width: control.frame.maxX + 4, height: bounds.height)
    let overflows = scrollView.contentSize.width > bounds.width
    if scrollView.isScrollEnabled != overflows { scrollView.isScrollEnabled = overflows }
    scrollView.delaysContentTouches = overflows
    for index in segments.indices {
      segments[index].accessibilityFrameInContainerSpace = segmentRect(at: index)
    }
    if revealSelection && !control.isTracking && !scrollView.isTracking {
      revealSelection = false
      let index = control.selectedSegmentIndex
      if items.indices.contains(index) {
        let rect = control.convert(segmentRect(at: index).insetBy(dx: -4, dy: 0), to: scrollView)
        scrollView.scrollRectToVisible(rect, animated: false)
      }
    }
  }

  @objc private func selectionChanged() {
    let index = control.selectedSegmentIndex
    guard items.indices.contains(index), selectedId != items[index].id else { return }
    selectedId = items[index].id
    updateSelectionAppearance()
    onSelection?(items[index].id)
    revealSelection = true
    // valueChanged can arrive before UIKit ends tracking this touch.
    DispatchQueue.main.async { [weak self] in self?.setNeedsLayout() }
  }

  private func updateSelectionAppearance() {
    for index in items.indices {
      let selected = index == control.selectedSegmentIndex
      control.setImage(selected ? selectedImages[index] : normalImages[index], forSegmentAt: index)
      segments[index].accessibilityTraits = selected ? [.button, .selected] : [.button]
    }
  }

  private func segmentRect(at index: Int) -> CGRect {
    let leading = widths.prefix(index).reduce(0, +)
    let x = rtl ? control.bounds.width - leading - widths[index] : leading
    return CGRect(x: x, y: 0, width: widths[index], height: control.bounds.height)
  }

  private func buildAccessibilityElements() {
    // UISegmentedControl accepts either a title or an image, not both. The
    // combined icon+label images below therefore need explicit text semantics.
    segments = items.map { item in
      let element = SegmentAccessibilityElement(accessibilityContainer: control)
      element.isAccessibilityElement = true
      element.accessibilityLabel = item.label
      element.activate = { [weak self] in
        guard let self, let index = self.items.firstIndex(where: { $0.id == item.id }) else {
          return false
        }
        self.control.selectedSegmentIndex = index
        self.selectionChanged()
        return true
      }
      return element
    }
    control.accessibilityElements = segments
  }

  private func image(for item: Item, color: Int64) -> UIImage {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
      .foregroundColor: GlassHostView.color(argb: color),
    ]
    let title = item.label as NSString
    let textSize = title.size(withAttributes: attributes)
    let symbol = item.symbol.flatMap {
      UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18))?
        .withTintColor(GlassHostView.color(argb: color), renderingMode: .alwaysOriginal)
    }
    let iconWidth: CGFloat = symbol == nil ? 0 : 24
    let size = CGSize(width: ceil(textSize.width) + iconWidth, height: max(18, ceil(textSize.height)))
    return UIGraphicsImageRenderer(size: size).image { _ in
      if let symbol {
        let scale = min(18 / symbol.size.width, 18 / symbol.size.height)
        let iconSize = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        symbol.draw(in: CGRect(
          x: (rtl ? size.width - 18 : 0) + (18 - iconSize.width) / 2,
          y: (size.height - iconSize.height) / 2, width: iconSize.width, height: iconSize.height))
      }
      title.draw(at: CGPoint(x: rtl ? 0 : iconWidth, y: (size.height - textSize.height) / 2),
        withAttributes: attributes)
    }.withRenderingMode(.alwaysOriginal)
  }
}

private final class SegmentAccessibilityElement: UIAccessibilityElement {
  var activate: (() -> Bool)?

  override func accessibilityActivate() -> Bool { activate?() ?? false }
}

private final class SegmentedControlScrollView: UIScrollView {
  override func touchesShouldCancel(in view: UIView) -> Bool {
    var ancestor: UIView? = view
    while let candidate = ancestor, candidate !== self {
      if candidate is UISegmentedControl { return false }
      ancestor = candidate.superview
    }
    return super.touchesShouldCancel(in: view)
  }
}
