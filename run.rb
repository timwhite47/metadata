require "open-uri"
require "logger"
require "json"
require 'mida'
require "newster"
require "simple_stats"
require "ruby-progressbar"
include Newster

logger = Logger.new(STDOUT)

puts 'getting articles'
articles = Source.all.inject({}) {|h, source|
	h[source.name] = source.articles.fields(:url).limit(250).collect &:url
	h
}
articles.each do |source_name, urls|
	bar = ProgressBar.create total: urls.count, format: '%e %B %p%% %t', title: source_name
	vals = urls.collect do |url|
		html = open url
		doc = Nokogiri::HTML html
		meta_types = doc.search("meta")
		meta_types = meta_types.collect {|tag| tag.attr("name") || tag.attr("property") }
		microdata = Mida::Document.new(doc.to_s).items
		microdata.collect! &:type
		bar.increment

		{ meta_types: meta_types, microdata: (microdata || []) }
	end

	tags = vals.collect {|v| v['meta_types'].compact }.flatten.compact.frequencies
	mdata = vals.collect {|v| v['microdata'] }.flatten.compact.frequencies
	data = {
		mdata: mdata, 
		tags: tags
	}
	
	File.open("#{source_name}.json", "w") { |file| file.puts data.to_json }
end