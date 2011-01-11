require 'polyglot'
require 'treetop' 
Treetop.load "lib/thcg" 
r = THCGParser.new.parse(File.open('data/sample.txt').read)
s = r.sentences.first
