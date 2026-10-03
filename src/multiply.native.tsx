import { NitroModules } from 'react-native-nitro-modules';
import type { DatetimePickerPrompt } from './DatetimePickerPrompt.nitro';

const DatetimePickerPromptHybridObject =
  NitroModules.createHybridObject<DatetimePickerPrompt>('DatetimePickerPrompt');

export function multiply(a: number, b: number): number {
  return DatetimePickerPromptHybridObject.multiply(a, b);
}
