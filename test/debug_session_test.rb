#!/usr/bin/env ruby

# Debug test script for console session management
require_relative '../config/environment'

# Start Rails app for testing
require 'rack/test'

class DebugConsoleSession
  include Rack::Test::Methods
  
  def app
    Rails.application
  end
  
  def debug_session_management
    puts "Debug testing console session management..."
    
    # Test 1: Create new session
    puts "\n1. Creating first session..."
    post '/console/new_session', { name: 'Debug Session 1' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    response_data = JSON.parse(last_response.body)
    puts "Session created: #{response_data['session']['id']}"
    first_session_id = response_data['session']['id']
    
    # Test 2: Set a variable
    puts "\n2. Setting variable in first session..."
    post '/console/execute', { command: 'debug_var = "first session value"' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    response_data = JSON.parse(last_response.body)
    puts "Variable set, result: #{response_data['result']}"
    puts "Session ID in response: #{response_data['session_id']}"
    
    # Test 3: Check session list and variables
    puts "\n3. Checking session list..."
    get '/console/session_list'
    
    response_data = JSON.parse(last_response.body)
    puts "Sessions:"
    response_data['sessions'].each do |sess|
      puts "  - #{sess['name']} (#{sess['id']}) - #{sess['variable_count']} variables, active: #{sess['is_active']}"
    end
    
    # Test 4: Create second session
    puts "\n4. Creating second session..."
    post '/console/new_session', { name: 'Debug Session 2' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    response_data = JSON.parse(last_response.body)
    puts "Second session created: #{response_data['session']['id']}"
    second_session_id = response_data['session']['id']
    
    # Test 5: Check sessions again
    puts "\n5. Checking session list after second session..."
    get '/console/session_list'
    
    response_data = JSON.parse(last_response.body)
    puts "Sessions:"
    response_data['sessions'].each do |sess|
      puts "  - #{sess['name']} (#{sess['id']}) - #{sess['variable_count']} variables, active: #{sess['is_active']}"
    end
    
    # Test 6: Try to access variable in second session (should fail)
    puts "\n6. Testing variable isolation in second session..."
    post '/console/execute', { command: 'debug_var' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    response_data = JSON.parse(last_response.body)
    if response_data.key?('error')
      puts "✓ Variable isolation working: #{response_data['error']}"
    else
      puts "✗ Variable isolation failed: #{response_data['result']}"
    end
    
    # Test 7: Switch back to first session
    puts "\n7. Switching back to first session..."
    put "/console/select_session/#{first_session_id}"
    
    response_data = JSON.parse(last_response.body)
    puts "Switched to: #{response_data['session']['name']}"
    puts "Variables in session: #{response_data['session']['variables']}"
    
    # Test 8: Check sessions after switch
    puts "\n8. Checking session list after switch..."
    get '/console/session_list'
    
    response_data = JSON.parse(last_response.body)
    puts "Sessions:"
    response_data['sessions'].each do |sess|
      puts "  - #{sess['name']} (#{sess['id']}) - #{sess['variable_count']} variables, active: #{sess['is_active']}"
    end
    
    # Test 9: Try to access variable again
    puts "\n9. Testing variable access in first session..."
    post '/console/execute', { command: 'debug_var' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    response_data = JSON.parse(last_response.body)
    puts "Variable access result: #{response_data['result'] || response_data['error']}"
    puts "Session ID in response: #{response_data['session_id']}"
    
    # Test 10: Check vars helper
    puts "\n10. Using vars helper..."
    post '/console/execute', { command: 'vars' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    response_data = JSON.parse(last_response.body)
    puts "Vars helper result: #{response_data['result']}"
    
    puts "\nDebug tests completed!"
  end
end

# Run the tests
tester = DebugConsoleSession.new
tester.debug_session_management
