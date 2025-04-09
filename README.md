# Marten S3

[![GitHub Release](https://img.shields.io/github/v/release/treagod/marten-s3?style=flat)](https://github.com/treagod/marten-s3/releases)
[![Marten Turbo Specs](https://github.com/treagod/marten-s3/actions/workflows/specs.yml/badge.svg)](https://github.com/treagod/marten-s3/actions/workflows/specs.yml)
[![QA](https://github.com/treagod/marten-s3/actions/workflows/qa.yml/badge.svg)](https://github.com/treagod/marten-s3/actions/workflows/qa.yml)

Marten S3 provides a file store implementation to interact with S3 storages

## Installation

Simply add the following entry to your project's `shard.yml`:

```yaml
dependencies:
  marten_s3:
    github: treagod/marten-s3
```

And run `shards install` afterward.

First, add the following requirement to your project's `src/project.cr` file:

```crystal
require "marten_s3"
```

Afterwards add it to your project applications

```crystal
config.installed_apps = [
  # …
  MartenS3::App
]
```

Finally you can configure the storage

```crystal
config.media_files.storage = MartenS3::Store.new(
  region: "your-region",
  bucket: "bucket-name",
  access_key: "s3_access_key",
  secret_key: "s3_secret_key",
  endpoint: "custom_endpoint", # optional – required only for non-AWS S3-compatible services
  force_path_style: true, # required for most S3-compatible providers (e.g. MinIO, Wasabi); not needed for AWS
)
```
