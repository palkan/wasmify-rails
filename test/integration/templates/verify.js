// Verifies that a packed Rails Wasm module works in a JavaScript runtime (Node.js):
// boots the application via the wasmify-rails JS package, sets up a PGlite
// database, runs Active Record queries against it, and performs a health-check
// Rack request.
//
// Usage: node scripts/verify.js [path/to/app.wasm]
//
// Prints "JS + PGlite verification passed" and exits 0 on success;
// exits 1 on any failure.

import { readFile } from "node:fs/promises";
import { PGlite } from "@electric-sql/pglite";
import { initRailsVM, registerPGliteWasmInterface } from "wasmify-rails";

const wasmPath = process.argv[2] || "dist/app.wasm";

const fail = (error) => {
  console.error("[verify] FAILED:", error);
  process.exit(1);
};

// The pglite Active Record adapter resolves its JS counterpart via the global
// `pglite` object: `pglite.create_interface(<database>)` must set up a database
// and return the name of the global query interface object. In the browser the
// PWA template provides it; here we back it with an in-memory PGlite instance.
globalThis.pglite = {
  async create_interface(database) {
    console.log(`[verify] Creating in-memory PGlite database (${database || "default"})...`);
    const db = new PGlite();
    await db.waitReady;
    registerPGliteWasmInterface(globalThis, db);
    return "pglite4rails";
  },
};

// NOTE: keep this snippet free of JS interpolation triggers (backticks, "${").
const VERIFY_SCRIPT = `
  conn = ActiveRecord::Base.connection

  conn.create_table(:integration_posts, force: true) do |t|
    t.string :title
    t.integer :visits, default: 0, null: false
  end

  class IntegrationPost < ActiveRecord::Base; end

  IntegrationPost.create!(title: "Hello from Wasm", visits: 2025)
  IntegrationPost.create!(title: "Another post")

  count = IntegrationPost.where("title LIKE ?", "%Wasm%").count
  raise "expected 1 matching record, got #{count}" unless count == 1

  post = IntegrationPost.find_by!(title: "Hello from Wasm")
  raise "unexpected visits value: #{post.visits.inspect}" unless post.visits == 2025

  total = IntegrationPost.count
  raise "expected 2 records, got #{total}" unless total == 2

  env = Rack::MockRequest.env_for("http://localhost:3000/up", "HTTP_HOST" => "localhost")
  status, _headers, _body = Rails.application.call(env)
  raise "health check request failed with status #{status}" unless status.to_i == 200

  "OK: #{total} records in PGlite; health check status: #{status}"
`;

try {
  console.log(`[verify] Loading Wasm module from ${wasmPath}...`);
  const module = await WebAssembly.compile(await readFile(wasmPath));

  const vm = await initRailsVM(module, {
    database: { adapter: "pglite" },
    async: true,
    progressCallback: (step) => console.log(`[verify] ${step}`),
  });

  const result = await vm.evalAsync(VERIFY_SCRIPT);
  const summary = result.toString();

  if (!summary.startsWith("OK")) {
    fail(`unexpected verification result: ${summary}`);
  }

  console.log(`[verify] ${summary}`);
  console.log("[verify] JS + PGlite verification passed");
  // The Wasm VM keeps the event loop alive; exit explicitly.
  process.exit(0);
} catch (error) {
  fail(error);
}
