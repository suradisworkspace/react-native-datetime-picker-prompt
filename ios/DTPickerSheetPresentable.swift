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
