
module THCG
  class Map 

    def self.from_file(filename)
      self.from_tab(File.open(filename).read)
    end
    
    def self.from_tab(tabstr)
      mapping = {}
      tabstr.chomp.split(/(\s*\r?\n\s*)+/).each do |l|
        cdg, cg = l.split(/\t+/).map(&:strip)
        next if cg == "CG cat" or cdg == ''
        if mapping[cg]
          warn "Ambiguous CG->CDG mapping: #{cg} could be either #{cdg} or #{mapping[cg]}" 
          mapping.delete(cg)
        else
          mapping[cg] = cdg
        end
      end
      Map.new(mapping)
    end
    
    def initialize(mapping)      
      raise "Expected hash" unless mapping.is_a? Hash
      @map = mapping      
      warn "#{@map.size} CG->CDG mapping(s)" 
    end
    
    def lookup(cg)
      if cg =~ %r{[\\/]}
        @map[cg] 
      else
        cg
      end
    end
    
    def lookup!(cg)
      lookup(cg) or raise MappingError, "No mapping for: #{cg}"
    end
    
  end
end
