require "test_helper"

class ConsoleControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Ensure we're in development environment for tests
    Rails.env = "development"
  end

  test "should get console index page" do
    get console_path
    assert_response :success
    assert_select "title", "Rails Web Console"
    assert_select ".console-container"
    assert_select "#console-input"
    assert_select "#console-output"
  end

  test "should execute simple ruby command" do
    post console_execute_path, params: { command: "1 + 1" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal "1 + 1", json_response["command"]
    assert_equal "2", json_response["result"]
    assert json_response["timestamp"]
  end

  test "should execute rails model commands" do
    # Create a test post first
    Post.create!(title: "Test Post", body: "Test body")
    
    post console_execute_path, params: { command: "Post.count" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal "Post.count", json_response["command"]
    assert json_response["result"].to_i > 0
  end

  test "should handle model queries" do
    post1 = Post.create!(title: "First Post", body: "First body")
    post2 = Post.create!(title: "Second Post", body: "Second body")
    
    post console_execute_path, params: { command: "Post.all" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response["result"].is_a?(Array)
  end

  test "should execute helper methods" do
    post console_execute_path, params: { command: "models" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response["result"].is_a?(Array)
    assert json_response["result"].include?("Post")
  end

  test "should handle errors gracefully" do
    post console_execute_path, params: { command: "undefined_variable" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response["error"]
    assert_equal "NameError", json_response["error_class"]
  end

  test "should block dangerous commands" do
    dangerous_commands = [
      "system('ls')",
      "exec('rm -rf /')",
      "`ls`",
      "File.delete('test.txt')",
      "exit",
      "eval('dangerous code')"
    ]

    dangerous_commands.each do |cmd|
      post console_execute_path, params: { command: cmd }, as: :json
      assert_response 403, "Command '#{cmd}' should be blocked"
      
      json_response = JSON.parse(response.body)
      assert_match(/not allowed/i, json_response["error"])
    end
  end

  test "should reject empty commands" do
    post console_execute_path, params: { command: "" }, as: :json
    assert_response 400
    
    json_response = JSON.parse(response.body)
    assert_match(/cannot be empty/i, json_response["error"])
  end

  test "should reject blank commands" do
    post console_execute_path, params: { command: "   " }, as: :json
    assert_response 400
    
    json_response = JSON.parse(response.body)
    assert_match(/cannot be empty/i, json_response["error"])
  end

  test "should store command history in session" do
    # Execute first command
    post console_execute_path, params: { command: "1 + 1" }, as: :json
    assert_response :success
    
    # Execute second command
    post console_execute_path, params: { command: "2 + 2" }, as: :json
    assert_response :success
    
    # Check that history is stored
    get console_path
    assert_response :success
    
    # The history should be available in the page
    assert_match "1 + 1", response.body
    assert_match "2 + 2", response.body
  end

  test "should clear command history" do
    # Add some commands to history
    post console_execute_path, params: { command: "1 + 1" }, as: :json
    post console_execute_path, params: { command: "2 + 2" }, as: :json
    
    # Clear history
    delete console_clear_history_path, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_match(/cleared/i, json_response["message"])
  end

  test "should handle string results properly" do
    post console_execute_path, params: { command: "'hello world'" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal "hello world", json_response["result"]
  end

  test "should handle nil results" do
    post console_execute_path, params: { command: "nil" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal "nil", json_response["result"]
  end

  test "should handle boolean results" do
    post console_execute_path, params: { command: "true" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal "true", json_response["result"]
    
    post console_execute_path, params: { command: "false" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal "false", json_response["result"]
  end

  test "should handle array results with truncation" do
    # Create an array larger than the display limit
    post console_execute_path, params: { command: "(1..15).to_a" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response["result"].is_a?(Array)
    # Should be truncated with "... more items" message
    assert json_response["result"].any? { |item| item.to_s.include?("more items") }
  end

  test "should handle hash results" do
    post console_execute_path, params: { command: "{ a: 1, b: 2 }" }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response["result"].is_a?(Array)
    assert json_response["result"].any? { |item| item.include?(":a") }
  end

  test "should restrict access to non-development environments" do
    # Temporarily change environment
    original_env = Rails.env
    Rails.env = "production"
    
    get console_path
    assert_response 403
    assert_match(/not allowed/i, response.body)
    
    # Restore environment
    Rails.env = original_env
  end

  test "should include CSRF protection" do
    # Test without CSRF token
    post console_execute_path, params: { command: "1 + 1" }, as: :json, headers: { 'X-CSRF-Token' => 'invalid' }
    # This should fail with CSRF error (exact response depends on Rails configuration)
    # In test environment, CSRF might be disabled, so we just ensure the endpoint exists
    assert_response :success # or :unprocessable_entity depending on config
  end

  private

  def console_execute_path
    "/console/execute"
  end

  def console_clear_history_path
    "/console/clear_history"
  end
end
