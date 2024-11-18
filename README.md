[![Gem Version](https://badge.fury.io/rb/wasmify-rails.svg)](https://rubygems.org/gems/wasmify-rails)

# Wasmify Rails

This gem provides tools and extensions to compile Rails applications to WebAssembly.

> [!NOTE]
> Read more in our handbook: [Rails on Wasm](https://writebook-on-wasm.fly.dev/5/ruby-on-rails-on-webassembly)

## Installation

Adding to your Gemfile:

```ruby
# Gemfile
gem "wasmify-rails", group: [:development, :wasm]
```

## Usage: generators and tasks

This gem comes with a few commands (Rake tasks) to help you get started with packing your Rails app into a Wasm module.

### Step 1: `bin/rails wasmify:install`

Run the following command to preconfigure your project for _wasmification_:

```sh
bin/rails wasmify:install
```

The script will tweak you configuration files and create a couple of new ones:

- `config/environments/wasm.rb` — a dedicated Rails environment based on the `production` environment to be used in Wasm builds.

- `config/wasmify.yml` — this is a configuration file for different _wasmify_ commands (see below).

It also adds the `wasm` group to your Gemfile (see below on that).

### Step 2: `bin/rails wasmify:build:core`

Now, it's time to build a ruby.wasm with all your project dependencies (from the Gemfile). This is gonna be a base Wasm module
for your project but not including the project files.

Prior to running the build command, you MUST update your Gemfile to mark the gems that you need in the Wasm environment
with the `:wasm` group. For example:

```ruby
# Rails is required.
# NOTE: don't forget about the default group — you need it for the regular Rails environments.
gem "rails", group: [:default, :wasm]

# We don't need Puma though
gem "puma"

# You can also use group ... do ... end syntax
group :default, :wasm do
  gem "propshaft"
  gem "importmap-rails"
  gem "turbo-rails"
  gem "stimulus-rails"
end
...
```

We try to mark gems as wasm-compatible during the `wasmify:install` phase, but it's likely that you will need to adjust the Gemfile manually.

If you use `ruby file: ".ruby-version"` in your Gemfile, you should probably configure the Ruby version for Wasm platform
a bit differently (since patch versions might not match). For example:

```ruby
if RUBY_PLATFORM =~ /wasm/
  ruby "3.3.3"
else
  ruby file: ".ruby-version"
end
```

Or just disable the Ruby version check for the Wasm platform:

```ruby
ruby file: ".ruby-version" unless RUBY_PLATFORM =~ /wasm/
```

Now, try to run the following command:

```sh
$ bin/rails wasmify:build:core

...
INFO: Packaging gem: rails-7.2.1
...
INFO: Size: 77.92 MB
```

If it succeeds then you're good to go further. However, 99% that it will fail with some compilation error.
You must identify the gem that caused the problem (usually, it happens when we failed to compile a C extension to Wasm—not every C extension is Wasm-compilable).
Then, you can either update your Gemfile to exclude the problematic gem from the Wasm group or you can update your `config/wasmify.yml` and
add the gem to the `exclude_gems` list.

Repeat until the `bin/rails wasmify:build:core` succeeds.

You can also verify that the resulting Wasm module works by running:

```sh
$ bin/rails wasmify:build:core:verify

Your Rails version is: 7.2.1 [wasm32-wasi]
```

If this command fails, try to iterate on gem exclusions and rebuild the core module.

### Step 3: `bin/rails wasmify:pack:core`

Now, we're ready to pack the whole application into a single Wasm module.
For that, run the following command:

```sh
$ bin/rails wasmify:pack:core

Packed the application to tmp/wasmify/app-core.wasm
Size: 103 MB
```

That should succeeds given that the previous step was successful.

Now, let's try to boot the application and see if it works:

```sh
$ bin/rails wasmify:pack:core:verify

Initializing Rails application...
Rails application initialized!
```

If the verification passes, you can proceed to the final step — building the Wasm module to be used on the web.
If it fails, check out the error message and try to fix the issues (usually, configuration related).

### Step 4: `bin/rails wasmify:pwa`

We're ready to launch our Rails application fully within a browser!

For that, you can use our starter Vite PWA application that can be generated via the following command:

```sh
bin/rails wasmify:pwa
```

Then, update your `config/wasmify.yml` to specify the path to the PWA app as the output:

```yml
output_dir: "pwa"
# ...
```

Now, create the final Wasm module:

```sh
bin/rails wasmify:pack
```

And go to the `pwa` for the instructions on how to launch the application.

Here is an example app:

<video src="https://github.com/user-attachments/assets/34e54379-5f3e-42eb-a4fa-96c9aaa91869"></video>

## Rails/Ruby extensions

This gem provides a variety of _adapters_ and plugins to make your Rails application Wasm-compatible:

- `Kernel#on_wasm?`: a convenient predicate method to check if the code is running in the Wasm environment.

- Active Record

  - `sqlite3_wasm` adapter: works with `sqlite3` Wasm just like with a regular SQLite database.
  - `pglite` adapter: uses [pglite](https://pglite.dev) as a database.
  - `nulldb` adapter for testing purposes.

- Active Storage

  - `null` variant processor (just leaves files as is)

- Action Mailer

  - `null` delivery method (to disable emails in Wasm)

- Rack

  - `Rack::DataUriUploads` middleware to transparently transform Data URI uploads into files.

## Roadmap

- PGLite support (see [this example](https://github.com/kateinoigakukun/mastodon/blob/fff2e4a626a20a616c546ddf4f91766abaf1133a/pwa/dist/pglite.rb#L1))
- Active Storage OPFS service
- Background jobs support
- WASI Preview 2 support (also [this](https://github.com/kateinoigakukun/mastodon/tree/katei/wasmify))

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/](https://github.com/).

## Credits

The `nulldb` adapter for Active Record (used for tests) is ported from [this project](https://github.com/nulldb/nulldb).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
