
module THCG
  
  class Treebank < Treetop::Runtime::SyntaxNode
    def sentences
      elements
    end
  end
  
  class Sentence < Treetop::Runtime::SyntaxNode
    def tokens
      [tokenized.token.text_value, * tokenized.rest.elements.map { |e| e.token.text_value } ]
    end
    def type
      tree.syntactic_type.type
    end
    def tree
      elements.find { |e| e.kind_of? Bracketed }
    end
  end
  
  class Tokenized < Treetop::Runtime::SyntaxNode
    
  end
  
  class Bracketed < Treetop::Runtime::SyntaxNode
    def terminals
      root.terminals
    end
    def root
      elements.find { |e| e.kind_of? TreeNode }
    end
    def to_dependencies(converter)
      terminals.each_with_index do |t, j|
        t.id = j+1
      end
      heads = converter.cdg2dep(root)
      root_count = 0
      raise "Multiple roots" if root_count > 1
      terminals.collect { |t|
        head_id = converter.heads[t.id] || 0
        deprel  = converter.deprels[t.id] || '_'
        root_count += 1 if head_id == 0        
        fields = [t.id, t.token, '_', t.type, '_', '_', head_id, deprel, '_', '_']
        fields.collect { |f| f.to_s.gsub(/\s/, '_') }.join("\t")
      }.join("\n") + "\n"      
    end
    def to_s
      root.to_s(true)
    end
  end
  
  class Token < Treetop::Runtime::SyntaxNode
    def to_s
      text_value
    end
  end
  
  class TreeNode < Treetop::Runtime::SyntaxNode
    attr_accessor :id, :proxy_for, :cdg, :touched
    def terminals
      if token.nil?
        # Non-terminal
        elements.collect { |e| e.terminals if e.kind_of? TreeNode }.flatten.compact
      else
        # Terminal node
        [self]
      end
    end    
    def root?
      not parent
    end
    def token
      elements.find { |e| e.kind_of? Token }
    end
    def children 
      elements.find_all { |e| e.kind_of? TreeNode }
    end
    def non_terminal_children
      children.find_all { |c| c.token.nil? }
    end
    def terminal_children
      children.find_all { |c| not c.token.nil? }
    end
    def siblings
      return [] unless parent
      parent.elements.find_all { |e| e.kind_of? TreeNode and e != self }
    end
    def left_siblings
      return [] unless parent
      found_self = false
      parent.elements.find_all { |e| 
        if e.kind_of? TreeNode 
          found_self = true if e == self 
          not found_self and e != self 
        end
      }
    end
    def right_siblings
      return [] unless parent
      found_self = false
      parent.elements.find_all { |e| 
        if e.kind_of? TreeNode 
          found_self = true if e == self 
          found_self and e != self 
        end
      }
    end
    def type
      elements.find { |e| e.kind_of? SyntacticType }      
    end
    def type=(new_type)
      idx = elements.index(self.type)
      elements[idx] = new_type
    end
    def to_s(recursive = false, lvl = 0)
      str = "#{' '*lvl}TreeNode(#{interval.first}  [#{token or 'NT'}]\t#{type}\tid:#{id} pid:#{proxied.id})"
      if recursive
        children.each do |c|
          str += "\n"
          str += c.to_s(true, lvl+1)
        end
      end
      str
    end
    def proxy(other)
      self.proxy_for = other.proxied
    end
    def proxied
      proxy_for ? proxy_for.proxied : self
    end
    def assign_heads!(converter)
      return if touched
      puts "[TOUCH] #{self}" if $VERBOSE
      self.touched = true
      non_terminal_children.each { |c| c.assign_heads!(converter) }
      terminal_children.each { |c| c.assign_heads!(converter) }
      puts "[CHECK] #{self}" if $VERBOSE
      if children.count == 2 and children.all? { |c| c.type.canonical == type.canonical }
        puts "[SERIAL] #{children.first} and #{children.last} under #{self}" if $VERBOSE
        converter.register_head(children.last, children.first, :serial)
      end
      type.arguments.reverse.each do |arg|        
        puts "  [ARG] #{arg}" if $VERBOSE
        sibling = arg.from == :right ? right_siblings.first : left_siblings.last
        unless sibling
          puts "[NOSIB]" if $VERBOSE
          break
        end
        sibling.assign_heads!(converter)
        if arg.matches(sibling.type) 
          puts "[MATCH] #{self} \n    and #{sibling}" if $VERBOSE
          case arg.dependency_role
          when :modifier
            converter.register_head(sibling, self)
          when :head
            converter.register_head(self, sibling)
          else
            raise "Unhandled dependency role: #{arg.dependency_role}"
          end
        else
          puts "[NOMAT] #{self} \n    and #{sibling}" if $VERBOSE
          break
        end
        arg.from == :right ? right_siblings.shift : left_siblings.pop
      end
    end
  end
  
  class TerminalNode < TreeNode
  end
  
  class NonterminalNode < TreeNode
  end
  
  class SyntacticType < Treetop::Runtime::SyntaxNode
    def to_s
      text_value
    end
    def has_dependency_directions?
      to_s =~ %r{[<>]}
    end   
    def arguments
      elements.find_all { |e| e.kind_of? Argument }      
    end
    def canonical
      to_s.gsub(/[<>]/, '').gsub(/^\(+/, '').gsub(/\)+$/, '')
    end
    def yields?(other_type)
      if other_type.primitive?
        yielding.canonical == other_type.canonical
      else
        canonical.start_with? other_type.canonical
      end
    end
    def primitive?
      not to_s =~ %r{[/\\]}
    end
  end
  
  class PrimitiveType < SyntacticType
  end
  
  class NestedType < SyntacticType
  end

  class Argument < Treetop::Runtime::SyntaxNode
    def from
      case slash.text_value
      when '/'
        :right
      when '\\' 
        :left
      end
    end
    def dependency_role
      if from == :right 
        if dir.text_value == '>'
          :modifier
        else
          :head
        end
      elsif from == :left
        if dir.text_value == '<'
          :modifier
        else
          :head          
        end
      end
    end
    def to_s
      "#{dependency_role} arg from #{from}: #{type}"
    end
    def matches(node_type)
      type.canonical == node_type.canonical
    end
  end
  
  class Slash < Treetop::Runtime::SyntaxNode
  end
  
  class DependencyDirection < Treetop::Runtime::SyntaxNode
  end

end