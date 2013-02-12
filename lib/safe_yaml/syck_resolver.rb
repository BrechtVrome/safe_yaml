module SafeYAML
  class SyckResolver
    QUOTE_STYLES = [:quote1, :quote2]

    def initialize
      @initializers = SafeYAML::OPTIONS[:custom_initializers] || {}
    end

    def resolve_node(node)
      case node.value
      when Hash
        return resolve_map(node)
      when Array
        return resolve_seq(node)
      when String
        return resolve_scalar(node)
      else
        raise "Don't know how to resolve this node: #{node.inspect}"
      end
    end

    def resolve_map(node)
      map = node.value

      tag = node.type_id
      hash = @initializers.include?(tag) ? @initializers[tag].call : {}

      # Take the "<<" key nodes first, as these are meant to approximate a form of inheritance.
      inheritors = map.keys.select { |node| resolve_node(node) == "<<" }
      inheritors.each do |key_node|
        value_node = map[key_node]
        hash.merge!(resolve_node(value_node))
      end

      # All that's left should be normal (non-"<<") nodes.
      normal_keys = map.keys - inheritors
      normal_keys.each do |key_node|
        value_node = map[key_node]
        hash[resolve_node(key_node)] = resolve_node(value_node)
      end

      return hash
    end

    def resolve_seq(node)
      seq = node.value

      tag = node.type_id
      arr = @initializers.include?(tag) ? @initializers[tag].call : []

      seq.inject(arr) { |array, node| array << resolve_node(node) }
    end

    def resolve_scalar(node)
      Transform.to_proper_type(node.value, QUOTE_STYLES.include?(node.instance_variable_get(:@style)), node.type_id)
    end
  end
end
