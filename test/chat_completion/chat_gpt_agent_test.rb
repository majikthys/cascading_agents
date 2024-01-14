# frozen_string_literal: true

require 'test_helper'

describe ChatGptAgent do
  it 'initializes from config' do
    agent = ChatGptAgent.new(config_path: 'test/config/test_agents/switchboard.yml')
    _(agent.model).must_be_nil
    _(agent.system_directives).must_match(/^Your are an agent that classifies/)
  end
end
