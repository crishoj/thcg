# encoding: UTF-8

require 'polyglot'
require 'treetop'

Treetop.load "lib/thcg"

describe THCGParser do
  
  before(:all) do
    @input = File.open('data/sample.txt').read
    @parser = THCGParser.new
    @result = @parser.parse(@input)
  end
  
  before(:each) do
  end
  
  it "should "
  
  after(:all) do
    puts
    if @result
      p @result
      p @result.sentences
    else
      puts "Reason: #{@parser.failure_reason}"
      puts "Line: #{@parser.failure_line}"
      puts "Column: #{@parser.failure_column}"
    end    
  end
  
end

