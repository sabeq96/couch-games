import { createApp } from 'vue'
import { Peer } from 'peerjs'
import App from './App.vue'
import './style.css'

// Test hook for the e2e smoke test; never part of production bundles.
if (import.meta.env.VITE_E2E) (window as unknown as { __Peer: typeof Peer }).__Peer = Peer

createApp(App).mount('#app')
