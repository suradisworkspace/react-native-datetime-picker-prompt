import UIKit

/// iOS 26+ redesign: a floating card, styled after the AirPods pairing popup,
/// rather than the edge-to-edge bottom sheet `DTPickerBottomSheetController`
/// uses on iOS <26. See docs/adr/0005-keyboard-matched-sheet-chrome.md and the
/// `ios26-liquid-glass-design` design note for the accepted direction.
///
/// Built incrementally, one visual change at a time:
/// - Step 1 (done): outer shape — margins on all sides, all four corners rounded.
/// - Step 2 (done): `cardView`'s own base surface is real `UIGlassEffect`
///   material instead of a flat color.
/// - Step 3: the Cancel/Done toolbar replaced by a single prominent "Done"
///   pill plus a smaller, de-emphasized "Cancel" link. Backdrop blur removed
///   per direct feedback; backdrop is now dim-only, no blur.
/// - Step 3a (this pass, direct feedback): action bar moved back above the
///   picker — a bottom-of-a-tall-floating-card button is a harder reach than
///   one near the top. Both buttons are icon-only now (checkmark/xmark)
///   rather than text, matching iOS 26's own Done/Cancel icon convention.
/// - Later: a mode-derived header.
@available(iOS 26, *)
final class DTPickerGlassSheetController: UIViewController, DTPickerSheetPresentable {
  private static let keyboardAnimationOptions = UIView.AnimationOptions(rawValue: 7 << 16)
  private static let keyboardAnimationDuration: TimeInterval = 0.25

  // Backdrop: dim only, no blur — blur was removed per direct feedback.
  private static let overlayBackgroundColor = UIColor { _ in
    UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
  }

  // Floating-card geometry.
  private static let cardSideMargin: CGFloat = 16
  private static let cardBottomMargin: CGFloat = 16
  private static let cardCornerRadius: CGFloat = 32
  private static let actionBarHeight: CGFloat = 56
  private static let actionBarHorizontalInset: CGFloat = 20

  private let mode: NitroPickMode
  private let minimumDate: Date?
  private let maximumDate: Date?
  private let defaultValue: Date?
  private let timeZone: TimeZone
  private let onCancel: () -> Void
  private let onConfirm: (Date) -> Void

  private let backdropView = UIView()
  private let cardView = UIView()
  private let datePicker = UIDatePicker()
  private var hasPresented = false
  private var isClosing = false

  init(
    mode: NitroPickMode,
    minimumDate: Date?,
    maximumDate: Date?,
    defaultValue: Date?,
    timeZone: TimeZone,
    onCancel: @escaping () -> Void,
    onConfirm: @escaping (Date) -> Void
  ) {
    self.mode = mode
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

    // Floating card: margins on every side, every corner rounded — the AirPods
    // popup shape, unlike the edge-to-edge bottom sheet this replaces.
    cardView.layer.cornerRadius = Self.cardCornerRadius
    cardView.layer.cornerCurve = .continuous
    cardView.layer.maskedCorners = [
      .layerMinXMinYCorner, .layerMaxXMinYCorner,
      .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
    ]
    cardView.clipsToBounds = true
    cardView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cardView)
    cardView.addGestureRecognizer(
      UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    )

    // Real Liquid Glass material, not a flat color — `.regular` is the
    // adaptive frosted-chrome style (vs. `.clear`'s lighter, more refractive
    // look, meant for media). Not interactive: this is the card's own
    // background, not a control responding to a direct press.
    let glassEffect = UIGlassEffect(style: .regular)
    glassEffect.isInteractive = false
    let glassView = UIVisualEffectView(effect: glassEffect)
    glassView.translatesAutoresizingMaskIntoConstraints = false
    cardView.addSubview(glassView)
    NSLayoutConstraint.activate([
      glassView.topAnchor.constraint(equalTo: cardView.topAnchor),
      glassView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
      glassView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
      glassView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
    ])

    // Action bar back above the picker — a button at the bottom of a tall
    // floating card is a harder reach than one near the top (direct feedback).
    let actionBar = makeActionBar()
    actionBar.translatesAutoresizingMaskIntoConstraints = false
    cardView.addSubview(actionBar)

    // Clear, not the old flat RGB(40,40,42) — that was opaque and covered the
    // glass material (step 2) underneath, for the card's single largest area.
    let datePickerContainer = UIView()
    datePickerContainer.translatesAutoresizingMaskIntoConstraints = false
    datePickerContainer.backgroundColor = .clear
    datePickerContainer.addSubview(datePicker)
    cardView.addSubview(datePickerContainer)

    datePicker.preferredDatePickerStyle = .wheels
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

      cardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Self.cardSideMargin),
      cardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Self.cardSideMargin),
      cardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.cardBottomMargin),

      actionBar.topAnchor.constraint(equalTo: cardView.topAnchor),
      actionBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
      actionBar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
      actionBar.heightAnchor.constraint(equalToConstant: Self.actionBarHeight),

      datePickerContainer.topAnchor.constraint(equalTo: actionBar.bottomAnchor),
      datePickerContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
      datePickerContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
      datePickerContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

      datePicker.topAnchor.constraint(equalTo: datePickerContainer.topAnchor),
      datePicker.leadingAnchor.constraint(equalTo: datePickerContainer.leadingAnchor),
      datePicker.trailingAnchor.constraint(equalTo: datePickerContainer.trailingAnchor),
      datePicker.bottomAnchor.constraint(equalTo: datePickerContainer.bottomAnchor),
    ])
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard !hasPresented else { return }
    // Start off-screen (below the bottom edge) before the first layout pass settles
    // the card's real (content-hugging) height, then animate it into place.
    cardView.transform = CGAffineTransform(translationX: 0, y: cardView.bounds.height + Self.cardBottomMargin)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !hasPresented else { return }
    hasPresented = true
    UIView.animate(withDuration: Self.keyboardAnimationDuration, delay: 0, options: [Self.keyboardAnimationOptions]) {
      self.cardView.transform = .identity
    }
  }

  func dismissProgrammatically() {
    close { [weak self] in self?.onCancel() }
  }

  /// Single prominent "Done" pill + a smaller, de-emphasized "Cancel" — both
  /// icon-only (checkmark/xmark), matching iOS 26's own Done/Cancel icon
  /// convention rather than text. Accessibility labels are still read off
  /// `UIBarButtonItem`'s system items rather than hardcoded, so VoiceOver
  /// stays localized to the device language without a hand-maintained
  /// translation table — same property ADR 0006 established for the old
  /// toolbar, carried forward even though the visible label is gone.
  private func makeActionBar() -> UIView {
    let container = UIView()
    container.backgroundColor = .clear

    let doneTitle = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: nil).title ?? "Done"
    let cancelTitle = UIBarButtonItem(barButtonSystemItem: .cancel, target: nil, action: nil).title ?? "Cancel"

    var doneConfig = UIButton.Configuration.filled()
    doneConfig.image = UIImage(systemName: "checkmark")
    doneConfig.cornerStyle = .capsule
    doneConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    let doneButton = UIButton(configuration: doneConfig)
    doneButton.accessibilityLabel = doneTitle
    doneButton.addTarget(self, action: #selector(handleConfirmTapped), for: .touchUpInside)
    doneButton.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(doneButton)

    var cancelConfig = UIButton.Configuration.plain()
    cancelConfig.image = UIImage(systemName: "xmark")
    cancelConfig.baseForegroundColor = .secondaryLabel
    cancelConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
    let cancelButton = UIButton(configuration: cancelConfig)
    cancelButton.accessibilityLabel = cancelTitle
    cancelButton.addTarget(self, action: #selector(handleCancelTapped), for: .touchUpInside)
    cancelButton.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(cancelButton)

    NSLayoutConstraint.activate([
      cancelButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Self.actionBarHorizontalInset),
      cancelButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

      doneButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Self.actionBarHorizontalInset),
      doneButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])

    return container
  }

  private func close(completion: @escaping () -> Void) {
    guard !isClosing else { return }
    isClosing = true
    UIView.animate(
      withDuration: Self.keyboardAnimationDuration, delay: 0, options: [Self.keyboardAnimationOptions],
      animations: {
        self.cardView.transform = CGAffineTransform(translationX: 0, y: self.cardView.bounds.height + Self.cardBottomMargin)
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
    let translation = gesture.translation(in: cardView)
    switch gesture.state {
    case .changed:
      if translation.y > 0 {
        cardView.transform = CGAffineTransform(translationX: 0, y: translation.y)
      }
    case .ended, .cancelled:
      let velocity = gesture.velocity(in: cardView).y
      if translation.y > 80 || velocity > 500 {
        close { [weak self] in self?.onCancel() }
      } else {
        UIView.animate(withDuration: Self.keyboardAnimationDuration, delay: 0, options: [Self.keyboardAnimationOptions]) {
          self.cardView.transform = .identity
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
