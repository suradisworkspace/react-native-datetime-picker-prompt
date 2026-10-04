import { describe, expect, it } from '@jest/globals';
import { DTPickerError, parseNativeError } from '../PickMode';

describe('parseNativeError', () => {
  it('extracts a known error code from the "CODE: message" convention', () => {
    const error = parseNativeError(
      new Error('E_ALREADY_VISIBLE: A picker is already being shown.')
    );

    expect(error).toBeInstanceOf(DTPickerError);
    expect(error.code).toBe('E_ALREADY_VISIBLE');
    expect(error.message).toBe('A picker is already being shown.');
  });

  it('falls back to E_UNKNOWN when the message has no recognized code prefix', () => {
    const error = parseNativeError(new Error('Something unexpected broke.'));

    expect(error.code).toBe('E_UNKNOWN');
    expect(error.message).toBe('Something unexpected broke.');
  });

  it('falls back to E_UNKNOWN for a code-shaped prefix that is not in the known list', () => {
    const error = parseNativeError(new Error('E_MADE_UP: nope.'));

    expect(error.code).toBe('E_UNKNOWN');
    expect(error.message).toBe('E_MADE_UP: nope.');
  });

  it('handles non-Error values', () => {
    const error = parseNativeError('E_NO_ACTIVITY: no current Activity.');

    expect(error.code).toBe('E_NO_ACTIVITY');
    expect(error.message).toBe('no current Activity.');
  });

  it('extracts E_INVALID_RANGE', () => {
    const error = parseNativeError(
      new Error('E_INVALID_RANGE: minimumDate is after maximumDate.')
    );

    expect(error.code).toBe('E_INVALID_RANGE');
    expect(error.message).toBe('minimumDate is after maximumDate.');
  });

  it('extracts E_INVALID_TIMEZONE', () => {
    const error = parseNativeError(
      new Error(
        'E_INVALID_TIMEZONE: "Asia/Bankok" is not a recognized IANA timezone identifier.'
      )
    );

    expect(error.code).toBe('E_INVALID_TIMEZONE');
    expect(error.message).toBe(
      '"Asia/Bankok" is not a recognized IANA timezone identifier.'
    );
  });
});
