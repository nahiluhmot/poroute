RSpec.describe Poroute::SegmentTree do
  subject do
    described_class
      .new
      .insert(
        Poroute::PathSegment.parse('/very/very/specific/path'),
        :specific
      )
      .insert(
        Poroute::PathSegment.parse('/pages/:page/item'),
        :pages_visit_item
      )
      .insert(
        Poroute::PathSegment.parse('/prefix/*suffix'),
        :pages_not_found
      )
      .insert(
        Poroute::PathSegment.parse(
          '/crazy/*first_wild_card/pizza/:bind/*second_wild_card'
        ),
        :crazy
      )
  end

  describe '#match' do
    context 'when there is no match' do
      let(:bad_paths) do
        [
          %w[crazy],
          %w[pages item],
          %w[404]
        ]
      end

      it 'returns nil' do
        bad_paths.each do |path|
          expect(subject.match(path))
            .to(eq(nil), "Expected no match for /#{path.join('/')}")
        end
      end
    end

    context 'when there is a match to an exact string' do
      it 'returns the match' do
        expect(subject.match(%w[very very specific path]))
          .to eq(described_class::Match.new(:specific, {}))
      end
    end

    context 'when there is a match with a bound parameter' do
      it 'returns the match' do
        expect(subject.match(%w[pages albert item]))
          .to eq(described_class::Match.new(:pages_visit_item, page: 'albert'))
      end
    end

    context 'when there is a match with a wildcard parameter' do
      it 'returns the match' do
        expect(subject.match(%w[prefix one two three]))
          .to(
            eq(
              described_class::Match.new(
                :pages_not_found,
                suffix: 'one/two/three'
              )
            )
          )
      end
    end

    context 'when there is a match with many parameters' do
      it 'returns the match' do
        expect(subject.match(%w[crazy first pizza tacos second]))
          .to(
            eq(
              described_class::Match.new(
                :crazy,
                first_wild_card: 'first',
                bind: 'tacos',
                second_wild_card: 'second'
              )
            )
          )

        expect(subject.match(%w[crazy wild card one pizza pasta wild card two]))
          .to(
            eq(
              described_class::Match.new(
                :crazy,
                first_wild_card: 'wild/card/one',
                bind: 'pasta',
                second_wild_card: 'wild/card/two'
              )
            )
          )
      end
    end
  end

  describe '#insert' do
    subject { described_class.new }
    let(:path_parts) { %w[pages tom a b c d] }
    let(:path_segments) do
      Poroute::PathSegment.parse('/pages/:slug/*rest')
    end

    it 'inserts the path segments at that value' do
      expect(subject.match(path_parts)).to be_nil

      modified = subject.insert(path_segments, :page)

      expect(modified.match(path_parts))
        .to eq(described_class::Match.new(:page, slug: 'tom', rest: 'a/b/c/d'))
    end
  end

  describe '#add_prefix' do
    subject do
      unprefixed.add_prefix(
        Poroute::PathSegment.parse('/context/:slug')
      )
    end
    let(:unprefixed) do
      described_class
        .new
        .insert(
          Poroute::PathSegment.parse('/:id'),
          :some_page
        )
    end

    let(:prefixed_path) { %w[context frog one] }
    let(:unprefixed_path) { %w[two] }

    it 'adds a prefix to every path' do
      expect(subject.match(prefixed_path))
        .to eq(described_class::Match.new(:some_page, slug: 'frog', id: 'one'))

      expect(subject.match(unprefixed_path))
        .to be_nil

      expect(unprefixed.match(prefixed_path))
        .to be_nil

      expect(unprefixed.match(unprefixed_path))
        .to eq(described_class::Match.new(:some_page, id: 'two'))
    end
  end

  describe '#merge' do
    subject do
      root
        .merge(authors)
        .merge(posts)
    end

    let(:root) do
      described_class
        .new
        .insert(Poroute::PathSegment.parse('/'), :index)
        .insert(Poroute::PathSegment.parse('/*match'), :not_found)
    end
    let(:authors) do
      described_class
        .new
        .insert(Poroute::PathSegment.parse('/'), :list_authors)
        .insert(Poroute::PathSegment.parse('/:name'), :read_author)
        .insert(Poroute::PathSegment.parse('/*'), :authors_not_found)
        .add_prefix(Poroute::PathSegment.parse('/authors'))
    end
    let(:posts) do
      described_class
        .new
        .insert(Poroute::PathSegment.parse('/'), :list_posts)
        .insert(Poroute::PathSegment.parse('/:id'), :read_post)
        .add_prefix(Poroute::PathSegment.parse('/authors/:name/posts'))
    end

    it 'returns a merged tree' do
      expect(subject.match([]))
        .to eq(described_class::Match.new(:index, {}))

      expect(subject.match(%w[404]))
        .to eq(described_class::Match.new(:not_found, match: '404'))

      expect(subject.match(%w[authors]))
        .to eq(described_class::Match.new(:list_authors, {}))

      expect(subject.match(%w[authors rowling]))
        .to eq(described_class::Match.new(:read_author, name: 'rowling'))

      expect(subject.match(%w[authors fitzgerald controversies])).to(
        eq(
          described_class::Match.new(
            :authors_not_found,
            '': 'fitzgerald/controversies'
          )
        )
      )

      expect(subject.match(%w[authors hawthorne posts]))
        .to eq(described_class::Match.new(:list_posts, name: 'hawthorne'))

      expect(subject.match(%w[authors adams posts hitchhiker])).to(
        eq(
          described_class::Match.new(
            :read_post,
            name: 'adams',
            id: 'hitchhiker'
          )
        )
      )

      expect(subject.match(%w[authors tolkien posts the-hobbit comments])).to(
        eq(
          described_class::Match.new(
            :authors_not_found,
            '': 'tolkien/posts/the-hobbit/comments'
          )
        )
      )
    end
  end

  describe '#to_a' do
    let(:expected) do
      [
        [
          [
            Poroute::PathSegment::MatchString.new('very'),
            Poroute::PathSegment::MatchString.new('very'),
            Poroute::PathSegment::MatchString.new('specific'),
            Poroute::PathSegment::MatchString.new('path')
          ],
          :specific
        ],
        [
          [
            Poroute::PathSegment::MatchString.new('pages'),
            Poroute::PathSegment::BindSegment.new('page'),
            Poroute::PathSegment::MatchString.new('item')
          ],
          :pages_visit_item
        ],
        [
          [
            Poroute::PathSegment::MatchString.new('prefix'),
            Poroute::PathSegment::BindWildCard.new('suffix')
          ],
          :pages_not_found
        ],
        [
          [
            Poroute::PathSegment::MatchString.new('crazy'),
            Poroute::PathSegment::BindWildCard.new('first_wild_card'),
            Poroute::PathSegment::MatchString.new('pizza'),
            Poroute::PathSegment::BindSegment.new('bind'),
            Poroute::PathSegment::BindWildCard.new('second_wild_card')
          ],
          :crazy
        ]
      ]
    end

    it 'returns each mapping' do
      expect(subject.to_a).to eq(expected)
    end
  end
end
