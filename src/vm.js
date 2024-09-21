import { RubyVM } from "@ruby/wasm-wasi";
import {
  File,
  WASI,
  OpenFile,
  ConsoleStdout,
  PreopenDirectory,
} from "@bjorn3/browser_wasi_shim";

export const initRailsVM = async (url, opts = {}) => {
  const progressCallback = opts.progressCallback;
  const outputCallback = opts.outputCallback;
  const debugOn = opts.debug || false;

  progressCallback?.(`Loading WebAssembly module from ${url}...`);

  const module = await WebAssembly.compileStreaming(fetch(url));
  const databaseAdapter = opts.database?.adapter || "sqlite3_wasm";

  const storageDirPath = opts.storageDir || "/rails/storage";

  const setStdout = function (val) {
    console.log(val);
    outputCallback?.(val);
  };

  const setStderr = function (val) {
    console.warn(val);
    outputCallback?.(val);
  };

  const emptyMap = new Map();
  const storageDir = new PreopenDirectory(storageDirPath, emptyMap);
  const workDir = new PreopenDirectory("/", emptyMap);

  const fds = [
    new OpenFile(new File([])),
    ConsoleStdout.lineBuffered(setStdout),
    ConsoleStdout.lineBuffered(setStderr),
    workDir,
    storageDir,
  ];

  const wasi = new WASI([], [], fds, { debug: false });
  const vm = new RubyVM();
  const imports = {
    wasi_snapshot_preview1: wasi.wasiImport,
  };
  vm.addToImports(imports);

  progressCallback?.(`Instantiating WebAssembly module..`);

  const instance = await WebAssembly.instantiate(module, imports);
  await vm.setInstance(instance);

  wasi.initialize(instance);
  vm.initialize(["app.wasm", "-W0", "-e_=0", "-EUTF-8", `-r/bundle/setup`]);

  vm.eval(`
    require "js"

    ENV["RAILS_ENV"] = "wasm"
    ENV["ACTIVE_RECORD_ADAPTER"] = "${databaseAdapter}"

    ENV["DEBUG"] = "1" if ${debugOn}

    if ${debugOn}
      puts "Initializing Rails application in debug mode..."
    else
      puts "Initializing Rails application..."
    end

    require "/rails/config/application.rb"

    Rails.application.initialize!

    puts "Rails application #{Rails.application.class.name.sub("::Application", "")} (#{Rails::VERSION::STRING}) has been initialized"
  `);

  return vm;
};
