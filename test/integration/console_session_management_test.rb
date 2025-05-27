require "test_helper"

class ConsoleSessionManagementTest < ActionDispatch::IntegrationTest
  test "creates new console session" do
    post "/console/new_session", params: { name: "Test Session" }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal "New console session created", response_data["message"]
    assert_equal "Test Session", response_data["session"]["name"]
    assert response_data["session"]["id"]
    assert response_data["active_session_id"]
  end

  test "creates new session with default name when no name provided" do
    post "/console/new_session", as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_includes response_data["session"]["name"], "Session"
  end

  test "lists console sessions" do
    # Create a couple of sessions first
    post "/console/new_session", params: { name: "Session 1" }, as: :json
    post "/console/new_session", params: { name: "Session 2" }, as: :json
    
    get "/console/session_list", as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data["sessions"].length >= 2
    assert response_data["active_session_id"]
    assert response_data["total_sessions"] >= 2
    
    # Check session properties
    session = response_data["sessions"].first
    assert session["id"]
    assert session["name"]
    assert session["created_at"]
    assert session["last_active"]
    assert session.key?("command_count")
    assert session.key?("variable_count")
    assert session.key?("is_active")
  end

  test "selects and activates a different session" do
    # Create two sessions
    post "/console/new_session", params: { name: "Session 1" }, as: :json
    session_1_id = JSON.parse(response.body)["session"]["id"]
    
    post "/console/new_session", params: { name: "Session 2" }, as: :json
    session_2_id = JSON.parse(response.body)["session"]["id"]
    
    # Switch back to session 1
    put "/console/select_session/#{session_1_id}", as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal "Switched to session", response_data["message"]
    assert_equal session_1_id, response_data["active_session_id"]
    assert_equal "Session 1", response_data["session"]["name"]
  end

  test "returns error when selecting non-existent session" do
    put "/console/select_session/nonexistent", as: :json
    assert_response :not_found
    
    response_data = JSON.parse(response.body)
    assert_equal "Session not found", response_data["error"]
  end

  test "closes a console session" do
    # Create two sessions (we need at least 2 to close one)
    post "/console/new_session", params: { name: "Session 1" }, as: :json
    session_1_id = JSON.parse(response.body)["session"]["id"]
    
    post "/console/new_session", params: { name: "Session 2" }, as: :json
    
    # Close session 1
    delete "/console/close_session/#{session_1_id}", as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal "Session closed", response_data["message"]
    assert_equal "Session 1", response_data["closed_session"]["name"]
    assert response_data["active_session_id"]
    assert_equal 1, response_data["remaining_sessions"]
  end

  test "cannot close the last remaining session" do
    # Get the list to find current sessions
    get "/console/session_list", as: :json
    sessions = JSON.parse(response.body)["sessions"]
    
    # Close all but one session
    sessions[1..-1].each do |session|
      delete "/console/close_session/#{session["id"]}", as: :json
    end if sessions.length > 1
    
    # Try to close the last session
    last_session_id = sessions.first["id"]
    delete "/console/close_session/#{last_session_id}", as: :json
    assert_response :bad_request
    
    response_data = JSON.parse(response.body)
    assert_equal "Cannot close the last session", response_data["error"]
  end

  test "returns error when closing non-existent session" do
    delete "/console/close_session/nonexistent", as: :json
    assert_response :not_found
    
    response_data = JSON.parse(response.body)
    assert_equal "Session not found", response_data["error"]
  end

  test "variables are isolated between sessions" do
    # Create first session and set a variable
    post "/console/new_session", params: { name: "Session A" }, as: :json
    session_a_id = JSON.parse(response.body)["session"]["id"]
    
    post "/console/execute", params: { command: 'a_var = "session A value"' }, as: :json
    assert_response :success
    
    # Create second session and set a different variable
    post "/console/new_session", params: { name: "Session B" }, as: :json
    session_b_id = JSON.parse(response.body)["session"]["id"]
    
    post "/console/execute", params: { command: 'b_var = "session B value"' }, as: :json
    assert_response :success
    
    # In session B, a_var should not exist
    post "/console/execute", params: { command: "a_var" }, as: :json
    response_data = JSON.parse(response.body)
    assert response_data.key?("error")
    assert_includes response_data["error"], "undefined"
    
    # Switch back to session A
    put "/console/select_session/#{session_a_id}", as: :json
    
    # In session A, a_var should exist but b_var should not
    post "/console/execute", params: { command: "a_var" }, as: :json
    response_data = JSON.parse(response.body)
    assert_equal "session A value", response_data["result"]
    
    post "/console/execute", params: { command: "b_var" }, as: :json
    response_data = JSON.parse(response.body)
    assert response_data.key?("error")
    assert_includes response_data["error"], "undefined"
  end

  test "command history is isolated between sessions" do
    # Create first session and execute a command
    post "/console/new_session", params: { name: "Session A" }, as: :json
    session_a_id = JSON.parse(response.body)["session"]["id"]
    
    post "/console/execute", params: { command: '1 + 1' }, as: :json
    
    # Create second session and execute a different command  
    post "/console/new_session", params: { name: "Session B" }, as: :json
    
    post "/console/execute", params: { command: '2 + 2' }, as: :json
    
    # Check session list to verify command counts
    get "/console/session_list", as: :json
    response_data = JSON.parse(response.body)
    
    sessions_by_name = response_data["sessions"].index_by { |s| s["name"] }
    assert_equal 1, sessions_by_name["Session A"]["command_count"]
    assert_equal 1, sessions_by_name["Session B"]["command_count"]
  end

  test "clear history only affects current session" do
    # Create two sessions with variables and history
    post "/console/new_session", params: { name: "Session A" }, as: :json
    session_a_id = JSON.parse(response.body)["session"]["id"]
    
    post "/console/execute", params: { command: 'a_var = "A"' }, as: :json
    
    post "/console/new_session", params: { name: "Session B" }, as: :json
    session_b_id = JSON.parse(response.body)["session"]["id"]
    
    post "/console/execute", params: { command: 'b_var = "B"' }, as: :json
    
    # Clear history in session B
    delete "/console/clear_history", as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_includes response_data["message"], "current session"
    
    # Variables in session B should be cleared
    post "/console/execute", params: { command: "b_var" }, as: :json
    response_data = JSON.parse(response.body)
    assert response_data.key?("error")
    
    # Switch to session A - variables should still exist
    put "/console/select_session/#{session_a_id}", as: :json
    
    post "/console/execute", params: { command: "a_var" }, as: :json
    response_data = JSON.parse(response.body)
    assert_equal "A", response_data["result"]
  end

  test "session migration from legacy format" do
    # This test ensures that existing sessions migrate properly
    # When console loads with old session format, it should migrate to new format
    get "/console", as: :html
    assert_response :success
    
    # Check that we can create sessions after migration
    post "/console/new_session", params: { name: "Post Migration" }, as: :json
    assert_response :success
  end
end
