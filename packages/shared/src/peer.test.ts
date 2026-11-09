import { describe, expect, it } from 'vitest';
import { peerOptions } from './peer';

describe('peerOptions', () => {
  it('is empty without a host', () => {
    expect(peerOptions({})).toEqual({});
  });
  it('builds local server options', () => {
    expect(peerOptions({ VITE_PEER_HOST: 'localhost', VITE_PEER_PORT: '9000' })).toEqual({
      host: 'localhost',
      port: 9000,
      path: '/',
      secure: false,
    });
  });
  it('uses a given path', () => {
    expect(peerOptions({ VITE_PEER_HOST: 'h', VITE_PEER_PORT: '1', VITE_PEER_PATH: '/p' }).path).toBe('/p');
  });
});
