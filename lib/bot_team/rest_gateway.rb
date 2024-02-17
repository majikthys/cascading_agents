# frozen_string_literal: true

require 'httparty'

require_relative 'chat_gpt_response'

class RestGateway
  class NoResponseError < StandardError; end

  include HTTParty

  def api_key
    BotTeam.configuration.api_key
  end

  def api_url
    'https://api.openai.com/v1/chat/completions'
  end

  def http_headers
    http_headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{api_key}"
    }
  end

  def call(chat_completion_request)
    response = try_http_request(chat_completion_request)
    return ChatGptResponse.create_from_json(response) if response&.code == 200

    $stderr.puts "==========================================="
    $stderr.puts "=== Unsuccessful response from OpenAI API ==="
    raise NoResponseError unless response

    $stderr.puts "Error: #{JSON.pretty_generate(response)}"
    raise response['error']['message']
  end

  def try_http_request(chat_completion_request)
    HTTParty.post(api_url, body: chat_completion_request.to_json, headers: http_headers, timeout: BotTeam.configuration.request_timeout)
  rescue Net::ReadTimeout
    exponent = [1.001, BotTeam.configuration.retry_rolloff_exponent].max
    delay ||= exponent
    $stderr.puts "Timeout error. Waiting #{delay} seconds then retrying..."
    sleep delay
    delay **= exponent
    retry if delay <= BotTeam.configuration.retry_longest_wait
  end
end
