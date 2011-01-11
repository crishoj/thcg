
sents = File.read('data/Correct_Tree_V2.5_with_dict.stripped.conll').split("\n\n").shuffle
train = sents[0..1318]
test = sents[1319..-1]
File.open('data/train.conll', 'w') { |f| f << train.join("\n\n") } 
File.open('data/test.conll', 'w') { |f| f << test.join("\n\n") } 

#java -jar ~/Tools/malt-1.4.1/malt.jar -c malt_test -i data/train.conll -m learn
#java -jar ~/Tools/malt-1.4.1/malt.jar -c malt_test -i data/test.conll -o malt_test.out.conll -m parse
#../dep_feat/bin/eval07.pl -q -g data/test.conll -s malt_test.out.conll


