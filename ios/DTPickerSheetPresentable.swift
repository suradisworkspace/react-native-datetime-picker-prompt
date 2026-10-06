import UIKit

/// Common interface for whichever picker sheet controller is actually presented —
/// `DTPickerBottomSheetController` (iOS <26) or `DTPickerGlassSheetController`
/// (iOS 26+). Lets `DatetimePickerPrompt` hold a single `activeSheet` reference
/// and call `dismiss()` without caring which one is live. See
/// docs/adr/0005-keyboard-matched-sheet-chrome.md for why there are two.
protocol DTPickerSheetPresentable: UIViewController {
  /// Invoked by the HybridObject for a programmatic `DTPicker.dismiss()` call.
  func dismissProgrammatically()
}

/// Shared by both picker sheet controllers — the `iosDisplay` prop maps
/// directly onto `UIDatePickerStyle`, nothing controller-specific about it.
extension NitroIosPickerDisplay {
  var uiDatePickerStyle: UIDatePickerStyle {
    switch self {
    case .wheel: return .wheels
    case .inline: return .inline
    }
  }
}

extension NitroPickMode {
  /// Resolves the actual `UIDatePickerStyle` to use. `.time` mode always
  /// forces `.wheels`, ignoring `iosDisplay` — `.inline`'s whole benefit is
  /// calendar-grid month/year navigation, which doesn't exist for a
  /// time-only picker, and it visibly looks worse there (direct feedback).
  func resolvedDatePickerStyle(iosDisplay: NitroIosPickerDisplay?) -> UIDatePickerStyle {
    guard self != .time else { return .wheels }
    return iosDisplay?.uiDatePickerStyle ?? .wheels
  }
}
