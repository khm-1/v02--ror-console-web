#!/usr/bin/env ruby

# Manual test script for console session management
require_relative '../config/environment'

# Start Rails app for testing
require 'rack/test'

class TestConsoleSession
  include Rack::Test::Methods
  
  def app
    Rails.application
  end
  
  def test_session_management
    puts "Testing console session management..."
    
    # Test 1: Create new session
    puts "\n1. Testing new session creation..."
    post '/console/new_session', { name: 'Test Session' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    if last_response.status == 200
      response_data = JSON.parse(last_response.body)
      puts "✓ New session created: #{response_data['session']['name']}"
      session_id = response_data['session']['id']
    else
      puts "✗ Failed to create new session: #{last_response.status}"
      puts last_response.body
      return
    end
    
    # Test 2: Execute command in session
    puts "\n2. Testing command execution..."
    post '/console/execute', { command: 'test_var = "hello world"' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    if last_response.status == 200
      response_data = JSON.parse(last_response.body)
      puts "✓ Command executed: #{response_data['result']}"
    else
      puts "✗ Failed to execute command: #{last_response.status}"
      puts last_response.body
      return
    end
    
    # Test 3: List sessions
    puts "\n3. Testing session list..."
    get '/console/session_list'
    
    if last_response.status == 200
      response_data = JSON.parse(last_response.body)
      puts "✓ Session list retrieved: #{response_data['sessions'].length} sessions"
    else
      puts "✗ Failed to get session list: #{last_response.status}"
      puts last_response.body
      return
    end
    
    # Test 4: Create second session
    puts "\n4. Testing second session creation..."
    post '/console/new_session', { name: 'Second Session' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    if last_response.status == 200
      response_data = JSON.parse(last_response.body)
      puts "✓ Second session created: #{response_data['session']['name']}"
      second_session_id = response_data['session']['id']
    else
      puts "✗ Failed to create second session: #{last_response.status}"
      puts last_response.body
      return
    end
    
    # Test 5: Variable isolation
    puts "\n5. Testing variable isolation..."
    post '/console/execute', { command: 'test_var' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    if last_response.status == 200
      response_data = JSON.parse(last_response.body)
      if response_data.key?('error')
        puts "✓ Variable isolation working: #{response_data['error']}"
      else
        puts "✗ Variable isolation failed: variable accessible in new session"
      end
    else
      puts "✗ Failed to test variable isolation: #{last_response.status}"
    end
    
    # Test 6: Switch back to first session
    puts "\n6. Testing session switching..."
    put "/console/select_session/#{session_id}"
    
    if last_response.status == 200
      response_data = JSON.parse(last_response.body)
      puts "✓ Switched to session: #{response_data['session']['name']}"
    else
      puts "✗ Failed to switch session: #{last_response.status}"
      puts last_response.body
      return
    end
    
    # Test 7: Check variable exists in first session
    puts "\n7. Testing variable persistence..."
    post '/console/execute', { command: 'test_var' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    if last_response.status == 200
      response_data = JSON.parse(last_response.body)
      if response_data['result'] == 'hello world'
        puts "✓ Variable persistence working: #{response_data['result']}"
      else
        puts "✗ Variable persistence failed: #{response_data['result']}"
      end
    else
      puts "✗ Failed to test variable persistence: #{last_response.status}"
    end
    
    puts "\nAll tests completed!"
  end
end

# Run the tests
tester = TestConsoleSession.new
tester.test_session_management
