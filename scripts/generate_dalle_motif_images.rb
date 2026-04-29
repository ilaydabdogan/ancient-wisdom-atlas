#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "fileutils"
require "json"
require "net/http"
require "optparse"
require "time"
require "uri"

ROOT = File.expand_path("..", __dir__)
DEFAULT_INPUT = "tmp/imagegen/recurring-motif-prompts.jsonl"
DEFAULT_OUTPUT_DIR = "output/imagegen/recurring-motifs"
DEFAULT_MODEL = "dall-e-3"
DEFAULT_SIZE = "1792x1024"
DEFAULT_QUALITY = "hd"
IMAGE_ENDPOINT = "https://api.openai.com/v1/images/generations"

OPTIONS = {
  input: DEFAULT_INPUT,
  out_dir: DEFAULT_OUTPUT_DIR,
  model: DEFAULT_MODEL,
  size: DEFAULT_SIZE,
  quality: DEFAULT_QUALITY,
  force: false,
  dry_run: false,
  limit: nil,
  max_attempts: 3,
  sleep: 1.0
}.freeze

def project_path(path)
  File.expand_path(path, ROOT)
end

def load_jsonl(path)
  File.foreach(path).with_index(1).map do |line, lineno|
    stripped = line.strip
    next if stripped.empty?

    JSON.parse(stripped)
  rescue JSON::ParserError => e
    warn "invalid JSON at #{path}:#{lineno}: #{e.message}"
    exit 1
  end.compact
end

def augment_prompt(job)
  sections = []
  sections << "Use case: #{job["use_case"]}" if job["use_case"].to_s != ""
  sections << "Primary request: #{job.fetch("prompt")}"
  sections << "Style/medium: #{job["style"]}" if job["style"].to_s != ""
  sections << "Composition/framing: #{job["composition"]}" if job["composition"].to_s != ""
  sections << "Lighting/mood: #{job["lighting"]}" if job["lighting"].to_s != ""
  sections << "Color palette: #{job["palette"]}" if job["palette"].to_s != ""
  sections << "Constraints: #{job["constraints"]}" if job["constraints"].to_s != ""
  sections << "Avoid: #{job["negative"]}" if job["negative"].to_s != ""
  sections.join("\n")
end

def output_path(out_dir, job, index)
  explicit = job["out"].to_s
  filename = explicit == "" ? format("%03d.png", index) : File.basename(explicit)
  filename = "#{filename}.png" unless File.extname(filename) != ""
  File.join(out_dir, filename)
end

def sidecar_path(image_path)
  image_path.sub(/\.[^.]+\z/, ".json")
end

def api_request(payload, api_key)
  uri = URI(IMAGE_ENDPOINT)
  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "Bearer #{api_key}"
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(payload)

  Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end
end

def retryable_status?(code)
  code.to_i == 429 || code.to_i >= 500
end

def write_image_and_sidecar(response_body, image_path, metadata)
  parsed = JSON.parse(response_body)
  first = parsed.fetch("data").fetch(0)
  image_b64 = first.fetch("b64_json")

  FileUtils.mkdir_p(File.dirname(image_path))
  File.binwrite(image_path, Base64.decode64(image_b64))

  sidecar = metadata.merge(
    "created" => parsed["created"],
    "revised_prompt" => first["revised_prompt"],
    "image_path" => image_path,
    "generated_at" => Time.now.utc.iso8601
  )
  File.write(sidecar_path(image_path), "#{JSON.pretty_generate(sidecar)}\n")
end

options = OPTIONS.dup

OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/generate_dalle_motif_images.rb [options]"
  parser.on("--input PATH", "Prompt JSONL path") { |value| options[:input] = value }
  parser.on("--out-dir PATH", "Output directory") { |value| options[:out_dir] = value }
  parser.on("--model MODEL", "Image model") { |value| options[:model] = value }
  parser.on("--size SIZE", "Image size") { |value| options[:size] = value }
  parser.on("--quality QUALITY", "DALL-E quality: standard or hd") { |value| options[:quality] = value }
  parser.on("--limit N", Integer, "Generate only the first N jobs") { |value| options[:limit] = value }
  parser.on("--max-attempts N", Integer, "Retry attempts for 429/5xx") { |value| options[:max_attempts] = value }
  parser.on("--sleep SECONDS", Float, "Pause between successful calls") { |value| options[:sleep] = value }
  parser.on("--force", "Overwrite existing PNGs") { options[:force] = true }
  parser.on("--dry-run", "Print planned files without API calls") { options[:dry_run] = true }
end.parse!

input_path = project_path(options[:input])
out_dir = project_path(options[:out_dir])
jobs = load_jsonl(input_path)
jobs = jobs.first(options[:limit]) if options[:limit]

api_key = ENV["OPENAI_API_KEY"].to_s
if api_key == "" && !options[:dry_run]
  warn "OPENAI_API_KEY is not set."
  exit 2
end

jobs.each_with_index do |job, index|
  job_number = index + 1
  image_path = output_path(out_dir, job, job_number)
  prompt = augment_prompt(job)

  if File.exist?(image_path) && !options[:force]
    warn "[job #{job_number}/#{jobs.length}] skipping existing #{image_path}"
    next
  end

  payload = {
    model: options[:model],
    prompt: prompt,
    n: 1,
    size: options[:size],
    quality: options[:quality],
    response_format: "b64_json"
  }

  if options[:dry_run]
    puts JSON.pretty_generate(payload.merge(output: image_path))
    next
  end

  warn "[job #{job_number}/#{jobs.length}] generating #{File.basename(image_path)}"
  response = nil
  options[:max_attempts].times do |attempt|
    response = api_request(payload, api_key)
    break if response.is_a?(Net::HTTPSuccess)

    body = response.body.to_s
    if retryable_status?(response.code) && attempt < options[:max_attempts] - 1
      sleep_seconds = 2**attempt
      warn "[job #{job_number}/#{jobs.length}] HTTP #{response.code}; retrying in #{sleep_seconds}s"
      sleep sleep_seconds
      next
    end

    warn "[job #{job_number}/#{jobs.length}] failed HTTP #{response.code}: #{body}"
    exit 1
  end

  write_image_and_sidecar(
    response.body,
    image_path,
    {
      "source_prompt_jsonl" => options[:input],
      "job_index" => job_number,
      "motif_output_name" => job["out"],
      "model" => options[:model],
      "size" => options[:size],
      "quality" => options[:quality],
      "prompt" => prompt
    }
  )
  warn "[job #{job_number}/#{jobs.length}] wrote #{image_path}"
  sleep options[:sleep] if options[:sleep].positive?
end
