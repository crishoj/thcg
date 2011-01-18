# coding: UTF-8
$:.unshift 'lib'
require 'thcg'
require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new 'thcg2dep', THCG::VERSION do |gem|
  gem.url = "http://github.com/crishoj/thcg2dep"
  gem.summary = "Derive (minimally labeled) dependency trees from the Thai CG Bank"
  gem.email = "crjensen@hum.ku.dk"
  gem.author = "Christian Rishøj"
  gem.runtime_dependencies << 'commander'
  gem.development_dependencies << 'rspec'
  gem.ignore_pattern = ['nbproject/**/*', 'data/**/*']
end
