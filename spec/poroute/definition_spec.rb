RSpec.describe Poroute::Definition do
  subject do
    described_class
      .new
      .controller(root_controller.new)
      .on('GET', Poroute::PathSegment.parse('/'), :index)
      .on('GET', Poroute::PathSegment.parse('/*route'), :not_found)
      .mount(
        Poroute::PathSegment.parse('/posts/'),
        described_class.new
          .controller(posts_controller.new)
          .middleware(json_middleware.new)
          .on('GET', Poroute::PathSegment.parse('/'), :index)
          .on('POST', Poroute::PathSegment.parse('/'), :create)
          .on('GET', Poroute::PathSegment.parse('/:id'), :read)
      )
  end
  let(:segment_trees_by_method) do
    subject.segment_trees_by_method
  end

  let(:root_controller) do
    Class.new do
      def index
        {
          status: 200,
          headers: {},
          body: 'Listing index'
        }
      end

      def not_found(params:)
        route = params[:route]

        {
          status: 404,
          headers: {},
          body: "No route matches /#{route}"
        }
      end
    end
  end

  let(:json_middleware) do
    Class.new do
      def call(request)
        response =
          if request.dig(:headers, 'Content-Type') == 'application/json'
            body = request[:body]
            if !body.nil? && !body.empty?
              parsed = JSON.parse(body, symbolize_names: true)

              yield request.merge(body: parsed)
            else
              yield request
            end
          else
            yield request
          end

        if response[:body].respond_to?(:to_json)
          headers = (response[:headers] || {})
            .merge('Content-Type' => 'application/json')

          response.merge(
            body: response[:body].to_json,
            headers: headers
          )
        else
          response
        end
      end
    end
  end

  let(:posts_controller) do
    Class.new do
      def initialize
        @posts_by_id = {}
      end

      def index
        {
          status: 200,
          body: @posts_by_id.values
        }
      end

      def create(body:)
        id = SecureRandom.uuid
        post = body.merge(id: id)
        @posts_by_id[id] = post

        {
          status: 201,
          body: post
        }
      end

      def read(params:)
        id = params[:id]

        if (post = @posts_by_id[id])
          {
            status: 200,
            body: post
          }
        else
          {
            status: 404,
            body: { error: "No post with ID: #{id}" }
          }
        end
      end
    end
  end

  def dispatch_route(method, path, headers: {}, body: nil)
    parts = path.split('/').reject(&:empty?)
    match = segment_trees_by_method[method].match(parts)

    match.value.call(
      method: method,
      path: path,
      headers: headers,
      body: body,
      params: match.params
    )
  end

  it 'builds up a segment tree' do
    expect(dispatch_route('GET', '/'))
      .to eq(status: 200, headers: {}, body: 'Listing index')

    expect(dispatch_route('GET', '/some/nonsense'))
      .to eq(status: 404, headers: {}, body: 'No route matches /some/nonsense')

    expect(dispatch_route('GET', '/posts/')).to(
      eq(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: '[]'
      )
    )

    create_response = dispatch_route(
      'POST',
      '/posts/',
      headers: { 'Content-Type' => 'application/json' },
      body: { title: '10 things I found in my room', text: 'blah' }.to_json
    )
    expect(create_response[:status]).to eq(201)
    expect(create_response[:headers])
      .to eq('Content-Type' => 'application/json')
    parsed = JSON.parse(create_response[:body], symbolize_names: true)
    expect(parsed).to(
      match(
        title: '10 things I found in my room',
        text: 'blah',
        id: instance_of(String)
      )
    )
    id = parsed[:id]

    expect(dispatch_route('GET', "/posts/#{id}")).to(
      eq(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: create_response[:body]
      )
    )
  end
end
