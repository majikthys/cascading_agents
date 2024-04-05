# frozen_string_literal: true

require 'test_helper'

describe 'Agent::Chooser' do
  def setup
    VCR.insert_cassette('agent_chooser')
  end

  def teardown
    VCR.eject_cassette
  end

  def giving_info
    @action = 'giving'
  end

  def requesting_info
    @action = 'requesting'
  end

  def unknown
    @action = 'unknown'
  end

  let(:give_or_request) do
    Agent::Chooser.new(config: {temperature: 0.2}).tap do |c|
      c.add_option('giving', description: 'User is giving some information', method: method(:giving_info))
      c.add_option('requesting', description: 'User is requesting some information', method: method(:requesting_info))
      c.add_option('unknown', description: 'The input is incomprehensible or the user is neither requesting nor offering information', method: method(:unknown))
    end
  end

  it 'can classify a giving request' do
    give_or_request.run(messages: [{ role: 'user', content: 'My name is Bob' }])
    _(@action).must_equal('giving')
  end

  it 'can classify a requesting request' do
    give_or_request.run(messages: [{ role: 'user', content: 'Who is the president of the United States?' }])
    _(@action).must_equal('requesting')
  end

  it 'can classify an unknown request' do
    give_or_request.run(messages: [{ role: 'user', content: 'Shabazoo' }])
    _(@action).must_equal('unknown')
  end
end