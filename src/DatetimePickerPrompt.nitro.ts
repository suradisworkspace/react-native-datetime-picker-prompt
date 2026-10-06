import type { HybridObject } from 'react-native-nitro-modules';

export type NitroPickMode = 'date' | 'time' | 'datetime';

export interface NitroPickOptions {
  mode: NitroPickMode;
  minimumDate?: string;
  maximumDate?: string;
  defaultValue?: string;
  timezone?: string;
}

export interface DatetimePickerPrompt extends HybridObject<{
  ios: 'swift';
  android: 'kotlin';
}> {
  pick(options: NitroPickOptions): Promise<string | null>;
  dismiss(): void;
}
