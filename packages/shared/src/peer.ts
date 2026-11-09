export interface PeerEnv {
  VITE_PEER_HOST?: string;
  VITE_PEER_PORT?: string;
  VITE_PEER_PATH?: string;
}

export function peerOptions(env: PeerEnv): { host?: string; port?: number; path?: string; secure?: boolean } {
  if (!env.VITE_PEER_HOST) return {};
  return {
    host: env.VITE_PEER_HOST,
    port: Number(env.VITE_PEER_PORT),
    path: env.VITE_PEER_PATH ?? '/',
    secure: false,
  };
}
