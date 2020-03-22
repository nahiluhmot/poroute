RSpec.describe Poroute::Dsl do
  describe '.define' do
    subject do
      users = users_controller.new

      marketing_middleware = proc do |request, &block|
        response = block.call(request)
        response.merge(
          headers: response[:headers].merge('X-Router' => 'Poroute')
        )
      end

      described_class.define do
        scope '/users/' do
          controller users

          middleware marketing_middleware

          get '/:id', :read
        end
      end
    end

    let(:users_controller) do
      Class.new do
        def read(params:)
          {
            status: 200,
            headers: {
              'Content-Type' => 'application/json'
            },
            body: { id: params[:id] }.to_json
          }
        end
      end
    end

    it 'builds a definition' do
      match = subject
        .segment_trees_by_method['GET']
        .match(%w[users first])

      _, _, handler = match.value
      response = handler.call(params: match.params)

      expect(response).to(
        eq(
          status: 200,
          headers: {
            'Content-Type' => 'application/json',
            'X-Router' => 'Poroute'
          },
          body: '{"id":"first"}'
        )
      )
    end
  end
end
