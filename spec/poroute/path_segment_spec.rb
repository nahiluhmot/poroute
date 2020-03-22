RSpec.describe Poroute::PathSegment do
  describe '#parse' do
    context 'without any variables' do
      let(:expected_segments_by_string) do
        {
          '' => [],
          '/' => [],
          '////' => [],
          '/api///users' => [
            described_class::MatchString.new('api'),
            described_class::MatchString.new('users')
          ],
          'posts' => [
            described_class::MatchString.new('posts')
          ],
          '/really/long/////uri/okay/its/not/that/long/' => [
            described_class::MatchString.new('really'),
            described_class::MatchString.new('long'),
            described_class::MatchString.new('uri'),
            described_class::MatchString.new('okay'),
            described_class::MatchString.new('its'),
            described_class::MatchString.new('not'),
            described_class::MatchString.new('that'),
            described_class::MatchString.new('long')
          ]
        }
      end

      it 'returns many MatchStrings' do
        expected_segments_by_string.each do |string, expected|
          expect(subject.parse(string)).to eq(expected)
        end
      end
    end

    context 'with only binds' do
      let(:expected_segments_by_string) do
        {
          '/:api/:users' => [
            described_class::BindSegment.new('api'),
            described_class::BindSegment.new('users')
          ],
          ':posts' => [
            described_class::BindSegment.new('posts')
          ],
          '/:really/:long/:uri/:okay/:its/:not/:that/:long/:' => [
            described_class::BindSegment.new('really'),
            described_class::BindSegment.new('long'),
            described_class::BindSegment.new('uri'),
            described_class::BindSegment.new('okay'),
            described_class::BindSegment.new('its'),
            described_class::BindSegment.new('not'),
            described_class::BindSegment.new('that'),
            described_class::BindSegment.new('long'),
            described_class::BindSegment.new('')
          ]
        }
      end

      it 'returns many BindSegments' do
        expected_segments_by_string.each do |string, expected|
          expect(subject.parse(string)).to eq(expected)
        end
      end
    end

    context 'with only wildcards' do
      let(:expected_segments_by_string) do
        {
          '/*api/*users' => [
            described_class::BindWildCard.new('api'),
            described_class::BindWildCard.new('users')
          ],
          '*posts' => [
            described_class::BindWildCard.new('posts')
          ],
          '/*really/*long/*uri/*okay/*its/*not/*that/*long/*' => [
            described_class::BindWildCard.new('really'),
            described_class::BindWildCard.new('long'),
            described_class::BindWildCard.new('uri'),
            described_class::BindWildCard.new('okay'),
            described_class::BindWildCard.new('its'),
            described_class::BindWildCard.new('not'),
            described_class::BindWildCard.new('that'),
            described_class::BindWildCard.new('long'),
            described_class::BindWildCard.new('')
          ]
        }
      end

      it 'returns many BindWildCards' do
        expected_segments_by_string.each do |string, expected|
          expect(subject.parse(string)).to eq(expected)
        end
      end
    end

    context 'with a mix' do
      let(:expected_segments_by_string) do
        {
          '/api/users/:user_id' => [
            described_class::MatchString.new('api'),
            described_class::MatchString.new('users'),
            described_class::BindSegment.new('user_id')
          ],
          '*match' => [
            described_class::BindWildCard.new('match')
          ],
          '/really/:long/*uri/okay/:its/*not/that/:long/*' => [
            described_class::MatchString.new('really'),
            described_class::BindSegment.new('long'),
            described_class::BindWildCard.new('uri'),
            described_class::MatchString.new('okay'),
            described_class::BindSegment.new('its'),
            described_class::BindWildCard.new('not'),
            described_class::MatchString.new('that'),
            described_class::BindSegment.new('long'),
            described_class::BindWildCard.new('')
          ]
        }
      end

      it 'parses the String' do
        expected_segments_by_string.each do |string, expected|
          expect(subject.parse(string)).to eq(expected)
        end
      end
    end
  end

  describe '#serialize' do
    let(:segments) do
      [
        described_class::MatchString.new('really'),
        described_class::BindSegment.new('good'),
        described_class::BindWildCard.new('test')
      ]
    end
    let(:expected) { '/really/:good/*test' }

    it 'transforms an Array of PathSegments into strings' do
      expect(subject.serialize(segments))
        .to eq(expected)
    end
  end

  describe '#parse_segment' do
    context 'when the segment starts with a ":"' do
      let(:expected_segment_by_string) do
        {
          ':identifier' => described_class::BindSegment.new('identifier'),
          ':' => described_class::BindSegment.new(''),
          '::colon:' => described_class::BindSegment.new(':colon:'),
          ':*star*' => described_class::BindSegment.new('*star*')
        }
      end

      it 'returns a BindSegment' do
        expected_segment_by_string.each do |string, expected|
          expect(subject.parse_segment(string)).to eq(expected)
        end
      end
    end

    context 'when the segment starts with a "*"' do
      let(:expected_segment_by_string) do
        {
          '*identifier' => described_class::BindWildCard.new('identifier'),
          '*' => described_class::BindWildCard.new(''),
          '*:colon:' => described_class::BindWildCard.new(':colon:'),
          '**star*' => described_class::BindWildCard.new('*star*')
        }
      end

      it 'returns a BindWildCard' do
        expected_segment_by_string.each do |string, expected|
          expect(subject.parse_segment(string)).to eq(expected)
        end
      end
    end

    context 'when the segment is anything else' do
      let(:expected_segment_by_string) do
        {
          'identifier' => described_class::MatchString.new('identifier'),
          '' => described_class::MatchString.new(''),
          'colon:' => described_class::MatchString.new('colon:'),
          'star*' => described_class::MatchString.new('star*')
        }
      end

      it 'returns a MatchString' do
        expected_segment_by_string.each do |string, expected|
          expect(subject.parse_segment(string)).to eq(expected)
        end
      end
    end
  end

  describe '#serialize_segment' do
    context 'when it is a MatchString' do
      let(:segment) { described_class::MatchString.new('api') }
      let(:expected) { '/api' }

      it 'serializes the segment' do
        expect(subject.serialize_segment(segment))
          .to eq(expected)
      end
    end

    context 'when it is a BindSegment' do
      let(:segment) { described_class::BindSegment.new('user_id') }
      let(:expected) { '/:user_id' }

      it 'serializes the segment' do
        expect(subject.serialize_segment(segment))
          .to eq(expected)
      end
    end

    context 'when it is a BindWildCard' do
      let(:segment) { described_class::BindWildCard.new('rest') }
      let(:expected) { '/*rest' }

      it 'serializes the segment' do
        expect(subject.serialize_segment(segment))
          .to eq(expected)
      end
    end
  end
end
