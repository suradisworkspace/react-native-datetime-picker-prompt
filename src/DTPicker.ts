import type { PickOptions } from './PickMode';

function unsupported(): never {
  throw new Error(
    'react-native-datetime-picker-prompt is only supported on iOS and Android.'
  );
}

export const DTPicker = {
  async pick(_options: PickOptions): Promise<string | null> {
    unsupported();
  },

  dismiss(): void {
    unsupported();
  },
};
