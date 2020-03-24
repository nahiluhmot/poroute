# Poroute

Poroute is a Rack router for defining controllers using Plain Old Ruby Objects (POROs).

## Features

* Controllers are defined using POROs
* Actions (route handlers) accept `Hash`es and return `Hash`es
* Routes are defined using an unambiguous DSL
* Middlewares use continuation passing style

## Usage

Define your controller:

```ruby
# app/controllers/posts.rb

module Controllers
  class Posts
    # For this example, we're using an in-memory Hash to store state.
    # In a real application, we'd probably be reaching out to a database.
    def initialize
      @posts = {}
      @next_id = 0
    end

    def create(request)
      post = request.dig(:body, :post)
      @posts[@next_id] = post
      @next_id += 1

      {
        status: 201,
        headers: { 'X-Total-Posts' => @posts.length },
        body: post
      }
    end

    def read(params:)
      id = params[:id].to_i

      if (post = @posts[id])
        {
          status: 200,
          body: post
        }
      else
        {
          status: 404,
          body: { error: "Unable to find post with ID #{id}" }
        }
      end
    end
  end
end
```

Define your routes:

```ruby
# app/routes.rb

require 'poroute'
require 'controllers/posts'

Routes = Poroute.define do
  scope '/api/posts' do
    controller Controllers::Posts

    middleware Poroute::Middleware::Json

    post '/', :create
    get '/:id', :read
  end
end
```


Start your application:

```ruby
# config.ru

$LOAD_PATH << File.expand_path('app', __dir__)
require 'routes'

run Routes
```

## Controllers & Actions

Controllers are standard Ruby objects -- no need to subclass, `include`, or `extend` anything.
Unlike Rails and Sinatra, where controllers are instantiated once per request, Poroute controllers are instantiated once and for all, so be careful with memoization.
Actions are methods defined on a controller which accept an HTTP request and return an HTTP response, both represented by `Hash`es.

In the above example, the `Controllers::Posts#create` action accepts the request as a `Hash`, appends the post to the data store, and returns a 201.
Many actions, such as `Controllers::Posts#read`, only need a subset of the data from the request.

To make things easier, Poroute allows users to define actions using keyword arguments to select the desired request keys.
The following keyword arguments can be required by actions:

* `method` - HTTP method
* `path` - HTTP path (before normalization)
* `query` - query parameters (as a `String`)
* `headers` - `Hash` containing the HTTP headers (without the `HTTP_` prefix added by Rack)
* `body` - request body (as an `IO`-like object)
* `params` - `Hash` of param parsed from the path description
* `env` - Rack env

Actions must return a `Hash` which includes a `:status`, and optional `:headers` and `:body` keys.

## Routes

The routing DSL maps descriptions of HTTP requests to controllers, actions, and middlewares.
Unlike the Rails routing DSL, Poroute forces users to specify which controller will be hit for each scope.
Forcing the specification is intended to remove ambiguity from the routes:action mappings.

Controllers are specified with the `controller` DSL method, which can either accept a controller class, or an instance of a controller class.
If a class is specified, it must have a 0 argument initializer.

Routes may be declared using `head`, `get`, `post`, `put`, `patch`, and `delete`.
Each of these methods accepts two arguments: a path pattern and a `Symbol` which corresponds to one of the controller's actions.

Path patterns can match HTTP paths by exact `String` literal, such as by specifying `get '/about', :about`.
Path segments (i.e. the parts of the path between `/`s) can also be used to match any `String`, and bind that value to a variable.
For instance, a match against `/users/:user_id/posts/:posts_id` with the path `/users/tom/posts/poros` would bind `{ user_id: 'tom', post_id: 'poros' }`.

To (greedily) match zero or more path segments, use `*` instead of `:`.
A match against `/start/*middle/finish` with the path `/start/a/b/c/d/e/finish` would bind `{ middle: 'a/b/c/d/e' }`.
Generally, this is used to define 404 handlers.

A set of route:action mappings may be mounted under a `scope`.
Like the route mapping methods, `scope` accepts a path pattern, which follows the same rules described above.
Each scope inherits the middleware from its parent scope.
As of right now, only one controller may be used per scope.
If you need to mount multiple controllers under a common prefix, you can define multiple scopes with that prefix.

## Middleware

Poroute middleware is defined in [Continuation-passing style](https://en.wikipedia.org/wiki/Continuation-passing_style).
Essentially, each layer of middleware is a function that accepts a request.
To pass the request, or a modified version of it, onto the next middleware in the stack, `yield` it.
Doing so will return the result from that layer of the middleware stack.
This result can then either be returned or modified.

Here's an example:

```ruby
class MarketingMiddleware
  def call(request)
    response = yield request

    response.merge(
      headers: (response[:headers] || {}).merge(
        'X-Routed-With' => "Poroute v#{Poroute::VERSION}"
      )
    )
  end
end
```

When mounted, `MarketingMiddleware` will add an `X-Routed-With` header to every HTTP response.

## Motivation

Poroute is [far](https://hanamirb.org/) [from](https://github.com/ruby-grape/grape) [the](http://sinatrarb.com/) [first](https://rubyonrails.org/) routing library for Ruby/Rack.
Its routing DSL even heavily resembles that of Rails (though with the caveat that controllers must be specified, _which is a feature_).
So, what's it add?

Great question, my fine straw man.
However, the main feature of Poroute is what it _doesn't_ add.
Instead of using a DSL to define controller actions, they're just normal methods on normal classes.

Want to see how an action would behave with different arguments?
Call it!

Want to delegate a request to a different action?
Call it!

Do you need a recursive route handler?
Call i--wait, no, probably don't do that.

Joking aside, methods are easier to understand, easier to test, and grant the developer at least as much freedom as a DSL.

This is also why actions are simple methods which accept requests and return responses.
There's no ambiguity about how to acheive what you want ("How do I set the response status? Do I return it? Is there some `status` DSL method?")

In short, Poroute is designed to be intuitive and unobtrusive in a way that other routing libraries are not.

## Installation

Add this line to your application"s Gemfile:

```ruby
gem 'poroute'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install poroute
```
## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `bundle exec rake` to run the tests and code quality metrics.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nahiluhmot/poroute.
This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/nahiluhmot/poroute/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Poroute project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/nahiluhmot/poroute/blob/master/CODE_OF_CONDUCT.md).
