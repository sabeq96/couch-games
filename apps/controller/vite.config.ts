import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'
import { BASE } from '../../site.config.ts'

export default defineConfig({
  base: BASE + 'controller/',
  plugins: [vue(), tailwindcss()],
  envDir: '../..',
  server: { fs: { allow: ['../..'] } },
})
