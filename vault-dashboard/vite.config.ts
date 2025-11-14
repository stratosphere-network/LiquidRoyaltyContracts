import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: true, // Allow external access
    allowedHosts: [
      'ab25e9fc2fc7.ngrok-free.app',
      '.ngrok-free.app', // Allow any ngrok subdomain
      '.ngrok.io', // Support older ngrok domains
    ],
  },
})
