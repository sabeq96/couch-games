import { createApp } from 'vue'
import { Peer } from 'peerjs'
import App from './App.vue'
import { createRouter, createWebHashHistory } from 'vue-router'
import { routes } from './routes'
import './style.css'

// Test hook for the e2e smoke test; never part of production bundles.
if (import.meta.env.VITE_E2E) (window as unknown as { __Peer: typeof Peer }).__Peer = Peer

createApp(App)
  .use(createRouter({ history: createWebHashHistory(), routes }))
  .mount('#app')
