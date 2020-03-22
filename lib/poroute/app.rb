module Poroute
  # Rack application which dispatches requests based on SegmentTrees.
  class App
    REQUEST_METHOD = 'REQUEST_METHOD'.freeze
    REQUEST_PATH = 'REQUEST_PATH'.freeze
    REQUEST_BODY = 'rack.input'.freeze
    HEADER_PREFIX = 'HTTP_'.freeze
    QUERY_STRING = 'QUERY_STRING'.freeze

    NOT_FOUND_RESPONSE = [404, {}, ['Unable to route request']].freeze

    def initialize(segment_trees_by_method)
      @segment_trees_by_method = segment_trees_by_method
    end

    def call(env)
      if (response = try_route_request(env))
        to_rack_response(response)
      else
        NOT_FOUND_RESPONSE
      end
    end

    def routes
      @segment_trees_by_method
        .flat_map { |method, tree| segment_tree_routes(method, tree) }
        .sort_by { |hash| hash[:path] }
    end

    private

    def segment_tree_routes(method, segment_tree)
      segment_tree.map do |prefix, (controller, action, _)|
        {
          method: method,
          path: PathSegment.serialize(prefix),
          controller: controller,
          action: action
        }
      end
    end

    def try_route_request(env)
      method = env[REQUEST_METHOD]

      if (segment_tree = @segment_trees_by_method[method])
        path = env[REQUEST_PATH]
        path_parts = path
          .split(PathSegment::PATH_SEPARATOR)
          .reject(&:empty?)

        if (match = segment_tree.match(path_parts))
          params = match.params
          _, _, route_handler = match.value

          headers = env
            .select { |key, _| key.start_with?(HEADER_PREFIX) }
            .transform_keys { |key| key.delete_prefix(HEADER_PREFIX) }

          query = env[QUERY_STRING]
          body = env[REQUEST_BODY]

          route_handler.call(
            method: method,
            path: path,
            query: query,
            headers: headers,
            body: body,
            params: params,
            env: env
          )
        end
      end
    end

    def to_rack_response(response)
      status, headers, body =
        response.values_at(:status, :headers, :body)

      [
        status || 200,
        headers || {},
        to_rack_body(body)
      ]
    end

    def to_rack_body(body)
      case body
      when String
        [body]
      when Enumerable
        body
      when nil
        []
      else
        [body]
      end
    end
  end
end
