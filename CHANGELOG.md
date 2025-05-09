# Change log

## master

## 0.3.2

- Add `Rack::WASI::IncomingHandler` mimicking `wasi/http:proxy` interface.

## 0.3.1

- Use latest patch versions for Ruby 3.3 and 3.4.

## 0.3.0

- Add `ignore_gem_extensions` configuration option.

- Make it possible to use builder and packer without Rails.

## 0.2.3

- Add `skipInitialize` option to `initVM`.

- Only skip extensions building for excluded gems.

## 0.2.2

- Fix handling multipart uploads in Data URI middleware.

- PWA template improvements.

## 0.2.1

- Minor generators updates.

## 0.2.0

- Add pglite support.

## 0.1.5

- Added async mode to rack.js.

- Added ability to pass env vars to Ruby VM.

- Rails 8 support for `sqlite3_wasm` adapter.

## 0.1.4

- Improve `wasmify:install`.

  Make it work with the `rails new` app without any manual steps.

## 0.1.3

- Check if `cookieStore` is available and only manipulate cookies if it is.

- Add `skipWaiting()` to the server worker to force the new version to take over.

## 0.1.2

- Add cache support to Rack handler.

  Now we use `caches` for files with `Cache-Control`, so we don't perform a Wasm request.

- Minor fixes and improvements.

## 0.1.1

- Support multipart file uploads by converting files to data URIs.

  At the Rack side, we use a `Rack::DataUriUploads` middleware to automatically convert
  data-URI-encoded files to files uploads, so the application can handle them as usual.

## 0.1.0

- Initial release
