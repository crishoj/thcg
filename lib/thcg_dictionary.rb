# coding: UTF-8

class Array
  def sum
    inject { |sum,x| sum + x }
  end
  def mean
    sum / size
  end
end

module THCG
  class Dictionary
    def initialize(filename)
      warn "Building dictionary from #{filename}" 
      @cdgs = {}
      File.foreach(filename) do |line|
        form, cat_str = line.chomp.split("\t")
        next unless cat_str
        @cdgs[form] = cat_str.split(',').map(&:strip)
      end
      warn "#{@cdgs.size} forms, #{@cdgs.map(&:size).mean} CDGS/form on average" 
      @map = {}
      warn "Building CG->CDG map"
      @cdgs.each_pair do |form, cats| 
        @map[form] = {}
        cats.each do |cdg|
          cg = cdg.gsub(/[<>]/, '') 
          if @map[form][cg]
            warn "Ambiguous CG->CDG mapping for #{form}: #{cg} could be either #{cdg} or #{@map[form][cg]}" 
            @map.delete(cg)
          else
            @map[form][cg] = cdg
          end
        end
      end
    end
    def lookup!(form, cg)
      lookup(form, cg) or raise MappingError, "No mapping of #{cg} for '#{form}'"
    end
    def lookup(form, cg)
      @map[form][cg] if @map[form]
    end
    def lookup_cdgs(form)
      @cdgs[form]
    end
  end
  
end

if __FILE__ == $PROGRAM_NAME
	d = THCG::Dictionary.new ARGV[0]
#  puts d.lookup_by_cg("พบ", "s\np/np")
  puts d.lookup_cdgs("พบ")
end