conllfile  = ARGV[0]
featfile   = ARGV[1] 
basename   = File.basename(conllfile, '.conll')
trainfile  = "#{basename}.train.conll"
testfile   = "#{basename}.test.conll"
systemfile = "#{basename}.system.conll"

sents = File.read(conllfile).split("\n\n")
File.open(trainfile, 'w') { |f| f << sents[0..1318].join("\n\n") } 
File.open(testfile, 'w')  { |f| f << sents[1319..-1].join("\n\n") } 

feat_opt = "-F #{featfile}" if featfile
puts `java -jar ~/Tools/malt-1.4.1/malt.jar -c #{basename} -i #{trainfile} -m learn #{feat_opt}`
puts `java -jar ~/Tools/malt-1.4.1/malt.jar -c #{basename} -i #{testfile} -o #{systemfile} -m parse`
puts `~/Projects/dep_feat/bin/eval07.pl -q -g #{testfile} -s #{systemfile}`
