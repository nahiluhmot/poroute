module Poroute
  # Tree which holds an app's routes before they're compiled into SegmentTrees.
  class Definition
    def initialize(controller: nil, routes: [], middleware: [], mounts: [])
      @controller = controller
      @routes = routes
      @middleware = middleware
      @mounts = mounts
    end

    def controller(new_controller)
      instance =
        if new_controller.is_a?(Class)
          new_controller.new
        else
          new_controller
        end

      with(controller: instance)
    end

    def on(method, path_segments, action)
      new_route = [method, path_segments, action]

      with(routes: [*@routes, new_route])
    end

    def middleware(new_middleware)
      with(middleware: [*@middleware, new_middleware])
    end

    def mount(prefix, definition)
      new_mount = [prefix, definition]

      with(mounts: [*@mounts, new_mount])
    end

    def segment_trees_by_method
      mounts_segment_trees_by_method
        .reduce(routes_segment_trees_by_method) do |acc, ele|
          acc.merge(ele) do |_, left_tree, right_tree|
            left_tree.merge(right_tree)
          end
        end
    end

    protected

    def prepend_middleware(new_middleware)
      with(middleware: new_middleware + @middleware)
    end

    def with_controller_unless_present(new_controller)
      if @controller
        self
      else
        controller(new_controller)
      end
    end

    private

    def routes_segment_trees_by_method
      @routes
        .group_by { |(method, _, _)| method }
        .transform_values do |routes|
          routes.reduce(SegmentTree.new) do |tree, (_, path_segments, action)|
            route_handler = build_route_handler(action)

            tree.insert(path_segments, [@controller, action, route_handler])
          end
        end
    end

    def mounts_segment_trees_by_method
      @mounts.map do |(prefix, definition)|
        definition
          .with_controller_unless_present(@controller)
          .prepend_middleware(@middleware)
          .segment_trees_by_method
          .transform_values { |tree| tree.add_prefix(prefix) }
      end
    end

    def build_route_handler(action)
      method = @controller.method(action)

      kwarg_names = method
        .parameters
        .select { |(type, _)| (type == :key) || (type == :keyreq) }
        .map { |(_, name)| name }

      base = proc do |hash|
        kwargs = hash.slice(*kwarg_names)

        method.call(**kwargs)
      end

      @middleware
        .reverse_each
        .reduce(base) { |acc, ele| proc { |hash| ele.call(hash, &acc) } }
    end

    def with(hash)
      default = {
        controller: @controller,
        routes: @routes,
        middleware: @middleware,
        mounts: @mounts
      }
      updated = default.merge(hash)

      self.class.new(**updated)
    end
  end
end
