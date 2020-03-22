RSpec.describe Poroute::App do
  subject do
    root = root_controller.new
    app = app_controller.new
    pasta = pasta_controller.new

    reverse_response_body_middleware = proc do |request, &block|
      response = block.call(request)
      body = response[:body]&.reverse

      response.merge(body: body)
    end

    Poroute.define do
      controller root

      middleware reverse_response_body_middleware

      get '/', :index
      get '/about', :about

      scope '/app/' do
        controller app

        get '/*match', :not_found

        scope '/pasta' do
          controller pasta

          get '/', :index
          post '/', :create
          get '/:slug', :read
          delete '/:slug', :destroy
        end
      end
    end
  end

  let(:root_controller) do
    Class.new do
      def index
        {
          status: 200,
          body: 'index'
        }
      end

      def about
        {
          status: 200,
          body: 'about'
        }
      end
    end
  end

  let(:app_controller) do
    Class.new do
      def not_found(params:)
        {
          status: 404,
          body: "Unable to route #{params[:match]}"
        }
      end
    end
  end

  let(:pasta_controller) do
    Class.new do
      def initialize
        @pastas = {}
      end

      def index
        {
          status: 200,
          headers: {
            'Content-Type' => 'application/json'
          },
          body: @pastas.values.to_json
        }
      end

      def create(body:)
        pasta = JSON.parse(body.read, symbolize_names: true)
        key = pasta[:name].downcase
        @pastas[key] = pasta

        {
          status: 200,
          headers: {
            'Content-Type' => 'application/json'
          },
          body: pasta.to_json
        }
      end

      def read(params:)
        slug = params[:slug]

        if (pasta = @pastas[slug])
          {
            status: 200,
            headers: {
              'Content-Type' => 'application/json'
            },
            body: pasta.to_json
          }
        else
          {
            status: 404,
            body: "Unable to find pasta #{slug}"
          }
        end
      end

      def destroy(params:)
        key = params[:slug]
        @pastas.delete(key)

        { status: 204 }
      end
    end
  end

  describe '#call' do
    context 'when the route is not found' do
      let(:env) do
        {
          'REQUEST_METHOD' => 'GET',
          'REQUEST_PATH' => '/somewhere/else',
          'rack.input' => StringIO.new,
          'QUERY_STRING' => ''
        }
      end
      let(:expected) do
        [404, {}, ['Unable to route request']]
      end

      it 'returns the default response' do
        expect(subject.call(env))
          .to eq(expected)
      end
    end

    context 'when the request matches an exact path' do
      let(:env) do
        {
          'REQUEST_METHOD' => 'GET',
          'REQUEST_PATH' => '/about',
          'rack.input' => StringIO.new,
          'QUERY_STRING' => ''
        }
      end
      let(:expected) do
        [200, {}, ['tuoba']]
      end

      it 'returns the default response' do
        expect(subject.call(env))
          .to eq(expected)
      end
    end

    context 'when the request matches a wild card' do
      let(:env) do
        {
          'REQUEST_METHOD' => 'GET',
          'REQUEST_PATH' => '/app/nested/miss',
          'rack.input' => StringIO.new,
          'QUERY_STRING' => ''
        }
      end
      let(:expected) do
        [404, {}, ['Unable to route nested/miss']]
      end

      it 'returns the default response' do
        expect(subject.call(env))
          .to eq(expected)
      end
    end

    context 'when the request matches a bind' do
      let(:index_env) do
        {
          'REQUEST_METHOD' => 'GET',
          'REQUEST_PATH' => '/app/pasta',
          'rack.input' => StringIO.new,
          'QUERY_STRING' => ''
        }
      end
      let(:create_env) do
        {
          'REQUEST_METHOD' => 'POST',
          'REQUEST_PATH' => '/app/pasta',
          'rack.input' =>
            StringIO.new({ name: 'gnocchi', rating: '10/10' }.to_json),
          'QUERY_STRING' => ''
        }
      end
      let(:read_env) do
        {
          'REQUEST_METHOD' => 'GET',
          'REQUEST_PATH' => '/app/pasta/gnocchi',
          'rack.input' => StringIO.new,
          'QUERY_STRING' => ''
        }
      end
      let(:delete_env) do
        {
          'REQUEST_METHOD' => 'DELETE',
          'REQUEST_PATH' => '/app/pasta/gnocchi',
          'rack.input' => StringIO.new,
          'QUERY_STRING' => ''
        }
      end

      it 'returns the default response' do
        expect(subject.call(index_env))
          .to eq([200, { 'Content-Type' => 'application/json' }, ['[]']])

        expect(subject.call(read_env))
          .to eq([404, {}, ['Unable to find pasta gnocchi']])

        expect(subject.call(create_env)).to(
          eq(
            [
              200,
              { 'Content-Type' => 'application/json' },
              ['{"name":"gnocchi","rating":"10/10"}']
            ]
          )
        )

        expect(subject.call(index_env)).to(
          eq(
            [
              200,
              { 'Content-Type' => 'application/json' },
              ['[{"name":"gnocchi","rating":"10/10"}]']
            ]
          )
        )

        expect(subject.call(read_env)).to(
          eq(
            [
              200,
              { 'Content-Type' => 'application/json' },
              ['{"name":"gnocchi","rating":"10/10"}']
            ]
          )
        )

        expect(subject.call(delete_env))
          .to eq([204, {}, []])

        expect(subject.call(index_env))
          .to eq([200, { 'Content-Type' => 'application/json' }, ['[]']])

        expect(subject.call(read_env))
          .to eq([404, {}, ['Unable to find pasta gnocchi']])
      end
    end
  end

  describe '#routes' do
    let(:routes) { subject.routes }
    let(:expected) do
      [
        %w[GET /],
        %w[GET /about],
        %w[GET /app/*match],
        %w[GET /app/pasta],
        %w[POST /app/pasta],
        %w[GET /app/pasta/:slug],
        %w[DELETE /app/pasta/:slug]
      ]
    end

    it 'returns the routes' do
      expect(subject.routes).to eq(routes)
    end
  end
end
