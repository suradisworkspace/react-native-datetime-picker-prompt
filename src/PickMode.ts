export enum PickMode {
  Date = 'date',
  Time = 'time',
  DateTime = 'datetime',
}

export type PickModeType = `${PickMode}`;

/**
 * `UIDatePickerStyle` choice for the iOS picker — `'wheel'` is `.wheels`
 * (the current look), `'inline'` is `.inline` (a calendar grid for the date
 * portion, letting you jump to a far date via month/year navigation instead
 * of spinning through individual days). No effect on Android, which has no
 * such distinction (`DatePickerDialog`/`TimePickerDialog` are OS-themed,
 * no style choice).
 *
 * Ignored for `PickMode.Time` — always `.wheels` there regardless of this
 * value. `'inline'`'s whole benefit is calendar navigation, which doesn't
 * exist for a time-only picker, and it visibly looks worse than wheels there.
 */
export type IosPickerDisplay = 'wheel' | 'inline';

export interface PickOptions {
  mode: PickModeType;
  /** ISO 8601 UTC string. */
  minimumDate?: string;
  /** ISO 8601 UTC string. */
  maximumDate?: string;
  /** ISO 8601 UTC string. */
  defaultValue?: string;
  /** IANA identifier, e.g. `'Asia/Bangkok'`. */
  timezone?: string;
  /** iOS only. Default `'wheel'`. See {@link IosPickerDisplay}. */
  iosDisplay?: IosPickerDisplay;
}

export type DTPickerErrorCode =
  | 'E_ALREADY_VISIBLE'
  | 'E_NO_ACTIVITY'
  | 'E_NO_WINDOW'
  | 'E_INVALID_RANGE'
  | 'E_INVALID_TIMEZONE'
  | 'E_UNKNOWN';

export class DTPickerError extends Error {
  code: DTPickerErrorCode;

  constructor(code: DTPickerErrorCode, message: string) {
    super(message);
    this.name = 'DTPickerError';
    this.code = code;
  }
}

const KNOWN_CODES: readonly string[] = [
  'E_ALREADY_VISIBLE',
  'E_NO_ACTIVITY',
  'E_NO_WINDOW',
  'E_INVALID_RANGE',
  'E_INVALID_TIMEZONE',
];

function isKnownCode(value: string): value is DTPickerErrorCode {
  return KNOWN_CODES.includes(value);
}

/**
 * Native (Swift/Kotlin) rejections only carry a plain message string across
 * the Nitro boundary — there is no structured error payload. Both platforms
 * encode the error code as a `"CODE: message"` prefix by convention; this
 * parses that convention back into a `DTPickerError` with a real `.code`.
 */
export function parseNativeError(error: unknown): DTPickerError {
  const rawMessage = error instanceof Error ? error.message : String(error);
  const match = /^([A-Z_]+):\s*(.*)$/s.exec(rawMessage);
  const code = match?.[1];
  const message = match?.[2];

  if (code !== undefined && message !== undefined && isKnownCode(code)) {
    return new DTPickerError(code, message);
  }

  return new DTPickerError('E_UNKNOWN', rawMessage);
}
