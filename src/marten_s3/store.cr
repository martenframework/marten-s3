require "awscr-s3"

module MartenS3
  class Store < Marten::Core::Storage::Base
    def initialize(
      @client : Awscr::S3::Client,
      @bucket : String,
      @force_path_style : Bool = false,
      @expires_in = 86_400,
      @public_urls : Bool = false,
    )
      @presigner = Awscr::S3::Presigner.new(@client)
      @file_uploader = Awscr::S3::FileUploader.new(@client)
    end

    def initialize(
      region : String,
      access_key : String,
      secret_key : String,
      @bucket : String,
      endpoint : String? = nil,
      @force_path_style : Bool = false,
      @expires_in = 86_400,
      @public_urls : Bool = false,
    )
      @client = Awscr::S3::Client.new(
        region,
        access_key,
        secret_key,
        endpoint: endpoint
      )
      @presigner = Awscr::S3::Presigner.new(@client)
      @file_uploader = Awscr::S3::FileUploader.new(@client)
    end

    def save(filepath : String, content : IO) : String
      normalized_path = Path.new(filepath).normalize
      super(normalized_path.to_s, content)
    end

    def write(filepath : String, content : IO) : Nil
      @file_uploader.upload(
        @bucket,
        filepath,
        content
      )
    end

    def delete(filepath : String) : Nil
      @client.head_object(@bucket, filepath)
      @client.delete_object(@bucket, filepath)
    rescue
      raise Marten::Core::Storage::Errors::FileNotFound.new(
        "File '#{filepath}' not found in #{@bucket}"
      )
    end

    def open(filepath : String) : IO
      io_mem = IO::Memory.new
      @client.get_object(@bucket, filepath) do |resp|
        IO.copy(resp.body_io, io_mem)
      end
      io_mem.rewind
      io_mem
    rescue Awscr::S3::NoSuchKey
      raise Marten::Core::Storage::Errors::FileNotFound.new("File '#{filepath}' not found in S3")
    end

    def exists?(filepath : String) : Bool
      @client.head_object(@bucket, filepath)
      true
    rescue
      false
    end

    def size(filepath : String) : Int64
      response = @client.head_object(@bucket, filepath)
      content_length = response.headers["Content-Length"]?
      if content_length
        content_length.to_i64
      else
        0_i64
      end
    rescue
      0_i64
    end

    def url(filepath : String) : String
      filepath = URI.encode_path(filepath)

      if @public_urls
        public_url(filepath)
      else
        generate_presigned_url(filepath)
      end
    end

    private def public_url(filepath)
      uri = @client.endpoint.dup
      if @force_path_style
        uri.path = "/#{@bucket}/#{filepath}"
      else
        uri.host = "#{@bucket}.#{@client.endpoint.host}"
        uri.path = "/#{filepath}"
      end

      uri.to_s
    end

    private def generate_presigned_url(filepath : String)
      @presigner.presigned_url(@bucket, filepath, expires: @expires_in, force_path_style: @force_path_style)
    end
  end
end
