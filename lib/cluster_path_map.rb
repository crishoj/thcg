
require 'conll'

class ClusterPathMap
  def initialize(filename)
    @map = {}
    File.foreach(filename) do |line|
      cluster, form, tmp = line.strip.split("\t")
      @map[form] = cluster
    end
  end
  def lookup(form)
    @map[form] or '_'
  end
end

if __FILE__ == $PROGRAM_NAME
	conllfile, pathsfile1, pathsfile2 = ARGV
  map1 = ClusterPathMap.new(pathsfile1)
  map2 = ClusterPathMap.new(pathsfile2) if pathsfile2
  corpus = Conll::Corpus.parse(conllfile)
  corpus.sentences.each do |s|
    s.tokens.each do |t|
      t.pos = map1.lookup(t.form)
      t.cpos = map2.lookup(t.form) if map2
    end
  end
  puts corpus
end
