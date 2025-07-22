require "./spec_helper"

describe MartenS3::Store do
  client = Awscr::S3::Client.new(
    region: "unused",
    aws_access_key: ENV.fetch("S3_KEY", "admin"),
    aws_secret_key: ENV.fetch("S3_SECRET", "password"),
    endpoint: ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000")
  )

  bucket_name = "awscr-s3-test-#{UUID.random}"
  storage = MartenS3::Store.new(
    region: "unused",
    bucket: bucket_name,
    access_key: ENV.fetch("S3_KEY", "admin"),
    secret_key: ENV.fetch("S3_SECRET", "password"),
    endpoint: ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000"),
    force_path_style: true,
  )
  client.put_bucket(bucket_name)

  after_all do
    list_buckets = client.list_buckets.buckets.map(&.name)
    list_buckets.each do |bucket|
      next if !bucket.starts_with?("awscr-s3-test-")
      client.list_objects(bucket).each do |resp|
        resp.contents.each do |object|
          client.delete_object(bucket, object.key)
        end
      end
      client.delete_bucket(bucket)
    end
  end

  before_each do
    bucket_name = "awscr-s3-test-#{UUID.random}"
    storage = MartenS3::Store.new(
      region: "unused",
      bucket: bucket_name,
      access_key: ENV.fetch("S3_KEY", "admin"),
      secret_key: ENV.fetch("S3_SECRET", "password"),
      endpoint: ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000"),
      force_path_style: true,
    )
    client.put_bucket(bucket_name)
  end

  describe "#delete" do
    it "deletes the file associated with the passed file path" do
      storage.write("css/app.css", IO::Memory.new("html { background: white; }"))

      storage.delete("css/app.css")

      storage.exists?("css/app.css").should be_false
    end

    it "raises if the file does not exist" do
      expect_raises Marten::Core::Storage::Errors::FileNotFound do
        storage.delete("css/app.css")
      end
    end
  end

  describe "#exists" do
    it "returns true if a file associated with the passed file path exists" do
      storage.write("css/app.css", IO::Memory.new("html { background: white; }"))
      storage.exists?("css/app.css").should be_true
    end

    it "returns false if a file associated with the passed file path does not exists" do
      storage.exists?("css/app.css").should be_false
    end
  end

  describe ".new(client)" do
    it "supports the full end-to-end read/write cycle with a supplied client" do
      custom_client = Awscr::S3::Client.new(
        region: "unused",
        aws_access_key: ENV.fetch("S3_KEY", "admin"),
        aws_secret_key: ENV.fetch("S3_SECRET", "password"),
        endpoint: ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000"),
      )

      custom_client.put_bucket(bucket_name) rescue nil

      storage_with_client = MartenS3::Store.new(
        custom_client,
        bucket_name,
        force_path_style: true,
        expires_in: 60,
      )

      storage_with_client.write("images/logo.png", IO::Memory.new("logo-content"))
      storage_with_client.exists?("images/logo.png").should be_true

      storage_with_client.open("images/logo.png").gets.should eq "logo-content"

      expected_size = "logo-content".bytesize.to_i64
      storage_with_client.size("images/logo.png").should eq expected_size

      uri = URI.parse(storage_with_client.url("images/logo.png"))
      URI::Params.parse(uri.query.not_nil!)["X-Amz-Expires"].should eq "60"
    end

    it "generates public virtual-host style URLs when requested" do
      custom_client = Awscr::S3::Client.new(
        region: "unused",
        aws_access_key: ENV.fetch("S3_KEY", "admin"),
        aws_secret_key: ENV.fetch("S3_SECRET", "password"),
      )
      custom_client.put_bucket(bucket_name) rescue nil

      storage_public = MartenS3::Store.new(
        custom_client,
        bucket_name,
        public_urls: true,
      )

      url = storage_public.url("assets/app.js")
      uri = URI.parse(url)

      # Expected host: "#{bucket}.minio-host"
      test_host = URI.parse("https://s3-unused.amazonaws.com").host
      uri.host.should eq "#{bucket_name}.#{test_host}"

      uri.path.should eq "/assets/app.js"
      uri.query.should be_nil
    end
  end

  describe "#open" do
    it "returns an IO corresponding to the passed file path" do
      storage.write("css/app.css", IO::Memory.new("html { background: white; }"))
      io = storage.open("css/app.css")
      io.gets.should eq "html { background: white; }"
    end

    it "raises if the file does not exist" do
      storage = Marten::Core::Storage::FileSystem.new(root: File.join("/tmp/"), base_url: "/assets/")
      expect_raises(Marten::Core::Storage::Errors::FileNotFound) do
        storage.open("css/unknown.css")
      end
    end
  end

  describe "#save" do
    it "copy the content of the passed IO object to the destination path if it does not already exist" do
      destination_path = "css/app_#{Time.local.to_unix}.css"

      path = storage.save(destination_path, IO::Memory.new("html { background: white; }"))
      path.should eq destination_path

      io = IO::Memory.new
      client.get_object(bucket_name, path) do |resp|
        IO.copy(resp.body_io, io)
      end
      io.rewind
      io.gets.should eq "html { background: white; }"
    end

    it "copy the content of the passed IO object to a modified destination path if it already exists" do
      destination_path = "css/app.css"

      first_path = storage.save(destination_path, IO::Memory.new("html { background: white; }"))
      path = storage.save(destination_path, IO::Memory.new("html { background: white; }"))

      first_path.should eq destination_path
      path.should_not eq destination_path
      path.starts_with?("css/app").should be_true

      io = IO::Memory.new
      client.get_object(bucket_name, path) do |resp|
        IO.copy(resp.body_io, io)
      end
      io.rewind
      io.gets.should eq "html { background: white; }"
    end

    it "does not retain leading ./ characters in the generated path" do
      destination_path = "./app.css"

      storage.save(destination_path, IO::Memory.new("html { background: white; }"))
      path = storage.save(destination_path, IO::Memory.new("html { background: white; }"))

      path.should_not eq destination_path
      path.starts_with?("app").should be_true
      io = IO::Memory.new
      client.get_object(bucket_name, path) do |resp|
        IO.copy(resp.body_io, io)
      end
      io.rewind
      io.gets.should eq "html { background: white; }"
    end

    describe "#size" do
      it "returns the size of the file associated with the passed file path" do
        storage.write("css/app.css", IO::Memory.new("html { background: white; }"))
        io = IO::Memory.new
        client.get_object(bucket_name, "css/app.css") do |resp|
          IO.copy(resp.body_io, io)
        end
        io.rewind
        storage.size("css/app.css").should eq io.gets.not_nil!.size
      end
    end

    describe "#url" do
      it "returns a private URL constructed from the base URL" do
        uri = URI.parse(storage.url("css/app.css"))

        uri.host.should eq URI.parse(ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000")).host

        uri.path.should contain "#{bucket_name}/css/app.css"

        query = uri.query.not_nil!

        query_params = URI::Params.parse(query)
        query_params.has_key?("X-Amz-Algorithm").should be_true
        query_params.has_key?("X-Amz-Credential").should be_true
        query_params.has_key?("X-Amz-Date").should be_true
        query_params["X-Amz-Expires"].should eq "86400"
        query_params.has_key?("X-Amz-SignedHeaders").should be_true
        query_params.has_key?("X-Amz-Signature").should be_true
      end

      it "returns a path-style public URL when `public_urls` is true and `force_path_style` is enabled" do
        storage = MartenS3::Store.new(
          region: "unused",
          bucket: bucket_name,
          access_key: ENV.fetch("S3_KEY", "admin"),
          secret_key: ENV.fetch("S3_SECRET", "password"),
          endpoint: ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000"),
          force_path_style: true,
          public_urls: true,
        )
        uri = URI.parse(storage.url("css/app.css"))

        uri.host.should eq URI.parse(ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000")).host

        uri.path.should eq "/#{bucket_name}/css/app.css"

        uri.query.should be_nil
      end

      it "returns a virtual-host–style public URL when `public_urls` is true and `force_path_style` is disabled" do
        storage = MartenS3::Store.new(
          region: "unused",
          bucket: bucket_name,
          access_key: ENV.fetch("S3_KEY", "admin"),
          secret_key: ENV.fetch("S3_SECRET", "password"),
          endpoint: ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000"),
          public_urls: true,
        )
        uri = URI.parse(storage.url("css/app.css"))

        test_host = URI.parse(ENV.fetch("S3_ENDPOINT", "http://127.0.0.1:9000")).host

        uri.host.should eq "#{bucket_name}.#{test_host}"

        uri.path.should eq "/css/app.css"

        uri.query.should be_nil
      end
    end

    describe "#write" do
      it "copy the content of the passed IO object to the destination path" do
        storage.write("css/app.css", IO::Memory.new("html { background: white; }"))
        io = IO::Memory.new
        client.get_object(bucket_name, "css/app.css") do |resp|
          IO.copy(resp.body_io, io)
        end
        io.rewind
        io.gets.should eq "html { background: white; }"
      end
    end
  end
end
