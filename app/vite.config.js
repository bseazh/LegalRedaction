import { defineConfig } from 'vite';

// Tauri devUrl is fixed to 5173. Never silently move to another port,
// otherwise the window can connect to a stale frontend instance.
export default defineConfig({
  server: { port: 5173, strictPort: true }
});
