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
      it "returns a URL constructed from the base URL" do
        storage.url("css/app.css").should contain "awscr-s3-test-"
        storage.url("css/app.css").should contain "css/app.css"
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
