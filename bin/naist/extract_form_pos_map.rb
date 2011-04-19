require 'conll'
require 'set'

form_tags = Hash.new { |hash,key| hash[key] = Set.new }

Conll::Corpus.parse(ARGV[0]) do |sentence|
  sentence.tokens.each do |token|
    form_tags[token.form] << token.pos
  end
end

form_tags.each_pair do |form, tags|  
  puts "#{form}\t#{tags.to_a.join(',')}"
end
