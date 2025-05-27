require 'test_helper'

class DebugSessionsTest < ActionDispatch::IntegrationTest
  def test_debug_session_list
    # First create a session
    post "/console/new_session", params: { name: "Debug Session" }, as: :json
    puts "New session response: #{response.body}"
    
    # Then get the session list
    get "/console/session_list", as: :json
    puts "Session list response: #{response.body}"
    
    response_data = JSON.parse(response.body)
    puts "Parsed response data: #{response_data.inspect}"
    puts "Active session ID: #{response_data['active_session_id'].inspect}"
    puts "Sessions: #{response_data['sessions'].inspect}"
  end
end
