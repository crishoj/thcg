base_path = File.expand_path(File.dirname(__FILE__))
require File.join(base_path, 'thcg_parser.rb')
require File.join(base_path, 'thcg_dictionary.rb')
require File.join(base_path, 'thcg_map.rb')

module THCG
  
  class Converter
    
    attr_accessor :heads, :deprels

    def initialize(dictionary, map)
      @dict, @map = dictionary, map
    end
    
    def cg2cdg(tree)
      tree.terminals.each do |node|
        cg = node.type.to_s
        if cg =~ %r{[/\\]}
          begin 
            cdg = @dict.lookup!(node.token.to_s, cg)
          rescue MappingError => e
            warn "#{e} - falling back on CD->CDG map"
            cdg = @map.lookup!(cg)
          end
          node.type = THCG::Parser.parse_syntactic_type(cdg)
          warn "#{node.token}: #{cg} => #{cdg}" if $DEBUG
        end
      end
      adopt_child_type(tree.root)
    end
    
    def adopt_child_type(node)
      node.children.each { |child| adopt_child_type(child) }
      return if node.type.primitive?
      return if node.type.has_dependency_directions?
      node.children.each do |child|
        next if child.type.primitive?
        warn "#{child.type} yields #{node.type} ? " if $DEBUG
        if child.type.yields?(node.type)
          warn "YES" if $DEBUG
          adopted = adopt_dependency_directions(node.type.to_s, child.type.to_s)
          warn "#{node.type} \t<== #{adopted}" if $DEBUG
          node.type = THCG::Parser.parse_syntactic_type(adopted)
          break
        else
          warn "NO" if $DEBUG
        end
      end
    end

    def adopt_dependency_directions(target_type, source_type)
      directions = source_type.chars.find_all { |c| c == '>' or c == '<' }
      target_type.gsub(%r{[/\\]}) { |applicator| applicator += directions.shift }
    end
    
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
          cg2cdg(s.tree)
          warn s.tree if $DEBUG
          puts s.tree.to_dependencies(self) + "\n"
        rescue MappingError => e
          warn "#{e}"
          warn "Skipping sentence #{i+1}"
        end
      end
      warn "done"
    end

  end
  
  class MappingError < Exception
  end
  
end

if __FILE__ == $PROGRAM_NAME
  dictionary_file, map_file, treebank_file, sent_no = ARGV

  warn "Dictionary file: #{dictionary_file}"
  dictionary = THCG::Dictionary.new(dictionary_file)

  warn "Map file: #{map_file}"
  map = THCG::Map.from_file(map_file)

	converter = THCG::Converter.new(dictionary, map)

  warn "Treebank file: #{treebank_file}"  
  converter.convert_treebank(File.open(treebank_file).read, sent_no)
end