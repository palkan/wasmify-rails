import { defineConfig } from "vite";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  server: {
    headers: {
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp",
    },
  },
  optimizeDeps: {
    exclude: ["@sqlite.org/sqlite-wasm"],
  },
  build: {
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        boot: resolve(__dirname, 'boot.html'),
      },
    },
  },
  plugins: [
    VitePWA({
      srcDir: ".",
      filename: "rails.sw.js",
      strategies: "injectManifest",
      injectRegister: false,
      manifest: false,
      injectManifest: {
        injectionPoint: null,
      },
      devOptions: {
        enabled: true,
      },
    }),
  ],
});
