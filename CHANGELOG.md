# Change log

## master

## 0.1.1

- Support multipart file uploads by converting files to data URIs.

  At the Rack side, we use a `Rack::DataUriUploads` middleware to automatically convert
  data-URI-encoded files to files uploads, so the application can handle them as usual.

## 0.1.0

- Initial release
