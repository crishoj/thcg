require 'polyglot'
require 'treetop'
require 'set'

module Naist
  class Treebank
    attr_reader :trees
    def initialize(filename)
      @trees = []
      File.foreach(filename, "\n\n") { |sent| 
        sent_parts = sent.chomp.chomp.split("\n")
        if sent_parts.length == 3
          @trees << sent_parts.last
        else
          raise "Unexpected number of parts: #{sent_parts.join("\n\n")}"
        end
      }
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  filename = ARGV[0]
  puts "Reading #{filename} ..."  
  treebank = Naist::Treebank.new(filename)
	puts "Loaded #{treebank.trees.length} trees"
  tag_counts = Hash.new(0)
  examples = {}
  pos_re = /"pos": "([^""]+)"/
  treebank.trees.each do |tree|
    tree.scan(pos_re) do |match|
      pos_tag = match.first
      tag_counts[pos_tag] += 1
      examples[pos_tag] ||= tree
    end
  end
#  tag_counts = tag_counts.sort { |a,b| a[1] <=> b[1] }.reverse
#  tag_counts.each do |tag, count|
#    puts "#{tag} occurs #{count} time(s)"
#  end
  examples.each do |tag, example|
    puts "\nExample tree for the tag '#{tag}':\n#{example}" unless %w{conjncl ppos vcau psm advm2 pper prec pind pint part ntit pref3 advm3 honm advm5 vex pdem}.include?(tag)
  end
end