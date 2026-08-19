# Marten S3

[![GitHub Release](https://img.shields.io/github/v/release/martenframework/marten-s3?style=flat)](https://github.com/martenframework/marten-s3/releases)
[![Specs](https://github.com/martenframework/marten-s3/actions/workflows/specs.yml/badge.svg)](https://github.com/martenframework/marten-s3/actions/workflows/specs.yml)
[![QA](https://github.com/martenframework/marten-s3/actions/workflows/qa.yml/badge.svg)](https://github.com/martenframework/marten-s3/actions/workflows/qa.yml)

**Marten S3** provides an [Amazon S3](https://aws.amazon.com/s3/) [file storage](https://martenframework.com/docs/files/managing-files#file-storages) backend for the [Marten](https://martenframework.com) web framework. It works with AWS S3 and S3-compatible services such as MinIO, Wasabi, or Cloudflare R2.

## Installation

Simply add the following entry to your project's `shard.yml`:

```yaml
dependencies:
  marten_s3:
    github: martenframework/marten-s3
```

And run `shards install` afterward.

## Configuration

First, add the following requirement to your project's `src/project.cr` file:

```crystal
require "marten_s3"
```

Then add the application to your project's installed apps (usually in `config/settings/base.cr`) and assign the storage to [`media_files.storage`](https://martenframework.com/docs/development/reference/settings#media-files-settings) (typically in `config/settings/production.cr`):

```crystal
Marten.configure do |config|
  config.installed_apps = [
    MartenS3::App,
    # …
  ]

  config.media_files.storage = MartenS3::Store.new(
    region: ENV.fetch("S3_REGION"),
    bucket: ENV.fetch("S3_BUCKET"),
    access_key: ENV.fetch("S3_ACCESS_KEY"),
    secret_key: ENV.fetch("S3_SECRET_KEY"),
  )
end
```

The same store can also be used for [collected assets](https://martenframework.com/docs/assets) by assigning it to [`assets.storage`](https://martenframework.com/docs/development/reference/settings#assets-settings).

You should ensure that access keys are kept secret and that they are not hardcoded in your config files.

### Constructor arguments

| Argument | Required | Default | Description |
| --- | --- | --- | --- |
| `region` | yes | — | AWS region (or a placeholder region for compatible services). |
| `bucket` | yes | — | Name of the bucket used to persist files. |
| `access_key` | yes | — | Access key ID. |
| `secret_key` | yes | — | Secret access key. |
| `endpoint` | no | `nil` | Custom endpoint URL. Required for non-AWS S3-compatible services. |
| `force_path_style` | no | `false` | Use path-style URLs (`endpoint/bucket/key`) instead of virtual-hosted-style URLs (`bucket.endpoint/key`). Required for most compatible providers. |
| `expires_in` | no | `86400` | Lifetime of generated [presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html), in seconds. |
| `public_urls` | no | `false` | Generate public object URLs instead of presigned URLs. Use this when objects are publicly readable. |

### S3-compatible services

For MinIO, Wasabi, and similar providers, set a custom `endpoint` and enable `force_path_style`:

```crystal
Marten.configure do |config|
  config.media_files.storage = MartenS3::Store.new(
    region: ENV.fetch("S3_REGION", "us-east-1"),
    bucket: ENV.fetch("S3_BUCKET"),
    access_key: ENV.fetch("S3_ACCESS_KEY"),
    secret_key: ENV.fetch("S3_SECRET_KEY"),
    endpoint: ENV.fetch("S3_ENDPOINT"),
    force_path_style: true,
  )
end
```

### Public URLs

By default, `#url` returns a time-limited presigned URL. If objects in the bucket are publicly readable, set `public_urls: true` to generate unsigned URLs instead:

```crystal
MartenS3::Store.new(
  region: ENV.fetch("S3_REGION"),
  bucket: ENV.fetch("S3_BUCKET"),
  access_key: ENV.fetch("S3_ACCESS_KEY"),
  secret_key: ENV.fetch("S3_SECRET_KEY"),
  public_urls: true,
)
```

### Custom S3 client

If you already have an [`Awscr::S3::Client`](https://github.com/taylorfinnell/awscr-s3) instance, you can pass it directly to the store:

```crystal
client = Awscr::S3::Client.new(
  ENV.fetch("S3_REGION"),
  ENV.fetch("S3_ACCESS_KEY"),
  ENV.fetch("S3_SECRET_KEY"),
)

config.media_files.storage = MartenS3::Store.new(client, ENV.fetch("S3_BUCKET"))
```

## Authors

Marvin Ahlgrimm ([@treagod](https://github.com/treagod)) and
[contributors](https://github.com/martenframework/marten-s3/contributors).

## License

MIT. See ``LICENSE`` for more details.
