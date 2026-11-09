import { describe, expect, it } from 'vitest';
import { controllerUrl, decodeClient, decodeServer, encodeInput, makeRoomCode, peerIdFor } from './protocol';

describe('room helpers', () => {
  it('makes a 4 letter code from the alphabet', () => {
    expect(makeRoomCode(() => 0)).toBe('AAAA');
  });
  it('builds the peer id', () => {
    expect(peerIdFor('abcd')).toBe('couchgames-ABCD');
  });
  it('builds the controller url', () => {
    expect(controllerUrl('/couch-games/controller/', 'ABCD')).toBe('/couch-games/controller/?room=ABCD');
  });
});

describe('decodeClient', () => {
  it('trims and truncates hello names', () => {
    expect(decodeClient('{"t":"hello","name":"  Alexandra the Great "}')).toEqual({ t: 'hello', name: 'Alexandra th' });
  });
  it('defaults an empty name', () => {
    expect(decodeClient({ t: 'hello', name: '' })).toEqual({ t: 'hello', name: 'Player' });
  });
  it('puts every key but t into input fields', () => {
    expect(decodeClient({ t: 'input', gas: true })).toEqual({ t: 'input', fields: { gas: true } });
  });
  it('rejects garbage', () => {
    expect(decodeClient('nope')).toBeNull();
    expect(decodeClient({ t: 'x' })).toBeNull();
  });
});

describe('decodeServer', () => {
  it('round-trips a state message', () => {
    const msg = { t: 'state', layout: 'dpad', color: '#FF8A80' };
    expect(decodeServer(msg)).toEqual(msg);
    expect(decodeServer(JSON.stringify(msg))).toEqual(msg);
  });
  it('rejects unknown layouts and non-string colors', () => {
    expect(decodeServer({ t: 'state', layout: 'piano', color: '#fff' })).toBeNull();
    expect(decodeServer({ t: 'state', layout: 'dpad', color: 1 })).toBeNull();
  });
});

describe('encodeInput', () => {
  it('tags the input', () => {
    expect(encodeInput({ gas: true })).toEqual({ t: 'input', gas: true });
  });
});
