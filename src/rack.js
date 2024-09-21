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

export class RackHandler {
  constructor(vmSetup, opts = {}) {
    this.logger = opts.logger || console;
    this.quiteAssets = opts.quiteAssets || true;
    this.assumeSSL = opts.assumeSSL || false;
    this.vmSetup = vmSetup;
    this.queue = new RequestQueue(this.process.bind(this));
  }

  handle(request) {
    if (!request.url.includes("/assets/")) {
      this.logger.log("[rails-web] Enqueue request: ", request);
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
      const cookies = await cookieStore.getAll();
      const railsCookie = cookies.map((c) => `${c.name}=${c.value}`).join("; ");

      railsHeaders["HTTP_COOKIE"] = railsCookie;

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
              console.warn(
                `[rails-wasm] Ignore file form input ${key}. Not supported yet.`,
              );
              formData.delete(key);
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

      const res = vm.eval(command).toJS();

      if (!railsURL.includes("/assets/")) {
        this.logger.log("[rails-web] Rails response", res);
      }

      let { status, headers, body } = res;

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
