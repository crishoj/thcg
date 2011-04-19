#!/usr/bin/env ruby 
require 'commander/import'

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
require 'thcg'
require 'thcg/parser'
require 'thcg/cdg_converter'

program :version, THCG::VERSION
program :description, 'Command to work with Thai CG/CDG treebanks.'

default_command :help

command :sort do |c|
  c.syntax = 'thcg sort'
  c.description = 'Sort sentences in a treebank with multiple CDG parse trees per sentences in increasing order of ambiguity.'
  c.action do |args, options|
    source = args.empty? ? STDIN : File.new(cdg_file)
    sorted = source.each("\n\n").sort_by { |cdg_sent| cdg_sent.count("\n") }
    print sorted.join
  end
end

command :disambiguate do |c|
  c.syntax = 'thcg disambiguate CDG_PARSES CONLL_FILE'
  c.description = 'Filter CDG parse trees, leaving only those with derived dependency trees consistent with reference dependency trees.'
  c.option '--skip N', Integer, 'Skip the first N sentences'
  c.action do |args, options|
    cdg_file, dep_file = args
    say "Reading CDG sentences from           #{cdg_file}"
    say "Reading CONLL trees from             #{dep_file}"
    cdg_sents  = File.new(cdg_file).each("\r\n\r\n")
    dep_sents  = File.new(dep_file).each("\n\n")
    ambigous   = File.new(cdg_file+'.ambiguous', 'w')
    unambigous = File.new(cdg_file+'.unambiguous', 'w')
    say "Writing ambiguous CDG sentences to   #{ambigous.path}"
    say "Writing unambiguous CDG sentences to #{unambigous.path}"
    counters = Hash.new(0)
    converter = THCG::CDGConverter.new
    begin
      while (cdg_sent = cdg_sents.next)
        if options.skip && options.skip > 0 and counters[:skips] < skip
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
  end
end
