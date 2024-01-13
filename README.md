# BRB

BRB is backslashed Ruby, a template system that lets you be-right-back to ERB.

BRB aims to be a simpler syntax, but still a superset of ERB, that's aware of the context we're in: HTML.

We're swapping the usual <% %>, <%= %>, and <%# %> for \, \= and \# — these are also self-terminating expressions.

So this ERB:

```erb
<%# Some comment %>
<% posts.each do |post| %>
  <h1><%= post.title %></h1>
<% end %>
```

Can be this in BRB:

```ruby
\# Some comment
\posts.each do |post|
  <h1>\= post.title</h1>
\end
```

Note: you can also do `\ posts.each` and `\ end`, it just feels a little nicer to nestle once you've written a bit.

We recognize lines starting with \ or \# as pure Ruby ones so we terminate on \n and convert to `<% %>`.
Same goes for \= except we also terminate on `</`, and then convert to `<%= %>`.

Use the sigil `\p(post.title)` for multiple statements on the same line or to otherwise disambiguate statements.

### Preprocessing sigils

BRB also includes preprocessing sigils. Sigils make common HTML output actions easier to write.

At template compile time the sigils are replaced with the equivalent ERB:

```
\p(post.options) -> <%= post.options %>
\id(post) -> id="<%= dom_id(post) %>"
\class(active: post.active?) -> class="<%= class_names(active: post.active?) %>"
\attributes(post.options) -> <%= tag.attributes(post.options) %>
\data(controller: :list) -> <%= tag.data(controller: :list) %>
\aria(describedby: :post_1) -> <%= tag.aria(describedby: :post_1) %>
\lorem -> Lorem ipsum dolor sit amet…
```

There's also a `t` sigil, but it's got a little extra too:

```
\t.message -> <%= t ".message" %>
\t(fully.qualified.message) -> <%= t "fully.qualified.message" %>
\t(Some bare words) -> <%= t "Some bare words" %> # Assumes we're using a gettext I18n backend, coming later!
```

### Embed ViewComponents with their templates

I haven't figured this out, but I'm trying to explore a way to embed a component
in its template. Using `~~~` to separate the frontmatter, a pure Ruby chunk where the component code goes, from the rest of the template file like this:

```ruby
# app/views/message_component.html.erb
class MessageComponent < ViewComponent::Base
  def initialize(name:) = @name = name
end
~~~

<h1>\= @name</h1>
```

I'm exploring a backmatter version where you can write pure Ruby below the template code:

```ruby
<h1>\= name</h1>

~~~
# Useful with Nice Partials
partial.helpers do
  # …
end
```

I'm still trying to figure out what Zeitwerk overrides are needed to make these work.


## Installation

Bundle BRB and call `BRB.enable` during your Rails app boot to use it.

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kaspth/brb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/kaspth/brb/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Brb project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/kaspth/brb/blob/main/CODE_OF_CONDUCT.md).
