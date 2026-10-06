import NitroModules
import UIKit

private struct PickValidationError: Error {
  let message: String
}

class DatetimePickerPrompt: HybridDatetimePickerPromptSpec {
  private var isShowing = false
  // iOS 26+ gets DTPickerGlassSheetController, earlier versions keep
  // DTPickerBottomSheetController unchanged — see DTPickerSheetPresentable.
  private weak var activeSheet: (any DTPickerSheetPresentable)?

  public func pick(options: NitroPickOptions) throws -> Promise<Variant_NullType_String> {
    let promise = Promise<Variant_NullType_String>()

    if isShowing {
      promise.reject(withError: RuntimeError("E_ALREADY_VISIBLE: A picker is already being shown."))
      return promise
    }

    let timeZone: TimeZone
    if let identifier = options.timezone {
      guard let resolved = TimeZone(identifier: identifier) else {
        promise.reject(withError: RuntimeError("E_INVALID_TIMEZONE: \"\(identifier)\" is not a recognized IANA timezone identifier."))
        return promise
      }
      timeZone = resolved
    } else {
      timeZone = .current
    }

    let minimumDate: Date?
    let maximumDate: Date?
    var defaultValue: Date?
    do {
      minimumDate = try Self.parseOptionalIsoDate(options.minimumDate, field: "minimumDate")
      maximumDate = try Self.parseOptionalIsoDate(options.maximumDate, field: "maximumDate")
      defaultValue = try Self.parseOptionalIsoDate(options.defaultValue, field: "defaultValue")
    } catch {
      let message = (error as? PickValidationError)?.message ?? "E_UNKNOWN: \(error)"
      promise.reject(withError: RuntimeError(message))
      return promise
    }

    if let min = minimumDate, let max = maximumDate,
       Self.compareEffective(min, max, mode: options.mode, timeZone: timeZone) == .orderedDescending {
      promise.reject(withError: RuntimeError("E_INVALID_RANGE: minimumDate is after maximumDate."))
      return promise
    }

    // Clamp an out-of-range defaultValue rather than rejecting — see docs/adr/0007.
    if let min = minimumDate, let value = defaultValue,
       Self.compareEffective(value, min, mode: options.mode, timeZone: timeZone) == .orderedAscending {
      defaultValue = min
    }
    if let max = maximumDate, let value = defaultValue,
       Self.compareEffective(value, max, mode: options.mode, timeZone: timeZone) == .orderedDescending {
      defaultValue = max
    }

    isShowing = true

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      guard let presenter = Self.topViewController() else {
        self.isShowing = false
        promise.reject(withError: RuntimeError("E_NO_WINDOW: No key window to present the picker on."))
        return
      }

      let onCancel: () -> Void = { [weak self] in
        self?.isShowing = false
        self?.activeSheet = nil
        promise.resolve(withResult: .first(.null))
      }
      let onConfirm: (Date) -> Void = { [weak self] date in
        self?.isShowing = false
        self?.activeSheet = nil
        promise.resolve(withResult: .second(Self.isoString(from: date)))
      }

      let sheet: any DTPickerSheetPresentable
      if #available(iOS 26, *) {
        sheet = DTPickerGlassSheetController(
          mode: options.mode,
          minimumDate: minimumDate,
          maximumDate: maximumDate,
          defaultValue: defaultValue,
          timeZone: timeZone,
          onCancel: onCancel,
          onConfirm: onConfirm
        )
      } else {
        sheet = DTPickerBottomSheetController(
          mode: options.mode,
          minimumDate: minimumDate,
          maximumDate: maximumDate,
          defaultValue: defaultValue,
          timeZone: timeZone,
          onCancel: onCancel,
          onConfirm: onConfirm
        )
      }
      self.activeSheet = sheet
      presenter.present(sheet, animated: false)
    }

    return promise
  }

  public func dismiss() throws {
    DispatchQueue.main.async { [weak self] in
      self?.activeSheet?.dismissProgrammatically()
    }
  }

  private static func topViewController() -> UIViewController? {
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }

    guard var top = keyWindow?.rootViewController else { return nil }
    while let presented = top.presentedViewController {
      top = presented
    }
    return top
  }

  private static func isoString(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private static func parseIsoDate(_ string: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string)
  }

  private static func parseOptionalIsoDate(_ string: String?, field: String) throws -> Date? {
    guard let string else { return nil }
    guard let date = parseIsoDate(string) else {
      throw PickValidationError(message: "E_INVALID_RANGE: \(field) \"\(string)\" is not a valid ISO 8601 date string.")
    }
    return date
  }

  /// Mode-aware comparison, matching what's actually meaningful per `PickMode`:
  /// `.date` compares only the calendar day, `.time` only the time-of-day,
  /// `.datetime` the full instant. See docs/adr/0007.
  private static func compareEffective(_ lhs: Date, _ rhs: Date, mode: NitroPickMode, timeZone: TimeZone) -> ComparisonResult {
    switch mode {
    case .datetime:
      return lhs.compare(rhs)
    case .date:
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = timeZone
      return calendar.startOfDay(for: lhs).compare(calendar.startOfDay(for: rhs))
    case .time:
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = timeZone
      let lhsSeconds = secondsIntoDay(lhs, calendar: calendar)
      let rhsSeconds = secondsIntoDay(rhs, calendar: calendar)
      if lhsSeconds == rhsSeconds { return .orderedSame }
      return lhsSeconds < rhsSeconds ? .orderedAscending : .orderedDescending
    }
  }

  private static func secondsIntoDay(_ date: Date, calendar: Calendar) -> Int {
    let components = calendar.dateComponents([.hour, .minute, .second], from: date)
    return (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
  }
}
