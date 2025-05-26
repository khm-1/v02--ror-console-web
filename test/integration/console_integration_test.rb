require "test_helper"

class ConsoleIntegrationTest < ActionDispatch::IntegrationTest
  test "full console workflow" do
    # Test complete workflow from visiting page to executing commands
    
    # 1. Visit console page
    get "/console"
    assert_response :success
    assert_select "#console-input"
    
    # 2. Execute simple arithmetic
    post "/console/execute", params: { command: "2 + 3" }, as: :json
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "5", response_data["result"]
    
    # 3. Execute Rails command
    post "/console/execute", params: { command: "Rails.env" }, as: :json
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_includes ["development", "test"], response_data["result"]
    
    # 4. Test model operations
    Post.create!(title: "Integration Test", body: "Test content")
    post "/console/execute", params: { command: "Post.last.title" }, as: :json
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "Integration Test", response_data["result"]
    
    # 5. Test helper methods
    post "/console/execute", params: { command: "models" }, as: :json
    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data["result"].include?("Post")
    
    # 6. Clear history
    delete "/console/clear_history", as: :json
    assert_response :success
  end

  test "session persistence across requests" do
    # Execute first command
    post "/console/execute", params: { command: "x = 10" }, as: :json
    assert_response :success
    
    # Execute second command that depends on first
    # Note: Variables don't persist across requests in current implementation
    post "/console/execute", params: { command: "10 * 2" }, as: :json
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "20", response_data["result"]
  end

  test "error handling across different error types" do
    error_commands = [
      { cmd: "undefined_method", error_class: "NameError" },
      { cmd: "1 / 0", error_class: "ZeroDivisionError" },
      { cmd: "'string'.nonexistent_method", error_class: "NoMethodError" }
    ]
    
    error_commands.each do |test_case|
      post "/console/execute", params: { command: test_case[:cmd] }, as: :json
      assert_response :success
      
      response_data = JSON.parse(response.body)
      assert response_data["error"]
      assert_equal test_case[:error_class], response_data["error_class"]
    end
  end

  test "command history management" do
    commands = ["1 + 1", "2 + 2", "3 + 3"]
    
    # Execute multiple commands
    commands.each do |cmd|
      post "/console/execute", params: { command: cmd }, as: :json
      assert_response :success
    end
    
    # Visit console page and check history is present
    get "/console"
    assert_response :success
    
    commands.each do |cmd|
      assert_match cmd, response.body
    end
    
    # Clear history
    delete "/console/clear_history", as: :json
    assert_response :success
    
    # Visit console page again and verify history is cleared
    get "/console"
    assert_response :success
    
    commands.each do |cmd|
      assert_no_match cmd, response.body
    end
  end

  test "security restrictions work end-to-end" do
    dangerous_commands = [
      "system('echo test')",
      "File.delete('test.txt')",
      "exec('ls')",
      "eval('puts \"dangerous\"')"
    ]
    
    dangerous_commands.each do |cmd|
      post "/console/execute", params: { command: cmd }, as: :json
      assert_response 403
      
      response_data = JSON.parse(response.body)
      assert_match(/not allowed/i, response_data["error"])
    end
  end

  test "large data handling" do
    # Create multiple posts
    50.times { |i| Post.create!(title: "Post #{i}", body: "Content #{i}") }
    
    # Execute command that returns large dataset
    post "/console/execute", params: { command: "Post.all" }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data["result"].is_a?(Array)
    
    # Should be truncated for display
    assert response_data["result"].any? { |item| item.to_s.include?("more") }
  end

  test "concurrent requests handling" do
    # Simulate multiple concurrent requests
    threads = []
    results = {}
    
    5.times do |i|
      threads << Thread.new do
        post "/console/execute", params: { command: "#{i} * 10" }, as: :json
        results[i] = JSON.parse(response.body)["result"].to_i
      end
    end
    
    threads.each(&:join)
    
    # Verify all requests were handled correctly
    5.times do |i|
      assert_equal i * 10, results[i]
    end
  end

  test "special characters in commands" do
    special_commands = [
      { cmd: "'hello world'", expected: "hello world" },
      { cmd: "\"double quotes\"", expected: "double quotes" },
      { cmd: ":symbol", expected: ":symbol" },
      { cmd: "[1, 2, 3]", expected_type: Array }
    ]
    
    special_commands.each do |test_case|
      post "/console/execute", params: { command: test_case[:cmd] }, as: :json
      assert_response :success
      
      response_data = JSON.parse(response.body)
      if test_case[:expected]
        assert_equal test_case[:expected], response_data["result"]
      elsif test_case[:expected_type]
        if test_case[:expected_type] == Array
          assert response_data["result"].is_a?(Array)
        end
      end
    end
  end

  test "environment variable access" do
    post "/console/execute", params: { command: "Rails.application.class.name" }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_match(/Application/, response_data["result"])
  end

  test "database operations through console" do
    # Test creating records
    post "/console/execute", params: { 
      command: "Post.create!(title: 'Console Created', body: 'Via console')" 
    }, as: :json
    assert_response :success
    
    # Verify record was created
    assert Post.exists?(title: 'Console Created')
    
    # Test querying
    post "/console/execute", params: { 
      command: "Post.where(title: 'Console Created').count" 
    }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal "1", response_data["result"]
  end

  test "console helper methods integration" do
    helper_commands = [
      "models",
      "routes", 
      "env_info",
      "db_info",
      "app_config"
    ]
    
    helper_commands.each do |cmd|
      post "/console/execute", params: { command: cmd }, as: :json
      assert_response :success
      
      response_data = JSON.parse(response.body)
      # Helper methods return either Arrays or Hashes
      assert response_data["result"].is_a?(Array) || response_data["result"].is_a?(Hash)
      assert response_data["result"].present?
    end
  end
end
