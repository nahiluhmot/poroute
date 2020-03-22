require 'poroute/app'
require 'poroute/definition'
require 'poroute/dsl'
require 'poroute/path_segment'
require 'poroute/segment_tree'
require 'poroute/version'

# Routing library that allows users to write controllers using Plain Old Ruby
# Objects.
module Poroute
  module_function

  def define(&block)
    App.new(
      Dsl
        .define(&block)
        .segment_trees_by_method
    )
  end
end
