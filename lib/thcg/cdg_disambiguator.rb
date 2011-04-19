base_path = File.expand_path(File.dirname(__FILE__))
require File.join(base_path, 'cdg_converter.rb')
require File.join(base_path, 'parser.rb')

cdg_file = ARGV.shift  
dep_file = ARGV.shift
skip = ARGV.shift.to_i

converter = THCG::CDGConverter.new

cdg_sents = File.new(cdg_file).each("\r\n\r\n")
dep_sents = File.new(dep_file).each("\n\n")

counters = Hash.new(0)

ambigous   = File.new(cdg_file+'.ambiguous', 'w')
unambigous = File.new(cdg_file+'.unambiguous', 'w')

begin
  while (cdg_sent = cdg_sents.next)
    if skip > 0 and counters[:skips] < skip
      counters[:skips] += 1
      dep_sents.next
      next
    end
    
    counters[:sentences] += 1
    cdg_parses = cdg_sent.chomp.split(/\r?\n/)
    unparsed = cdg_parses.shift
    cdg_forms = unparsed.split('|').compact.collect { |form| form.gsub(/\A"|"\Z/, '') }

    warn "Sentence #{counters[:sentences]}: #{unparsed}, #{cdg_parses.count} CDG parses"

    dep_tree = nil
    loop do
      begin
        dep_tree = Conll::Sentence.parse(dep_sents.next.split("\n"))
        break if cdg_forms == dep_tree.tokens.forms
        warn "\tSkipping: #{dep_tree.tokens.forms} != #{cdg_forms}"
        counters[:missing] += 1
      rescue StopIteration
        warn "No more dependency trees"
        exit 1
      end
    end

    if cdg_parses.count == 0
      counters[:no_cdgs] += 1
      warn ""
      next
    end
    
    target_head_ids = dep_tree.tokens.collect(&:head_id).collect(&:to_i)
    compatible = []
    warn "\tTarget dependencies: #{target_head_ids}"
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
    warn "\t#{compatible.count} compatible CDG parses"
    if compatible.count == 0
      counters[:incompatible] += 1
    elsif compatible.count == 1
      counters[:compatible] += 1
      counters[:unambiguous] += 1
      unambigous << unparsed + "\n" + compatible.join("\n") + "\n\n"
      unambigous.flush
    else
      counters[:compatible] += 1
      counters[:ambiguous] += 1 
      ambigous << unparsed + "\n" + compatible.join("\n") + "\n\n"
      ambigous.flush
    end
    warn ""
    warn "Counts: #{counters.sort.inspect}\n"
  end

ensure
  warn <<-eos
    Out of #{counters[:sentences]} dependency trees,
     - #{counters[:missing]} are missing from the CDG parser output
     - #{counters[:no_cdgs]} had 0 CDG parses,
     - #{counters[:incompatible]} had no CDG parses compatible with the NAIST dependency tree,
     - #{counters[:compatible] - counters[:ambiguous]} had a single CDG parse compatible with the NAIST dependency tree,
     - #{counters[:ambiguous]} had two or more CDG parses compatible with the NAIST dependency tree,
    totaling #{counters[:compatible]} NAIST dependency trees for which one or more CDG trees could be obtained.
  eos
end