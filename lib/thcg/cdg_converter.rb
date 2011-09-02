base_path = File.expand_path(File.dirname(__FILE__))
require File.join(base_path, 'parser.rb')

module THCG

  class CDGConverter
    
    attr_accessor :heads, :deprels

    def cdg2dep(tree)
      @heads = []
      @deprels = []
      tree.assign_heads!(self)
      return @heads
    end
    
    def register_head(node, other, deprel = nil)
      warn " [HEAD] head(#{node.proxied.id}) = #{other.proxied.id}" if $VERBOSE
      raise "head assignment to node with no ID" unless node.proxied.id
      raise "head assignment with node with no ID" unless other.proxied.id
      @heads[node.proxied.id]   ||= other.proxied.id
      @deprels[node.proxied.id] ||= deprel 
      node.parent.proxy(other)
    end
    
    def show_analysis(sentence)
      sentence.tree.terminals.each_with_index do |t, j|
        cg = t.type.to_s
        cdg = @dict.lookup!(t.token, cg)
        t.id = j+1
        warn " * Terminal #{t.id}: #{t.token}, #{cg} => #{cdg}"
        parsed_cdg = THCG::Parser.parse_syntactic_type(cdg)
        parsed_cdg.arguments.each do |arg|
          warn "    - #{arg}"
        end
        warn "    + yields: #{parsed_cdg.yielding}" 
      end
    end

    def convert_treebank(data, sent_no = nil)
      warn "Parsing #{data.count("\n")} lines..." 
      tb = THCG::Parser.parse(data)
      warn "done"
      warn "Processing #{tb.sentences.size} sentences..."
      tb.sentences.each_with_index do |s, i| 
        next unless sent_no.nil? or sent_no.to_i == i+1
        #        show_analysis(s) if $VERBOSE
        warn "Sentence #{i+1}: #{s.type}" if $VERBOSE
        warn s.tree if $DEBUG
        begin
          puts "#{convert_sentence(s)}\n\n"
        rescue ConversionError => e
          warn "#{e}"
          warn "Skipping sentence #{i+1}"
        end
      end
      warn "done"
    end
    
    def convert_sentence(s)
      s.tree.to_dependencies(self)
    end
    
  end

  class ConversionError < Exception
  end

end

if __FILE__ == $PROGRAM_NAME
  treebank_file, sent_no = ARGV

	converter = THCG::CDGConverter.new

  warn "Treebank file: #{treebank_file}"  
  converter.convert_treebank(File.open(treebank_file).read, sent_no)
end
