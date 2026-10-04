import UIKit

/// See docs/adr/0004-platform-specific-picker-ui.md and docs/adr/0005-keyboard-matched-sheet-chrome.md.
final class DTPickerBottomSheetController: UIViewController {
  // `7 << 16` is UIKit's private keyboard animation curve, packed into the public AnimationOptions bitmask.
  private static let keyboardAnimationOptions = UIView.AnimationOptions(rawValue: 7 << 16)
  private static let keyboardAnimationDuration: TimeInterval = 0.25

  // Sampled from the real keyboard — UIInputView(inputViewStyle: .keyboard) doesn't render this material standalone.
  private static let keyboardBackgroundColor = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 44 / 255, green: 44 / 255, blue: 44 / 255, alpha: 1.0)
      : UIColor(red: 209 / 255, green: 212 / 255, blue: 217 / 255, alpha: 1.0)
  }

  private let mode: NitroPickMode
  private let cancelText: String?
  private let confirmText: String?
  private let minimumDate: Date?
  private let maximumDate: Date?
  private let defaultValue: Date?
  private let timeZone: TimeZone
  private let onCancel: () -> Void
  private let onConfirm: (Date) -> Void

  private let backdropView = UIView()
  private let sheetView = UIView()
  private let datePicker = UIDatePicker()
  private var hasPresented = false
  private var isClosing = false

  init(
    mode: NitroPickMode,
    cancelText: String?,
    confirmText: String?,
    minimumDate: Date?,
    maximumDate: Date?,
    defaultValue: Date?,
    timeZone: TimeZone,
    onCancel: @escaping () -> Void,
    onConfirm: @escaping (Date) -> Void
  ) {
    self.mode = mode
    self.cancelText = cancelText
    self.confirmText = confirmText
    self.minimumDate = minimumDate
    self.maximumDate = maximumDate
    self.defaultValue = defaultValue
    self.timeZone = timeZone
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

    sheetView.backgroundColor = Self.keyboardBackgroundColor
    sheetView.layer.cornerRadius = 12
    sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    sheetView.clipsToBounds = true
    sheetView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(sheetView)
    sheetView.addGestureRecognizer(
      UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    )

    let toolbar = makeToolbar()
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    sheetView.addSubview(toolbar)

    datePicker.preferredDatePickerStyle = .wheels
    datePicker.datePickerMode = mode.uiDatePickerMode
    datePicker.timeZone = timeZone
    datePicker.minimumDate = minimumDate
    datePicker.maximumDate = maximumDate
    if let defaultValue {
      datePicker.date = defaultValue
    }
    datePicker.translatesAutoresizingMaskIntoConstraints = false
    sheetView.addSubview(datePicker)

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

      datePicker.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
      datePicker.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
      datePicker.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
      datePicker.bottomAnchor.constraint(equalTo: sheetView.safeAreaLayoutGuide.bottomAnchor),
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
    let toolbar = UIToolbar()
    toolbar.isTranslucent = false
    toolbar.barTintColor = Self.keyboardBackgroundColor
    toolbar.clipsToBounds = true

    // No override → UIBarButtonItem's system item renders Apple's own localized
    // title, matching the device language for free. See docs/adr/0005.
    let cancelItem = cancelText.map {
      UIBarButtonItem(title: $0, style: .plain, target: self, action: #selector(handleCancelTapped))
    } ?? UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(handleCancelTapped))

    let confirmItem = confirmText.map {
      UIBarButtonItem(title: $0, style: .done, target: self, action: #selector(handleConfirmTapped))
    } ?? UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(handleConfirmTapped))

    let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    toolbar.items = [cancelItem, flexibleSpace, confirmItem]

    return toolbar
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
