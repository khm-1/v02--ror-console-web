#!/usr/bin/env ruby

# Simple session variable test
require_relative '../config/environment'
require 'rack/test'

class SimpleSessionTest
  include Rack::Test::Methods
  
  def app
    Rails.application
  end
  
  def test_basic_variables
    puts "Testing basic variable functionality..."
    
    # Test basic variable assignment
    puts "\n1. Setting a variable..."
    post '/console/execute', { command: 'x = 42' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    response_data = JSON.parse(last_response.body)
    puts "Set x = 42, result: #{response_data['result']}"
    
    # Test immediate variable access
    puts "\n2. Accessing variable immediately..."
    post '/console/execute', { command: 'x' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    response_data = JSON.parse(last_response.body)
    puts "Access x, result: #{response_data['result'] || response_data['error']}"
    
    # Test vars helper
    puts "\n3. Using vars helper..."
    post '/console/execute', { command: 'vars' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    response_data = JSON.parse(last_response.body)
    puts "vars result: #{response_data['result']}"
    
    puts "\nBasic variable test completed!"
  end
end

tester = SimpleSessionTest.new
tester.test_basic_variables
