import { NitroModules } from 'react-native-nitro-modules';
import type { DatetimePickerPrompt } from './DatetimePickerPrompt.nitro';
import { parseNativeError, type PickOptions } from './PickMode';

const DatetimePickerPromptHybridObject =
  NitroModules.createHybridObject<DatetimePickerPrompt>('DatetimePickerPrompt');

export const DTPicker = {
  async pick(options: PickOptions): Promise<string | null> {
    try {
      return await DatetimePickerPromptHybridObject.pick(options);
    } catch (error) {
      throw parseNativeError(error);
    }
  },

  dismiss(): void {
    DatetimePickerPromptHybridObject.dismiss();
  },
};
