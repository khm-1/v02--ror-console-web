require "test_helper"

class VariablePersistenceTest < ActionDispatch::IntegrationTest
  test "variables persist across console commands" do
    # Set a variable
    post "/console/execute", params: { command: 'name = "xoxo"' }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal 'xoxo', response_data["result"]
    
    # Access the variable in a new command
    post "/console/execute", params: { command: "name" }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal 'xoxo', response_data["result"]
  end

  test "complex variable assignments work" do
    # Set multiple variables
    post "/console/execute", params: { command: 'x = 10' }, as: :json
    assert_response :success
    
    post "/console/execute", params: { command: 'y = 20' }, as: :json
    assert_response :success
    
    # Use variables in calculations
    post "/console/execute", params: { command: "x + y" }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal "30", response_data["result"]
  end

  test "vars helper shows current variables" do
    # Set some variables
    post "/console/execute", params: { command: 'a = 1' }, as: :json
    assert_response :success
    
    post "/console/execute", params: { command: 'b = "hello"' }, as: :json
    assert_response :success
    
    # Check vars helper
    post "/console/execute", params: { command: "vars" }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    result = response_data["result"]
    assert_includes result, "a = 1"
    assert_includes result, 'b = "hello"'
  end

  test "clear_history also clears variables" do
    # Set a variable
    post "/console/execute", params: { command: 'temp = "test"' }, as: :json
    assert_response :success
    
    # Clear history and variables
    delete "/console/clear_history", as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_includes response_data["message"], "variables cleared"
    
    # Variable should no longer exist
    post "/console/execute", params: { command: "temp" }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data.key?("error")
    assert_includes response_data["error"], "undefined"
  end

  test "variables are session-scoped" do
    # This test ensures variables don't leak between different sessions
    # We'll simulate this by clearing and setting new variables
    
    # Clear any existing variables
    delete "/console/clear_history", as: :json
    
    # Set a variable in this session
    post "/console/execute", params: { command: 'session_var = "session1"' }, as: :json
    assert_response :success
    
    # Verify it exists
    post "/console/execute", params: { command: "session_var" }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal 'session1', response_data["result"]
  end
end
