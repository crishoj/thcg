#!/usr/bin/env ruby 
require 'commander/import'

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
require 'thcg'
require 'thcg/parser'
require 'thcg/cdg_converter'

program :version, THCG::VERSION
program :description, 'Command to work with Thai CG/CDG treebanks.'

default_command :help

global_option('--dos') { $/ = "\r\n" }

command :sort do |c|
  c.syntax = 'thcg sort'
  c.description = 'Sort sentences in a treebank with multiple CDG parse trees per sentences in increasing order of ambiguity.'
  c.action do |args, options|
    source = args.empty? ? STDIN : File.new(cdg_file)
    sorted = source.each($/ * 2).sort_by { |cdg_sent| cdg_sent.count("\n") }
    print sorted.join
  end
end

command :deduplicate do |c|
  c.syntax = 'thcg deduplicate'
  c.description = 'Remove duplicate sentences from a treebank (according to surface form).'
  c.action do |args, options|
    seen = Hash.new(0)
    source = args.empty? ? STDIN : File.new(cdg_file)
    lines = source.each($/)
    while line = lines.next
      cdg_sent = line + lines.next
      surface = cdg_sent.split($/).first.strip
      if seen[surface] == 0
        print cdg_sent 
      end
      seen[surface] += 1
    end
  end
end

command :cg2dep do |c|
  c.syntax = 'thcg cg2dep --dictionary FILE --map FILE [options] TREEBANK_FILE'
  c.option '--dictionary FILE', 'CDG dictionary'
  c.option '--map FILE', 'Generic CG->CDG mapping for OOV fallback'
  c.option '--sent-no N', 'Optionally convert a single sentence'
  c.description = 'Enrich CG trees with dependency directions and derive dependency trees'
  c.action do |args, options|
    require 'thcg/cg_converter'

    dictionary_file = options.dictionary
    raise "Dictionary file #{dictionary_file} not found" unless dictionary_file and File.readable? dictionary_file
    warn "Dictionary file: #{dictionary_file}"
    dictionary = THCG::Dictionary.new(dictionary_file)

    map_file = options.map
    raise "Map file #{map_file} not found" unless map_file and File.readable? map_file
    warn "Map file: #{map_file}"
    map = THCG::Map.from_file(map_file)

    treebank_file = args.first
    raise "Treebank file #{treebank_file} not found" unless treebank_file and File.readable? treebank_file
    warn "Treebank file: #{treebank_file}"  

    sent_no = options.sent_no
    converter = THCG::CGConverter.new(dictionary, map)
    converter.convert_treebank(File.open(treebank_file).read, sent_no)
  end
end

command :cdg2dep do |c|
  c.syntax = 'thcg cdg2dep [options] TREEBANK'
  c.description = 'Derive dependency trees from CDG trees'
  c.option '--sent-no N', 'Optionally convert a single sentence'
  c.action do |args, options|
    require 'thcg/cdg_converter'

    treebank_file = args.first
    raise "Treebank file #{treebank_file} not found" unless treebank_file and File.readable? treebank_file
    warn "Treebank file: #{treebank_file}"  

    converter = THCG::CDGConverter.new
    converter.convert_treebank(File.open(treebank_file).read, sent_no)
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

command :cdg_deprels do |c|
  c.syntax = 'thcg cdg_deprels CDG_PARSES CONLL_FILE'
  c.description = 'What dependency relations do different CDG categories give rise to?'
  c.option '--external-pos-tags FILE', 'Include POS tags from FILE'
  c.option '--include-head', 'Include head CDG type in counts'
  c.option '--with-head CDG', String, 'Count only the given head CDG type'
  c.option '--with-dependent CDG', String, 'Count only the given dependent CDG type'
  c.option '--with-dir DIR', String, 'Count only dependencies in given direction (L/R)'
  c.option '--print', 'Show matched sentences'
  c.option '--features', 'Output features suitable for learning'
  c.action do |args, options|
    cdg_file, dep_file = args
    warn "Reading CDG sentences from           #{cdg_file}"
    warn "Reading CONLL trees from             #{dep_file}"
    cdg_sents = File.new(cdg_file).each("\n\n")
    dep_sents = File.new(dep_file).each("\n\n")
    pos_sents = File.new(options.external_pos_tags).each("\n\n") if options.external_pos_tags
    headers = [
      'deprel', 
      'cdg',
      'head_cdg',
      'left_siblings',
      'right_siblings',
      'cdg+position',
      'head_cdg+position',
      'dep_dir',
      'form',
      'head_form',
      'gold_pos',
    ]
    headers << 'external_pos' if pos_sents
    puts headers.join("\t")
    begin
      cdg_deprels = Hash.new { |cdgs,cdg| cdgs[cdg] = Hash.new(0) }
      while (cdg_sent = cdg_sents.next)
        tokenized, bracketed = cdg_sent.chomp.split(/\r?\n/)
        cdg_forms = tokenized.split('|').compact.collect { |form| form.gsub(/\A"|"\Z/, '') }
        warn tokenized if $VERBOSE
        dep_tree = nil
        external_pos_tags = nil
        loop do
          begin
            dep_tree = Conll::Sentence.parse(dep_sents.next.split("\n"))
            external_pos_tags = pos_sents.next.split("\n") if pos_sents
            break if cdg_forms == dep_tree.tokens.forms
            warn "\tSkipping: #{dep_tree.tokens.forms}" if $VERBOSE
          rescue StopIteration
            warn "No more dependency trees" 
            exit 1
          end
        end
        warn "\tMatched: #{dep_tree.tokens.forms}" if $VERBOSE
        cdg_tree = THCG::Parser.parse_bracketed(bracketed)
        for i in 0...cdg_tree.terminals.count
          cdg_tok, dep_tok = cdg_tree.terminals[i], dep_tree.tokens[i]
          key = cdg_tok.type.to_s
          next if dep_tok.head_id.to_i == 0 # only non-root relations are interesting
          head_cdg_tok = cdg_tree.terminals[dep_tok.head_id.to_i - 1]
          dep_dir = dep_tok.id.to_i < dep_tok.head_id.to_i ? "R" : "L"
          next if options.with_dependent and not options.with_dependent == cdg_tok.type.to_s
          next if options.with_head and not options.with_head == head_cdg_tok.type.to_s
          next if options.with_dir and not dep_dir == options.with_dir
          key += " <- #{head_cdg_tok.type}" if options.include_head
          cdg_deprels[key][dep_tok.deprel] += 1
          if options.print
            puts "Head: #{head_cdg_tok.token}"
            puts "Dependent: #{cdg_tok.token}"
            puts "Dir: #{dep_dir}"
            puts "Label: #{dep_tok.deprel}"
            puts bracketed
            puts dep_tree
            puts
          end
          if options.features
            fields = [
              dep_tok.deprel, 
              cdg_tok.type.to_s, 
              head_cdg_tok.type.to_s,
              cdg_tok.left_siblings.count,
              cdg_tok.right_siblings.count,
              "#{cdg_tok.type.to_s}+#{cdg_tok.left_siblings.count}",
              "#{head_cdg_tok.type.to_s}+#{cdg_tok.left_siblings.count}",
              dep_dir,
              cdg_tok.token,
              head_cdg_tok.token,
              dep_tok.pos,
            ]
            fields << external_pos_tags.shift if external_pos_tags
            puts fields.join("\t")
          end
        end
      end
    rescue StopIteration
    ensure
      unless options.features
        cdg_deprels.each_pair do |cdg, deprels| 
          puts
          puts cdg
          puts " => \t" + deprels.sort_by { |deprel,count| count }.reverse.collect { |deprel,count| 
            "#{deprel} (#{count} times)"
          }.join(', ')
        end
      end
    end
  end
end