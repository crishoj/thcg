base_path = File.expand_path(File.dirname(__FILE__))
require File.join(base_path, 'cdg_converter.rb')
require File.join(base_path, 'dictionary.rb')
require File.join(base_path, 'map.rb')

module THCG
  
  class CGConverter < CDGConverter
    
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
    
    def convert_sentence(s)
      cg2cdg(s.tree)
      warn s.tree if $DEBUG
      super(s)
    end
    
  end
  
  class MappingError < ConversionError
  end
  
end

if __FILE__ == $PROGRAM_NAME
  treebank_file, dictionary_file, map_file, sent_no = ARGV
  
  warn "Dictionary file: #{dictionary_file}"
  dictionary = THCG::Dictionary.new(dictionary_file)

  warn "Map file: #{map_file}"
  map = THCG::Map.from_file(map_file)

	converter = THCG::CGConverter.new(dictionary, map)

  warn "Treebank file: #{treebank_file}"  
  converter.convert_treebank(File.open(treebank_file).read, sent_no)
end