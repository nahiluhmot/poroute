module Poroute
  # Parses path patterns into segments.
  module PathSegment
    # Psuedo sum type for path segments.
    Segment = Struct.new(:string)
    MatchString = Class.new(Segment)
    BindSegment = Class.new(Segment)
    BindWildCard = Class.new(Segment)

    BIND_SEGMENT_PREFIX = ':'.freeze
    BIND_WILD_CARD_PREFIX = '*'.freeze
    PATH_SEPARATOR = '/'.freeze

    module_function

    def parse(pattern)
      pattern
        .split(PATH_SEPARATOR)
        .reject(&:empty?)
        .map(&method(:parse_segment))
    end

    def parse_segment(segment)
      if segment.start_with?(BIND_SEGMENT_PREFIX)
        BindSegment.new(segment[1..-1])
      elsif segment.start_with?(BIND_WILD_CARD_PREFIX)
        BindWildCard.new(segment[1..-1])
      else
        MatchString.new(segment)
      end
    end
  end
end
