module Poroute
  # Stores values keyed by many PathSegments. Lookups are done with path parts
  # (i.e. the path of HTTP requests, split on "/").
  class SegmentTree
    include Enumerable

    Node = Struct.new(:value, :exact_matches, :binds, :wild_cards)
    Match = Struct.new(:value, :params)

    def initialize(root = Node.new(nil, {}, {}, {}))
      @root = root
    end

    def match(path_parts)
      match_node(path_parts, {}, @root)
    end

    def insert(path_segments, value)
      inner_node = Node.new(value, {}, {}, {})
      tree_update = nested_node(path_segments, inner_node)
      new_root = merge_nodes(@root, tree_update)

      SegmentTree.new(new_root)
    end

    def add_prefix(path_segments)
      new_root = nested_node(path_segments, @root)

      SegmentTree.new(new_root)
    end

    def merge(other)
      new_root = merge_nodes(@root, other.root)

      SegmentTree.new(new_root)
    end

    def each(&block)
      return enum_for(:each) unless block

      each_value_with_prefix(@root, [], &block)

      self
    end

    protected

    attr_reader :root

    private

    def each_value_with_prefix(node, prefix, &block)
      block.call(prefix, node.value) if node.value

      each_child_value_with_prefix(
        node.exact_matches,
        prefix,
        PathSegment::MatchString,
        &block
      )

      each_child_value_with_prefix(
        node.binds,
        prefix,
        PathSegment::BindSegment,
        &block
      )

      each_child_value_with_prefix(
        node.wild_cards,
        prefix,
        PathSegment::BindWildCard,
        &block
      )
    end

    def each_child_value_with_prefix(children, prefix, klass, &block)
      children.each do |key, child_node|
        new_prefix = [*prefix, klass.new(key)]

        each_value_with_prefix(child_node, new_prefix, &block)
      end
    end

    def match_node(path_parts, params, node)
      if path_parts.empty?
        if node.value
          Match.new(node.value, params)
        else
          match_wild_card(path_parts, params, node)
        end
      else
        match_exact(path_parts, params, node) ||
          match_bind(path_parts, params, node) ||
          match_wild_card(path_parts, params, node)
      end
    end

    def match_exact((path_part, *rest), params, node)
      if (match_node = node.exact_matches[path_part])
        match_node(rest, params, match_node)
      end
    end

    def match_bind((path_part, *rest), params, node)
      find_first(node.binds) do |var_name, bind_node|
        new_params = params.merge(var_name.to_sym => path_part)

        match_node(rest, new_params, bind_node)
      end
    end

    def match_wild_card(path_parts, params, node)
      lengths = (0..path_parts.length).reverse_each

      find_first(node.wild_cards) do |var_name, wild_card_node|
        find_first(lengths) do |length|
          new_parts = path_parts.drop(length)

          value = path_parts.take(length).join(PathSegment::PATH_SEPARATOR)
          new_params = params.merge(var_name.to_sym => value)

          match_node(
            new_parts,
            new_params,
            wild_card_node
          )
        end
      end
    end

    def find_first(enumerable)
      enumerable.each do |element|
        if (result = yield element)
          return result
        end
      end

      nil
    end

    def nested_node(path_segments, inner)
      path_segments.reverse_each.reduce(inner) do |node, segment|
        key = segment.string
        new_hash = { key => node }

        case segment
        when PathSegment::MatchString
          Node.new(nil, new_hash, {}, {})
        when PathSegment::BindSegment
          Node.new(nil, {}, new_hash, {})
        when PathSegment::BindWildCard
          Node.new(nil, {}, {}, new_hash)
        end
      end
    end

    def merge_nodes(left, right)
      Node.new(
        right.value || left.value,
        merge_node_hashes(left.exact_matches, right.exact_matches),
        merge_node_hashes(left.binds, right.binds),
        merge_node_hashes(left.wild_cards, right.wild_cards)
      )
    end

    def merge_node_hashes(left, right)
      left.merge(right) do |_key, left_node, right_node|
        merge_nodes(left_node, right_node)
      end
    end
  end
end
