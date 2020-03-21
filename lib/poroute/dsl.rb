module Poroute
  # Builds up a definition as methods are called.
  class Dsl
    attr_reader :definition

    def self.define(&block)
      instance = new
      instance.instance_eval(&block)
      instance.definition
    end

    def initialize
      @definition = Definition.new
    end

    def controller(new_controller)
      @definition = @definition.controller(new_controller)
    end

    def middleware(new_middleware)
      @definition = @definition.middleware(new_middleware)
    end

    def scope(prefix = '', &block)
      path_segments = PathSegment.parse(prefix)
      inner = Dsl.define(&block)

      @definition = @definition.mount(path_segments, inner)
    end

    def on(method, path, action)
      path_segments = PathSegment.parse(path)

      @definition = @definition.on(method, path_segments, action)
    end

    %i[get head post put patch delete].each do |http_method|
      define_method(http_method) do |path, action|
        on(http_method.to_s.upcase, path, action)
      end
    end
  end
end
