import { useState } from 'react';
import {
  Button,
  Text,
  View,
  StyleSheet,
  TextInput,
  useColorScheme,
} from 'react-native';
import {
  DTPicker,
  PickMode,
  DTPickerError,
  type PickModeType,
} from 'react-native-datetime-picker-prompt';

export default function App() {
  const scheme = useColorScheme();
  const isDark = scheme === 'dark';
  const theme = isDark ? darkStyles : lightStyles;
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const pick = async (mode: PickMode) => {
    setError(null);
    try {
      const value = await DTPicker.pick({ mode });
      setResult(value);
    } catch (e) {
      if (e instanceof DTPickerError) {
        setError(`${e.code}: ${e.message}`);
      } else {
        setError(String(e));
      }
    }
  };

  const pickWithBounds = async () => {
    setError(null);
    const now = new Date();
    const minimumDate = new Date(now.getTime() + 60 * 60 * 1000); // now + 1h
    const maximumDate = new Date(now.getTime() + 2 * 60 * 60 * 1000); // now + 2h
    try {
      const value = await DTPicker.pick({
        mode: PickMode.DateTime,
        minimumDate: minimumDate.toISOString(),
        maximumDate: maximumDate.toISOString(),
        defaultValue: now.toISOString(),
      });
      setResult(value);
    } catch (e) {
      if (e instanceof DTPickerError) {
        setError(`${e.code}: ${e.message}`);
      } else {
        setError(String(e));
      }
    }
  };

  const pickInTokyo = async () => {
    setError(null);
    try {
      const value = await DTPicker.pick({
        mode: PickMode.Time,
        timezone: 'Asia/Tokyo',
      });
      setResult(value);
    } catch (e) {
      if (e instanceof DTPickerError) {
        setError(`${e.code}: ${e.message}`);
      } else {
        setError(String(e));
      }
    }
  };

  const pickInline = async (mode: PickModeType) => {
    setError(null);
    try {
      const value = await DTPicker.pick({
        mode: mode,
        iosDisplay: 'inline',
      });
      setResult(value);
    } catch (e) {
      if (e instanceof DTPickerError) {
        setError(`${e.code}: ${e.message}`);
      } else {
        setError(String(e));
      }
    }
  };

  return (
    <View style={[styles.container, theme.container]}>
      <Button title="Pick date" onPress={() => pick(PickMode.Date)} />
      <Button title="Pick time" onPress={() => pick(PickMode.Time)} />
      <Button
        title="Pick date & time"
        onPress={() => pick(PickMode.DateTime)}
      />
      <Button title="Pick with bounds (+1h to +2h)" onPress={pickWithBounds} />
      <Button title="Pick time in Asia/Tokyo" onPress={pickInTokyo} />
      <Button
        title="Pick date (inline, iOS)"
        onPress={() => pickInline(PickMode.Date)}
      />
      <Button
        title="Pick time (inline, iOS)"
        onPress={() => pickInline(PickMode.Time)}
      />
      <Button
        title="Pick date & time (inline, iOS)"
        onPress={() => pickInline(PickMode.DateTime)}
      />
      <Button title="Dismiss" onPress={() => DTPicker.dismiss()} />
      <Text style={theme.text}>Result: {result ?? '(none)'}</Text>
      <TextInput
        style={[styles.input, theme.input]}
        placeholder="Type here"
        placeholderTextColor={isDark ? '#888' : '#aaa'}
      />
      {error != null && <Text style={styles.error}>{error}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  error: {
    color: 'red',
  },
  input: {
    borderWidth: 1,
    width: 200,
  },
});

const lightStyles = StyleSheet.create({
  container: { backgroundColor: '#fff' },
  text: { color: '#000' },
  input: { color: '#000', borderColor: '#000' },
});

const darkStyles = StyleSheet.create({
  container: { backgroundColor: '#000' },
  text: { color: '#fff' },
  input: { color: '#fff', borderColor: '#fff' },
});
