import UIKit

/// Used on iOS <26 — see DTPickerGlassSheetController for the iOS 26+ design.
/// See docs/adr/0004-platform-specific-picker-ui.md and docs/adr/0005-keyboard-matched-sheet-chrome.md.
final class DTPickerBottomSheetController: UIViewController, DTPickerSheetPresentable {
  // `7 << 16` is UIKit's private keyboard animation curve, packed into the public AnimationOptions bitmask.
  private static let keyboardAnimationOptions = UIView.AnimationOptions(rawValue: 7 << 16)
  private static let keyboardAnimationDuration: TimeInterval = 0.25

  // iOS 26+ system overlay style: semi-transparent dark background with blur
  private static let overlayBackgroundColor = UIColor { traits in
    UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
  }

  // Hairline divider color
  private static let dividerColor = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 80 / 255, green: 80 / 255, blue: 80 / 255, alpha: 0.3)
      : UIColor(red: 200 / 255, green: 200 / 255, blue: 200 / 255, alpha: 0.3)
  }

  private let mode: NitroPickMode
  private let minimumDate: Date?
  private let maximumDate: Date?
  private let defaultValue: Date?
  private let timeZone: TimeZone
  private let iosDisplay: NitroIosPickerDisplay?
  private let onCancel: () -> Void
  private let onConfirm: (Date) -> Void

  private let backdropView = UIView()
  private let sheetView = UIView()
  private let datePicker = UIDatePicker()
  private var hasPresented = false
  private var isClosing = false

  init(
    mode: NitroPickMode,
    minimumDate: Date?,
    maximumDate: Date?,
    defaultValue: Date?,
    timeZone: TimeZone,
    iosDisplay: NitroIosPickerDisplay?,
    onCancel: @escaping () -> Void,
    onConfirm: @escaping (Date) -> Void
  ) {
    self.mode = mode
    self.minimumDate = minimumDate
    self.maximumDate = maximumDate
    self.defaultValue = defaultValue
    self.timeZone = timeZone
    self.iosDisplay = iosDisplay
    self.onCancel = onCancel
    self.onConfirm = onConfirm
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .overFullScreen
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear

    backdropView.backgroundColor = .clear
    backdropView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(backdropView)
    backdropView.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(handleBackdropTap))
    )

    // Add blur effect behind the sheet
    let blurEffect = UIBlurEffect(style: .dark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.translatesAutoresizingMaskIntoConstraints = false
    backdropView.addSubview(blurView)
    NSLayoutConstraint.activate([
      blurView.topAnchor.constraint(equalTo: backdropView.topAnchor),
      blurView.leadingAnchor.constraint(equalTo: backdropView.leadingAnchor),
      blurView.trailingAnchor.constraint(equalTo: backdropView.trailingAnchor),
      blurView.bottomAnchor.constraint(equalTo: backdropView.bottomAnchor),
    ])

    // Semi-transparent overlay
    let overlayView = UIView()
    overlayView.backgroundColor = Self.overlayBackgroundColor
    overlayView.translatesAutoresizingMaskIntoConstraints = false
    backdropView.addSubview(overlayView)
    NSLayoutConstraint.activate([
      overlayView.topAnchor.constraint(equalTo: backdropView.topAnchor),
      overlayView.leadingAnchor.constraint(equalTo: backdropView.leadingAnchor),
      overlayView.trailingAnchor.constraint(equalTo: backdropView.trailingAnchor),
      overlayView.bottomAnchor.constraint(equalTo: backdropView.bottomAnchor),
    ])

    sheetView.backgroundColor = UIColor(red: 30 / 255, green: 30 / 255, blue: 32 / 255, alpha: 0.95)
    sheetView.layer.cornerRadius = 16
    sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    sheetView.clipsToBounds = true
    sheetView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(sheetView)
    sheetView.addGestureRecognizer(
      UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    )
    
    let datePickerContainer = UIView()
    datePickerContainer.translatesAutoresizingMaskIntoConstraints = false
    datePickerContainer.backgroundColor = UIColor(red: 40 / 255, green: 40 / 255, blue: 42 / 255, alpha: 1.0)
    datePickerContainer.addSubview(datePicker)
    sheetView.addSubview(datePickerContainer)
    
    let toolbar = makeToolbar()
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    sheetView.addSubview(toolbar)

    datePicker.preferredDatePickerStyle = mode.resolvedDatePickerStyle(iosDisplay: iosDisplay)
    datePicker.datePickerMode = mode.uiDatePickerMode
    
    datePicker.timeZone = timeZone
    datePicker.minimumDate = minimumDate
    datePicker.maximumDate = maximumDate
    if let defaultValue {
      datePicker.date = defaultValue
    }
    datePicker.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      backdropView.topAnchor.constraint(equalTo: view.topAnchor),
      backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      toolbar.topAnchor.constraint(equalTo: sheetView.topAnchor),
      toolbar.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
      toolbar.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
      toolbar.heightAnchor.constraint(equalToConstant: 44),
      
      datePickerContainer.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
      datePickerContainer.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
      datePickerContainer.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
      datePickerContainer.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor),

      datePicker.topAnchor.constraint(equalTo: datePickerContainer.topAnchor),
      datePicker.leadingAnchor.constraint(equalTo: datePickerContainer.leadingAnchor),
      datePicker.trailingAnchor.constraint(equalTo: datePickerContainer.trailingAnchor),
      datePicker.bottomAnchor.constraint(equalTo: datePickerContainer.safeAreaLayoutGuide.bottomAnchor),
    ])
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard !hasPresented else { return }
    // Start off-screen (below the bottom edge) before the first layout pass settles
    // the sheet's real (content-hugging) height, then animate it into place.
    sheetView.transform = CGAffineTransform(translationX: 0, y: sheetView.bounds.height)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !hasPresented else { return }
    hasPresented = true
    UIView.animate(withDuration: Self.keyboardAnimationDuration, delay: 0, options: [Self.keyboardAnimationOptions]) {
      self.sheetView.transform = .identity
    }
  }

  /// Invoked by the HybridObject for a programmatic `DTPicker.dismiss()` call.
  func dismissProgrammatically() {
    close { [weak self] in self?.onCancel() }
  }

  private func makeToolbar() -> UIView {
    let container = UIView()
    container.backgroundColor = .clear

    let toolbar = UIToolbar()
    toolbar.isTranslucent = false
    toolbar.barTintColor = UIColor(red: 30 / 255, green: 30 / 255, blue: 32 / 255, alpha: 0.95)
    toolbar.clipsToBounds = true
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(toolbar)

    // Always system items, never a custom title — Apple's own localized title
    // renders automatically (device language, zero translation data), and on
    // iOS 26+ these auto-render as icons (✕ / ✓) per the Liquid Glass design
    // language. A custom title would never get that icon treatment on any iOS
    // version, which is exactly why there's no override here. See docs/adr/0005
    // and docs/adr/0006.
    let cancelItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(handleCancelTapped))
    let confirmItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(handleConfirmTapped))

    let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    toolbar.items = [cancelItem, flexibleSpace, confirmItem]

    // Add hairline divider below toolbar
    let divider = UIView()
    divider.backgroundColor = Self.dividerColor
    divider.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(divider)

    NSLayoutConstraint.activate([
      toolbar.topAnchor.constraint(equalTo: container.topAnchor),
      toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      toolbar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      toolbar.heightAnchor.constraint(equalToConstant: 44),

      divider.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
      divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      divider.heightAnchor.constraint(equalToConstant: 1),
      divider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    return container
  }

  private func close(completion: @escaping () -> Void) {
    guard !isClosing else { return }
    isClosing = true
    UIView.animate(
      withDuration: Self.keyboardAnimationDuration, delay: 0, options: [Self.keyboardAnimationOptions],
      animations: {
        self.sheetView.transform = CGAffineTransform(translationX: 0, y: self.sheetView.bounds.height)
      },
      completion: { _ in
        self.presentingViewController?.dismiss(animated: false, completion: completion)
      }
    )
  }

  @objc private func handleBackdropTap() {
    close { [weak self] in self?.onCancel() }
  }

  @objc private func handleCancelTapped() {
    close { [weak self] in self?.onCancel() }
  }

  @objc private func handleConfirmTapped() {
    let date = datePicker.date
    close { [weak self] in self?.onConfirm(date) }
  }

  @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: sheetView)
    switch gesture.state {
    case .changed:
      if translation.y > 0 {
        sheetView.transform = CGAffineTransform(translationX: 0, y: translation.y)
      }
    case .ended, .cancelled:
      let velocity = gesture.velocity(in: sheetView).y
      if translation.y > 80 || velocity > 500 {
        close { [weak self] in self?.onCancel() }
      } else {
        UIView.animate(withDuration: Self.keyboardAnimationDuration, delay: 0, options: [Self.keyboardAnimationOptions]) {
          self.sheetView.transform = .identity
        }
      }
    default:
      break
    }
  }
}

private extension NitroPickMode {
  var uiDatePickerMode: UIDatePicker.Mode {
    switch self {
    case .date: return .date
    case .time: return .time
    case .datetime: return .dateAndTime
    }
  }
}
