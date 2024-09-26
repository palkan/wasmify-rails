# Change log

## master

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
