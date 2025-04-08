require "awscr-s3"

module MartenS3
  class Store < Marten::Core::Storage::Base
    def initialize(
      @region : String,
      @access_key : String,
      @secret_key : String,
      @bucket : String,
      @endpoint : String? = nil,
      @force_path_style : Bool = false,
      @expires_in = 86_400,
    )
      @client = Awscr::S3::Client.new(
        @region,
        @access_key,
        @secret_key,
        endpoint: @endpoint
      )
    end

    def write(filepath : String, content : IO) : Nil
      @client.put_object(
        @bucket,
        filepath,
        content
      )
    end

    def delete(filepath : String) : Nil
      @client.delete_object(@bucket, filepath)
    rescue Awscr::S3::NoSuchKey
      raise Marten::Core::Storage::Errors::FileNotFound.new("File '#{filepath}' not found in S3")
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
      generate_presigned_url(filepath)
    end

    private def public_url(filepath)
      File.join(@endpoint.not_nil!, @bucket, URI.encode_path(filepath))
    end

    private def generate_presigned_url(filepath : String)
      options = Awscr::S3::Presigned::Url::Options.new(
        aws_access_key: @access_key,
        aws_secret_key: @secret_key,
        region: @region,
        endpoint: @endpoint,
        bucket: @bucket,
        force_path_style: @force_path_style,
        object: filepath,
        expires: @expires_in
      )

      Awscr::S3::Presigned::Url.new(options).for(:get)
    end
  end
end
