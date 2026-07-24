import { defineConfig } from 'vite'

// base: './' = rutas relativas. El mismo build funciona en producción
// (/Take-OS/) y en staging (/takeos-staging/) sin cambios. Mata el 404.
export default defineConfig({
  base: './',
  build: {
    outDir: 'dist',
  },
})
