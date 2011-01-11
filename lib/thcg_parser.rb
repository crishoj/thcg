require 'treetop'

module THCG
  
  class Parser
    base_path = File.expand_path(File.dirname(__FILE__))
    require File.join(base_path, 'node_extensions.rb')
  
    Treetop.load(File.join(base_path, 'thcg.treetop'))
    @@parser = THCGParser.new
  
    def self.parse(data)
      tree = @@parser.parse(data)
      raise Exception, "Parse error: #{@@parser.failure_reason}" if tree.nil?
      self.clean_tree(tree)
      tree
    end  
    
    def self.parse_syntactic_type(data)
      tree = @@parser.parse(data, :root => 'syntactic_type')
      raise Exception, "Parse error: #{@@parser.failure_reason}" if tree.nil?
      self.clean_tree(tree)
      tree
    end
    
    private
    
    def self.clean_tree(root_node)
      unless root_node.elements.nil?
        root_node.elements.each do |node| 
          self.clean_tree(node) 
        end
        root_node.elements.delete_if do |node| 
          if node.class.name == "Treetop::Runtime::SyntaxNode" 
            unless node.terminal? or node.elements.nil?
              node.elements.each do |child_node|
                child_node.parent = root_node
                root_node.elements << child_node
              end
            end
            true
          end
        end
      end
    end
  end
  
end