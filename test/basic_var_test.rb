#!/usr/bin/env ruby

# Test session persistence without any session management
require_relative '../config/environment'
require 'rack/test'

class BasicVariableTest
  include Rack::Test::Methods
  
  def app
    Rails.application
  end
  
  def test_without_session_methods
    puts "Testing basic variable assignment and retrieval..."
    
    # First, let's manually call the console routes that existed before
    puts "\n=== Test 1: Basic execute ==="
    
    # Post to the existing console/execute route
    response = post '/console/execute', { command: 'simple_test = "works"' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    puts "Response status: #{last_response.status}"
    if last_response.status == 200
      begin
        response_data = JSON.parse(last_response.body)
        puts "Response: #{response_data}"
      rescue JSON::ParserError => e
        puts "JSON Parse Error: #{e.message}"
        puts "Raw response body (first 200 chars):"
        puts last_response.body[0..200]
      end
    else
      puts "Error response body:"
      puts last_response.body[0..500]
    end
  end
end

tester = BasicVariableTest.new
tester.test_without_session_methods
