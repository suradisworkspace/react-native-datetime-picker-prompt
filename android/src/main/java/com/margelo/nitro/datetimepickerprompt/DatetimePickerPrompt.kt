package com.margelo.nitro.datetimepickerprompt

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.DialogInterface
import android.text.format.DateFormat
import com.facebook.proguard.annotations.DoNotStrip
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.NullType
import com.margelo.nitro.core.Promise
import java.text.ParseException
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

private class PickValidationException(message: String) : Exception(message)

@DoNotStrip
class DatetimePickerPrompt : HybridDatetimePickerPromptSpec() {
  @Volatile
  private var isShowing = false
  private var activeDialog: DialogInterface? = null

  override fun pick(options: NitroPickOptions): Promise<Variant_NullType_String> {
    val promise = Promise<Variant_NullType_String>()

    if (isShowing) {
      promise.reject(Exception("E_ALREADY_VISIBLE: A picker is already being shown."))
      return promise
    }

    val activity = NitroModules.applicationContext?.currentActivity
    if (activity == null) {
      promise.reject(Exception("E_NO_ACTIVITY: No active Activity to attach the picker to."))
      return promise
    }

    val timeZone: TimeZone
    val minimumDate: Calendar?
    val maximumDate: Calendar?
    var defaultValue: Calendar?
    try {
      timeZone = resolveTimeZone(options.timezone)
      minimumDate = parseOptionalIsoDate(options.minimumDate, timeZone, "minimumDate")
      maximumDate = parseOptionalIsoDate(options.maximumDate, timeZone, "maximumDate")
      defaultValue = parseOptionalIsoDate(options.defaultValue, timeZone, "defaultValue")
    } catch (e: PickValidationException) {
      promise.reject(e)
      return promise
    }

    if (minimumDate != null && maximumDate != null &&
      compareEffective(minimumDate, maximumDate, options.mode) > 0
    ) {
      promise.reject(Exception("E_INVALID_RANGE: minimumDate is after maximumDate."))
      return promise
    }

    // Clamp an out-of-range defaultValue rather than rejecting — see docs/adr/0007.
    if (minimumDate != null && defaultValue != null &&
      compareEffective(defaultValue, minimumDate, options.mode) < 0
    ) {
      defaultValue = minimumDate
    }
    if (maximumDate != null && defaultValue != null &&
      compareEffective(defaultValue, maximumDate, options.mode) > 0
    ) {
      defaultValue = maximumDate
    }

    isShowing = true

    activity.runOnUiThread {
      val calendar = defaultValue ?: Calendar.getInstance(timeZone)
      val is24Hour = DateFormat.is24HourFormat(activity)

      fun finish(result: Variant_NullType_String) {
        isShowing = false
        activeDialog = null
        promise.resolve(result)
      }

      fun resolveCancelled() {
        finish(Variant_NullType_String.create(NullType.NULL))
      }

      fun resolveConfirmed() {
        finish(Variant_NullType_String.create(toIsoString(calendar)))
      }

      fun showTimeDialog() {
        val timeDialog = TimePickerDialog(
          activity,
          { _, hour, minute ->
            calendar.set(Calendar.HOUR_OF_DAY, hour)
            calendar.set(Calendar.MINUTE, minute)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            resolveConfirmed()
          },
          calendar.get(Calendar.HOUR_OF_DAY),
          calendar.get(Calendar.MINUTE),
          is24Hour
        )
        // Android's native TimePicker has no min/max-time API — a picked time
        // outside [minimumDate, maximumDate] resolves as picked. See docs/adr/0007.
        timeDialog.setOnCancelListener { resolveCancelled() }
        activeDialog = timeDialog
        timeDialog.show()
      }

      fun showDateDialog(onConfirmed: () -> Unit) {
        val dateDialog = DatePickerDialog(
          activity,
          { _, year, month, day ->
            calendar.set(year, month, day)
            onConfirmed()
          },
          calendar.get(Calendar.YEAR),
          calendar.get(Calendar.MONTH),
          calendar.get(Calendar.DAY_OF_MONTH)
        )
        // DatePicker.minDate/maxDate always interpret millis via the device's own
        // default timezone (no public API to change that), so re-anchor to the
        // same calendar-day numbers under the device's timezone rather than
        // passing a raw cross-timezone instant through. See docs/adr/0007.
        minimumDate?.let { dateDialog.datePicker.minDate = reanchorToDeviceTimeZone(it).timeInMillis }
        maximumDate?.let { dateDialog.datePicker.maxDate = reanchorToDeviceTimeZone(it).timeInMillis }
        dateDialog.setOnCancelListener { resolveCancelled() }
        activeDialog = dateDialog
        dateDialog.show()
      }

      when (options.mode) {
        NitroPickMode.DATE -> showDateDialog(onConfirmed = { resolveConfirmed() })
        NitroPickMode.TIME -> showTimeDialog()
        NitroPickMode.DATETIME -> showDateDialog(onConfirmed = { showTimeDialog() })
      }
    }

    return promise
  }

  override fun dismiss() {
    val activity = NitroModules.applicationContext?.currentActivity ?: return
    activity.runOnUiThread {
      // cancel() (not dismiss()) so the existing onCancelListener resolves the
      // pending promise with null, same outcome as a user-initiated Cancel.
      activeDialog?.cancel()
    }
  }

  private fun toIsoString(calendar: Calendar): String {
    val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
    formatter.timeZone = TimeZone.getTimeZone("UTC")
    return formatter.format(calendar.time)
  }

  private fun resolveTimeZone(identifier: String?): TimeZone {
    if (identifier == null) return TimeZone.getDefault()
    // TimeZone.getTimeZone() silently falls back to GMT for unrecognized ids —
    // check against the real available-ids list instead so a typo is rejected.
    if (!TimeZone.getAvailableIDs().contains(identifier)) {
      throw PickValidationException("E_INVALID_TIMEZONE: \"$identifier\" is not a recognized IANA timezone identifier.")
    }
    return TimeZone.getTimeZone(identifier)
  }

  private fun parseOptionalIsoDate(value: String?, timeZone: TimeZone, field: String): Calendar? {
    if (value == null) return null
    val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
    formatter.timeZone = TimeZone.getTimeZone("UTC")
    val parsed = try {
      formatter.parse(value)
    } catch (e: ParseException) {
      null
    } ?: throw PickValidationException("E_INVALID_RANGE: $field \"$value\" is not a valid ISO 8601 date string.")
    val calendar = Calendar.getInstance(timeZone)
    calendar.time = parsed
    return calendar
  }

  /**
   * Mode-aware comparison, matching what's actually meaningful per `PickMode`:
   * `DATE` compares only the calendar day, `TIME` only the time-of-day,
   * `DATETIME` the full instant. See docs/adr/0007.
   */
  private fun compareEffective(lhs: Calendar, rhs: Calendar, mode: NitroPickMode): Int {
    return when (mode) {
      NitroPickMode.DATETIME -> lhs.timeInMillis.compareTo(rhs.timeInMillis)
      NitroPickMode.DATE -> {
        val l = lhs.get(Calendar.YEAR) * 10000 + lhs.get(Calendar.MONTH) * 100 + lhs.get(Calendar.DAY_OF_MONTH)
        val r = rhs.get(Calendar.YEAR) * 10000 + rhs.get(Calendar.MONTH) * 100 + rhs.get(Calendar.DAY_OF_MONTH)
        l.compareTo(r)
      }
      NitroPickMode.TIME -> {
        val l = lhs.get(Calendar.HOUR_OF_DAY) * 3600 + lhs.get(Calendar.MINUTE) * 60 + lhs.get(Calendar.SECOND)
        val r = rhs.get(Calendar.HOUR_OF_DAY) * 3600 + rhs.get(Calendar.MINUTE) * 60 + rhs.get(Calendar.SECOND)
        l.compareTo(r)
      }
    }
  }

  /**
   * Re-anchors a Calendar's Y/M/D fields onto the device's default timezone at
   * midnight. See the comment at the `minDate`/`maxDate` call site.
   */
  private fun reanchorToDeviceTimeZone(source: Calendar): Calendar {
    val target = Calendar.getInstance()
    target.clear()
    target.set(source.get(Calendar.YEAR), source.get(Calendar.MONTH), source.get(Calendar.DAY_OF_MONTH))
    return target
  }
}
