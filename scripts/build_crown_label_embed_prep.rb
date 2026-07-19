#!/usr/bin/env ruby
# frozen_string_literal: true
# Prepares embedding requests for every distinct RAW motif label across all
# extraction records (blind: uses the free-text label, never taxonomy_refs).
# Records each label's tradition spread and which pile (isolated/connected)
# it appears in, for the crown independent-taxonomy experiment.
require_relative "batch_common"
ISOLATED = %w[australian-aboriginal indigenous-australian inuit
  khoisan-south-african san zulu siberian guiana-amerindian amazonian
  andamanese maya mesoamerican nahua nahua-maya-inca navajo zuni hopi
  hawaiian tsimshian native-american-great-lakes native-american-northwest-coast
  native-american-plains native-american-southeast native-american-southwest
  native-american-northeast-woodlands].to_set
run_id = "crown-label-embed-2026-07-18"
labels = {} # normalized label => {label, isolated_traditions:Set, connected_traditions:Set}
Dir.glob(File.join(AtlasBatch::ROOT, "extractions/**/*.{yml,yaml}")).each do |path|
  rec = AtlasBatch.load_yaml(path); next unless rec.is_a?(Hash)
  src = rec["source_text_path"].to_s; next if src.empty?
  trad = src.split("/")[2].to_s; next if trad == "comparative"
  pile = ISOLATED.include?(trad) ? :iso : :con
  Array(rec["candidate_motifs"]).each do |m|
    lab = m["label"].to_s.strip; next if lab.length < 4
    key = lab.downcase
    e = (labels[key] ||= {"label"=>lab, "iso"=>[], "con"=>[]})
    (pile == :iso ? e["iso"] : e["con"]) << trad
  end
end
labels.each_value { |e| e["iso"].uniq!; e["con"].uniq! }
puts "distinct raw labels: #{labels.length} (iso-only #{labels.count{|_,e|e["con"].empty?}}, con-only #{labels.count{|_,e|e["iso"].empty?}}, both #{labels.count{|_,e|!e["iso"].empty?&&!e["con"].empty?}})"
reqs=[]; map=[]
labels.each_with_index do |(key,e),i|
  cid = "crownlab:#{i}"
  reqs << {"custom_id"=>cid,"method"=>"POST","url"=>"/v1/embeddings","body"=>{"model"=>"text-embedding-3-large","input"=>e["label"],"dimensions"=>512}}
  map << {"custom_id"=>cid,"label"=>e["label"],"iso_traditions"=>e["iso"],"con_traditions"=>e["con"]}
end
dir = File.join(AtlasBatch.batch_dir(run_id),"requests"); FileUtils.mkdir_p(dir)
shards=[]
reqs.each_slice(3000).with_index do |sl,idx|
  sid="shard-%04d"%(idx+1); p=File.join(dir,"#{sid}.jsonl"); AtlasBatch.write_jsonl(p,sl,force:true)
  shards<<{"shard_id"=>sid,"path"=>AtlasBatch.relative_path(p),"request_count"=>sl.length,"bytes"=>File.size(p),"sha256"=>AtlasBatch.sha256_file(p),"endpoint"=>"/v1/embeddings","model"=>"text-embedding-3-large","status"=>"prepared"}
end
AtlasBatch.write_jsonl(File.join(AtlasBatch.batch_dir(run_id),"request-map.jsonl"),map,force:true)
AtlasBatch.write_yaml(File.join(dir,"index.yml"),{"batch_request_index_version"=>"1","run_id"=>run_id,"created_at"=>AtlasBatch.utc_now,"updated_at"=>AtlasBatch.utc_now,"endpoint"=>"/v1/embeddings","model"=>"text-embedding-3-large","shards"=>shards})
m=AtlasBatch.load_manifest(run_id); m["artifacts"]["requests_index_path"]=AtlasBatch.relative_path(File.join(dir,"index.yml")); AtlasBatch.save_manifest(m)
puts "prepared #{reqs.length} label-embed requests in #{shards.length} shards"
