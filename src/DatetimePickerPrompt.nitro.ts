import type { HybridObject } from 'react-native-nitro-modules';

export type NitroPickMode = 'date' | 'time' | 'datetime';

// iOS only — maps to UIDatePickerStyle.wheels/.inline. Unused on Android
// (DatePickerDialog/TimePickerDialog have no equivalent style choice); the
// field still exists on the generated Kotlin struct since this interface is
// shared, but DatetimePickerPrompt.kt never reads it.
export type NitroIosPickerDisplay = 'wheel' | 'inline';

export interface NitroPickOptions {
  mode: NitroPickMode;
  minimumDate?: string;
  maximumDate?: string;
  defaultValue?: string;
  timezone?: string;
  iosDisplay?: NitroIosPickerDisplay;
}

export interface DatetimePickerPrompt extends HybridObject<{
  ios: 'swift';
  android: 'kotlin';
}> {
  pick(options: NitroPickOptions): Promise<string | null>;
  dismiss(): void;
}
