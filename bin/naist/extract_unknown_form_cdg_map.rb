require 'conll'
require 'set'
require 'thcg_dictionary'

pos_forms = Hash.new { |hash,key| hash[key] = Set.new }

Conll::Corpus.parse(ARGV[0]) do |sentence|
  sentence.tokens.each do |token|
    pos_forms[token.pos] << token.form
  end
end

dict = THCG::Dictionary.new(ARGV[1])
pos_cdgs = Hash.new { |hash,key| hash[key] = Set.new }

pos_forms.each_pair do |pos, forms|
  forms.each do |form|
    if (cdgs = dict.lookup_cdgs(form))
      cdgs.each do |cdg|
        pos_cdgs[pos] << cdg
      end
    else 
      warn "No CDG types found for #{form}" if $DEBUG
    end
  end
end

warn "Possible CDG types found for #{pos_cdgs.length} POS tags"

form_cdgs = Hash.new { |hash,key| hash[key] = Set.new }

Conll::Corpus.parse(ARGV[0]) do |sentence|
  sentence.tokens.each do |token|
    pos_cdgs[token.pos].each do |cdg|
      form_cdgs[token.form] << cdg
    end unless dict.lookup_cdgs(token.form)
  end
end

warn "Possible CDG types found for #{form_cdgs.length} word forms"

form_cdgs.each_pair do |form, cdgs|  
  puts "#{form}\t#{cdgs.to_a.join(',')}"
end

