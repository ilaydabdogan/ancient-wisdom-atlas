#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "optparse"
require "securerandom"
require "time"
require "uri"
require "yaml"

module AtlasBatch
  ROOT = File.expand_path("..", __dir__)
  BATCH_ROOT = File.join(ROOT, "data", "batches")
  DEFAULT_ENDPOINT = "/v1/responses"
  DEFAULT_COMPLETION_WINDOW = "24h"

  module_function

  def die(message, code = 1)
    warn message
    exit code
  end

  def relative_path(path)
    File.expand_path(path, ROOT).sub("#{ROOT}/", "")
  end

  def project_path(path)
    File.expand_path(path, ROOT)
  end

  def utc_now
    Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  def sha256_file(path)
    Digest::SHA256.file(path).hexdigest
  end

  def sha256_text(text)
    Digest::SHA256.hexdigest(text)
  end

  def safe_slug(value, fallback: "item")
    slug = value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    slug.empty? ? fallback : slug
  end

  def safe_filename(value, fallback: "item")
    safe_slug(value, fallback: fallback)
  end

  def load_yaml(path, default = {})
    return default unless File.file?(path)

    YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: false) || default
  end

  def write_yaml(path, data)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{YAML.dump(data)}\n")
  end

  def read_jsonl(path)
    File.readlines(path, chomp: true).map do |line|
      next nil if line.strip.empty?

      JSON.parse(line)
    end.compact
  end

  def write_jsonl(path, records, force: false)
    content = records.map { |record| JSON.generate(record) }.join("\n")
    content = "#{content}\n" unless content.empty?
    write_if_changed(path, content, force: force)
  end

  def write_if_changed(path, content, force: false)
    if File.file?(path)
      existing = File.binread(path)
      return :unchanged if existing == content

      die "#{relative_path(path)} exists and differs; rerun with --force to replace it" unless force
    end

    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
    :written
  end

  def batch_dir(run_id)
    File.join(BATCH_ROOT, run_id)
  end

  def manifest_path(run_id)
    File.join(batch_dir(run_id), "manifest.yml")
  end

  def load_manifest(run_id)
    path = manifest_path(run_id)
    manifest = load_yaml(path, {})
    manifest["batch_pipeline_manifest_version"] ||= "1"
    manifest["run_id"] ||= run_id
    manifest["created_at"] ||= utc_now
    manifest["updated_at"] ||= manifest["created_at"]
    manifest["artifacts"] ||= {}
    manifest["openai"] ||= {}
    manifest["state"] ||= {}
    manifest
  end

  def save_manifest(manifest)
    manifest["updated_at"] = utc_now
    write_yaml(manifest_path(manifest.fetch("run_id")), manifest)
  end

  def append_unique(array, item, key)
    existing_index = array.index { |entry| entry[key] == item[key] }
    if existing_index
      array[existing_index] = array[existing_index].merge(item)
    else
      array << item
    end
    array
  end

  def read_markdown(path)
    lines = File.readlines(path, chomp: true)
    metadata = {}
    body_start_index = 0

    if lines.first&.match?(/\A---\s*\z/)
      closing_index = (1...lines.length).find { |index| lines[index].match?(/\A---\s*\z/) }
      if closing_index
        front_matter = lines[1...closing_index].join("\n")
        metadata = YAML.safe_load(front_matter, permitted_classes: [Date, Time], aliases: false) || {}
        body_start_index = closing_index + 1
      end
    end

    body_lines = lines[body_start_index..] || []
    entries = body_lines.each_with_index.map do |line, index|
      [body_start_index + index + 1, line.rstrip]
    end

    {
      "metadata" => metadata,
      "body_entries" => entries,
      "body" => body_lines.join("\n")
    }
  end

  def paragraphs_from_entries(entries)
    paragraphs = []
    current = []
    start_line = nil
    end_line = nil

    flush = lambda do
      unless current.empty?
        paragraphs << {
          "start_line" => start_line,
          "end_line" => end_line,
          "text" => current.join("\n")
        }
      end
      current = []
      start_line = nil
      end_line = nil
    end

    entries.each do |line_number, line|
      if line.strip.empty?
        flush.call
        next
      end

      start_line ||= line_number
      end_line = line_number
      current << line
    end

    flush.call
    paragraphs
  end

  def heading_label(line)
    stripped = line.strip
    if (match = stripped.match(/\A\#{1,6}\s+(.+?)\s*\z/))
      return match[1].strip
    end

    return stripped if stripped.match?(/\A(?:book|chapter|canto|runo|part|sura|sure)\s+[\w .:-]+\z/i) && stripped.length <= 90
    return stripped if stripped.match?(/\A[A-Z][A-Z0-9 ,.';:!?()-]{4,89}\z/) && stripped.count("a-z").zero?

    nil
  end

  def openai_api_key
    azure_key = ENV["AZURE_OPENAI_API_KEY"].to_s.strip
    return azure_key unless azure_key.empty?

    ENV["OPENAI_API_KEY"].to_s.strip.tap do |key|
      die "OPENAI_API_KEY (or AZURE_OPENAI_API_KEY + AZURE_OPENAI_ENDPOINT) is required for OpenAI API operations" if key.empty?
    end
  end

  # With AZURE_OPENAI_ENDPOINT set (e.g. https://myresource.openai.azure.com),
  # requests go to Azure OpenAI's OpenAI-compatible /openai/v1 surface; model
  # values in request JSONL must then be Azure deployment names.
  def openai_base_url
    azure_endpoint = ENV["AZURE_OPENAI_ENDPOINT"].to_s.strip
    return "#{azure_endpoint.chomp("/")}/openai/v1" unless azure_endpoint.empty?

    ENV.fetch("OPENAI_BASE_URL", "https://api.openai.com/v1")
  end

  class OpenAIClient
    def initialize(api_key: AtlasBatch.openai_api_key, base_url: AtlasBatch.openai_base_url)
      @api_key = api_key
      @base_url = base_url.end_with?("/") ? base_url : "#{base_url}/"
      @azure = !ENV["AZURE_OPENAI_ENDPOINT"].to_s.strip.empty?
    end

    def get_json(path)
      response = request(:get, path)
      parse_json_response(response)
    end

    def post_json(path, body)
      response = request(:post, path, JSON.generate(body), "Content-Type" => "application/json")
      parse_json_response(response)
    end

    def upload_file(path, purpose: "batch")
      boundary = "----atlas-batch-#{SecureRandom.hex(12)}"
      body = +""
      add_multipart_field(body, boundary, "purpose", purpose)
      add_multipart_file(body, boundary, "file", path, "application/jsonl")
      body << "--#{boundary}--\r\n"

      response = request(:post, "files", body, "Content-Type" => "multipart/form-data; boundary=#{boundary}")
      parse_json_response(response)
    end

    def download_file(file_id)
      response = request(:get, "files/#{URI.encode_www_form_component(file_id)}/content")
      unless response.code.to_i.between?(200, 299)
        raise "OpenAI API #{response.code}: #{response.body}"
      end

      response.body
    end

    private

    def request(method, path, body = nil, extra_headers = {})
      uri = URI.join(@base_url, path.sub(%r{\A/+}, ""))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = 120
      http.open_timeout = 30

      request_class = method == :post ? Net::HTTP::Post : Net::HTTP::Get
      request = request_class.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["api-key"] = @api_key if @azure
      extra_headers.each { |key, value| request[key] = value }
      request.body = body if body
      http.request(request)
    end

    def parse_json_response(response)
      unless response.code.to_i.between?(200, 299)
        raise "OpenAI API #{response.code}: #{response.body}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise "OpenAI API returned invalid JSON: #{e.message}"
    end

    def add_multipart_field(body, boundary, name, value)
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n"
      body << "#{value}\r\n"
    end

    def add_multipart_file(body, boundary, name, path, content_type)
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{File.basename(path)}\"\r\n"
      body << "Content-Type: #{content_type}\r\n\r\n"
      body << File.binread(path)
      body << "\r\n"
    end
  end
end
