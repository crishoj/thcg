# encoding: UTF-8

require 'polyglot'
require 'treetop'

Treetop.load "lib/thcg"

describe THCGParser do
  
  before(:all) do 
    @input = File.open('data/Correct_Tree_V2.5.txt').read
  end
  
  before(:each) do
    @parser = THCGParser.new    
  end
  
  after(:each) do
    unless @result
      puts
      puts "Reason: #{@parser.failure_reason}"
      puts "Line: #{@parser.failure_line}"
      puts "Column: #{@parser.failure_column}"
    end    
  end

  it "should be parse a token" do
    @result = @parser.parse('นักวิชาการ', :root => 'token')
    @result.should be_true
  end

  it "should be parse a tokenized sentence" do
    @result = @parser.parse('﻿นักวิชาการ|ตรวจ|พบ|ไวรัส|โคโรน่า|ใน|ชะมด|', :root => 'tokenized_sentence').should be_true
  end

  it "should parse a simple type" do
    @result = @parser.parse('np', :root => 'syntactic_type')
    @result.should be_true
  end
  
  it "should parse a complex type with forward slash" do
    @result = @parser.parse('np/np', :root => 'syntactic_type')
    @result.should be_true
  end
  
  it "should parse a complex type with backslash" do
    @result = @parser.parse('np\np', :root => 'syntactic_type')
    @result.should be_true
  end
  
  it "should parse a more complex type" do
    @result = @parser.parse('s\np/np', :root => 'syntactic_type')
    @result.should be_true
  end
  
  it "should parse a nested complex type" do
    @result = @parser.parse('(s\np)/np', :root => 'syntactic_type')
    @result.should be_true
  end
  
  it "should parse a leaf node" do
    @result = @parser.parse('s\np/np[ดับ]', :root => 'node')
    @result.should be_true
  end
  
  it "should parse a tree" do
    @result = @parser.parse('s(np[เธอ] s\np(s\np/np[ดับ] np[เทียน]))', :root => 'node')
    @result.should be_true
  end
  
  it "should parse another tree" do
    @result = @parser.parse('s(np[นักวิชาการ] s\np(s\np[ตรวจ] s\np(s\np(s\np/np[พบ] np(np[ไวรัส] np[โคโรน่า])) (s\np)\(s\np)(((s\np)\(s\np))/np[ใน] np[ชะมด]))))', :root => 'node')
    @result.should be_true
  end
  
  it "should parse a typed tree" do
    @result = @parser.parse('	s\np	s\np((s\np)/(s\np)[ต้อง] s\np(s\np[ศึกษา] (s\np)\(s\np)[ต่อไป]))', :root => 'typed_tree')
    @result.should be_true
  end

  it "should parse another typed tree" do
    @result = @parser.parse('  s s(np[นักวิชาการ] s\np(s\np[ตรวจ] s\np(s\np(s\np/np[พบ] np(np[ไวรัส] np[โคโรน่า])) (s\np)\(s\np)(((s\np)\(s\np))/np[ใน] np[ชะมด]))))', :root => 'typed_tree')
    @result.should be_true
  end

  it "should parse a treebank" do
    treebank = 'นักวิชาการ|ตรวจ|พบ|ไวรัส|โคโรน่า|ใน|ชะมด|
	s s(np[นักวิชาการ] s\np(s\np[ตรวจ] s\np(s\np(s\np/np[พบ] np(np[ไวรัส] np[โคโรน่า])) (s\np)\(s\np)(((s\np)\(s\np))/np[ใน] np[ชะมด]))))
ต้อง|ศึกษา|ต่อไป|
	s\np	s\np((s\np)/(s\np)[ต้อง] s\np(s\np[ศึกษา] (s\np)\(s\np)[ต่อไป]))
ระวัง|อย่า|ให้|รับประทาน|อาหาร|ดิบ| |ๆ    
	s\np	s\np(s\np[ระวัง] s\np((s\np)/(s\np)[อย่า] s\np(s\np[ให้] s\np(s\np/np[รับประทาน] np(np[อาหาร] np\np(np\np[ดิบ] (np\np)\(np\np)[ๆ]))))))
'
    @result = @parser.parse(treebank)
    @result.should be_true
  end

  it "should parse the whole example file" do
    @result = @parser.parse(@input)
    @result.should be_true    
  end
  
end

