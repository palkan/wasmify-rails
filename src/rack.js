import setCookieParser from "set-cookie-parser";

// An outgoing request queue to prevent concurrent requests from hitting rails.wasm.
//
// Based on https://github.com/kateinoigakukun/mastodon/blob/fff2e4a626a20a616c546ddf4f91766abaf1133a/pwa/src/rails.sw.js#L282
export class RequestQueue {
  constructor(respond) {
    this._respond = respond;
    this.isProcessing = false;
    this.queue = [];
  }

  async respond(request) {
    if (this.isProcessing) {
      return new Promise((resolve) => {
        this.queue.push({ request, resolve });
      });
    }
    const response = await this.process(request);
    queueMicrotask(() => this.tick());
    return response;
  }

  async process(request) {
    this.isProcessing = true;
    let response;
    try {
      response = await this._respond(request);
    } catch (e) {
      console.error(e);
      response = new Response(`Application Error: ${e.message}`, {
        status: 500,
      });
    } finally {
      this.isProcessing = false;
    }
    return response;
  }

  async tick() {
    if (this.queue.length === 0) {
      return;
    }
    const { request, resolve } = this.queue.shift();
    const response = await this.process(request);
    resolve(response);
    queueMicrotask(() => this.tick());
  }
}

// We convert files from forms into data URIs and handle them via Rack DataUriUploads middleware.
const DATA_URI_UPLOAD_PREFIX = "BbC14y";

const fileToDataURI = async (file) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = () => {
      resolve(reader.result);
    };

    reader.onerror = (error) => {
      reject(error);
    };

    reader.readAsDataURL(file);
  });
};

const cachedProcess = async (request, fallback) => {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    // Add cached headers to the response, so we can track cache hits
    const headers = new Headers(cachedResponse.headers);
    headers.append("X-Cache", "HIT");
    console.log("[rails-web] Cache hit", request.url);
    return new Response(cachedResponse.body, {
      status: cachedResponse.status,
      statusText: cachedResponse.statusText,
      headers,
    });
  }

  const networkResponse = await fallback(request);
  const cacheControl = networkResponse.headers.get("Cache-Control");

  // Only cache if Cache-Control header doesn't indicate 'no-store' or 'no-cache'
  if (
    cacheControl &&
    !cacheControl.includes("no-store") &&
    !cacheControl.includes("no-cache")
  ) {
    // Cache everything with cache set to some days/months/more
    const maxAgeMatch = cacheControl.match(/max-age=(\d{5,})/);
    if (maxAgeMatch) {
      const cache = await caches.open("rails-wasm");
      cache.put(request, networkResponse.clone());
    }
  }

  return networkResponse;
};

export class RackHandler {
  constructor(vmSetup, opts = {}) {
    this.logger = opts.logger || console;
    this.cache = opts.cache || true;
    this.quiteAssets = opts.quiteAssets || true;
    this.assumeSSL = opts.assumeSSL || false;
    this.async = opts.async || false;
    this.vmSetup = vmSetup;
    // Check if cookieStore is supported
    this.cookiesEnabled = !!globalThis.cookieStore;
    this.queue = new RequestQueue(this.process.bind(this));
  }

  handle(request) {
    if (!request.url.includes("/assets/")) {
      this.logger.log("[rails-web] Enqueue request: ", request);
    }

    if (this.cache) {
      return cachedProcess(request, (req) => {
        return this.queue.respond(req);
      });
    }

    return this.queue.respond(request);
  }

  async process(request) {
    let vm = await this.vmSetup();

    const railsURL = this.assumeSSL
      ? request.url
      : request.url.replace("https://", "http://");
    const railsHeaders = {};

    for (const [key, value] of request.headers.entries()) {
      railsHeaders[`HTTP_${key.toUpperCase().replaceAll("-", "_")}`] = value;
    }

    try {
      if (this.cookiesEnabled) {
        const cookies = await cookieStore.getAll();
        const railsCookie = cookies
          .map((c) => `${c.name}=${c.value}`)
          .join("; ");

        railsHeaders["HTTP_COOKIE"] = railsCookie;
      }

      let input = null;

      if (
        request.method === "POST" ||
        request.method === "PUT" ||
        request.method === "PATCH"
      ) {
        const contentType = request.headers.get("content-type");

        // multipart inputs do not work correctly or some reason
        // (_method is getting lost)
        if (contentType.includes("multipart/form-data")) {
          const formData = await request.formData();
          // Remove file/blob values from FormData
          for (const [key, value] of formData.entries()) {
            if (value instanceof File) {
              try {
                const dataURI = await fileToDataURI(value);
                formData.set(key, DATA_URI_UPLOAD_PREFIX + dataURI);
              } catch (e) {
                console.warn(
                  `[rails-wasm] Failed to convert file into data URI: ${e.message}. Ignoring file form input ${key}`,
                );
                formData.delete(key);
              }
            }
          }

          input = new URLSearchParams(formData).toString();
        } else {
          input = await request.text();
        }
      }

      if (!railsURL.includes("/assets/")) {
        this.logger.log("[rails-web] Rails request", {
          url: railsURL,
          headers: railsHeaders,
          input: !!input,
        });
      }

      const command = `
        has_input = ${!!input}
        request = Rack::MockRequest.env_for(
          "${railsURL}",
          JSON.parse(%q[${JSON.stringify(railsHeaders)}]).merge(
            method: :${request.method}
          ).tap do
            _1.merge!(input: %q[${input}]) if has_input
          end
        )

        response = Rack::Response[*Rails.application.call(request)]
        status, headers, bodyiter = *response.finish

        body = ""
        body_is_set = false

        bodyiter.each do |part|
          body += part
          body_is_set = true
        end

        # Serve images as base64 from Ruby and decode back in JS
        if headers["Content-Type"]&.start_with?("image/")
          body = Base64.strict_encode64(body)
        end

        {
          status: status,
          headers: headers,
          body: body_is_set ? body : nil
        }
      `;

      let res;

      if (this.async) {
        const proc = vm.eval(`proc do\n${command}\nend`);
        res = await proc.callAsync("call");
        // const retVal = await vm.evalAsync(command);
        // res = retVal.toJS();
      } else {
        res = vm.eval(command).toJS();
      }

      if (!railsURL.includes("/assets/")) {
        this.logger.log("[rails-web] Rails response", res);
      }

      let { status, headers, body } = res;

      if (this.cookiesEnabled) {
        const cookie = headers["set-cookie"];

        if (cookie) {
          const cookies = setCookieParser.parse(cookie, {
            decodeValues: false,
          });
          cookies.forEach(async (c) => {
            await cookieStore.set({
              name: c.name,
              value: c.value,
              domain: c.domain,
              path: c.path,
              expires: c.expires,
              sameSite: c.sameSite.toLowerCase(),
            });
          });
        }
      }

      // Convert image into a blob
      if (headers["content-type"]?.startsWith("image/")) {
        this.logger.log(
          "[rails-web]",
          `Converting ${headers["content-type"]} image into blob`,
        );

        body = await fetch(
          `data:${headers["content-type"]};base64,${body}`,
        ).then((res) => res.blob());
      }

      const resp = new Response(body, {
        headers,
        status,
      });

      if (!railsURL.includes("/assets/")) {
        this.logger.log("[rails-web] Response:", resp);
      }

      return resp;
    } catch (e) {
      this.logger.error(e);
      return new Response(`Application Error: ${e.message}`, {
        status: 500,
      });
    }
  }
}
