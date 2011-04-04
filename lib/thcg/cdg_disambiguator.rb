base_path = File.expand_path(File.dirname(__FILE__))
require File.join(base_path, 'cdg_converter.rb')
require File.join(base_path, 'parser.rb')

module THCG
  class CDGDisambiguator
    
    def initialize
    end
    
  end
end


if __FILE__ == $PROGRAM_NAME
  cdg_file = ARGV.shift  
  dep_file = ARGV.shift
  req_sent_no = ARGV.shift.to_i
  sent_no = 0
  
  converter = THCG::CDGConverter.new

  cdg_sents = File.new(cdg_file).each("\r\n\r\n")
  dep_sents = File.new(dep_file).each("\n\n")

  
  dep_tree = Conll::Sentence.parse(dep_sents.next.split("\n"))
  while (cdg_sent = cdg_sents.next)
    sent_no += 1
    next if req_sent_no > 0 and sent_no != req_sent_no
    
    cdg_parses = cdg_sent.chomp.split(/\r?\n/)
    unparsed = cdg_parses.shift
    cdg_forms = unparsed.split('|').compact

    warn "Sentence #{sent_no}: #{unparsed}, #{cdg_parses.count} CDG parses\n\tCDG forms: #{cdg_forms}\n\tDep forms: #{dep_tree.tokens.forms}"
    
    if cdg_forms != dep_tree.tokens.forms
      warn "Forms mismatch. Skipping (assuming missing dependency tree)"
      exit 1
    end
    
    target_head_ids = dep_tree.tokens.collect(&:head_id).collect(&:to_i)
    compatible = []
    warn "Target dependencies:    #{target_head_ids}"
    cdg_parses.each do |bracketed|
      begin
        cdg_tree = THCG::Parser.parse_bracketed(bracketed)
        candidate_dep_tree = cdg_tree.to_dependencies(converter)
        candidate_head_ids = candidate_dep_tree.tokens.collect(&:head_id)
        if target_head_ids == candidate_head_ids
          compatible << bracketed
        end
      rescue Exception => e
        warn "While processing: #{bracketed}"
        raise e
      end
    end
    warn "#{compatible.count} compatible CDG parses"
    puts compatible.join("\n")
#    break
    dep_tree = Conll::Sentence.parse(dep_sents.next.split("\n"))
  end
end