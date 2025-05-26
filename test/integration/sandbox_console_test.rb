require "test_helper"

class SandboxConsoleTest < ActionDispatch::IntegrationTest
  
  test "sandbox index page loads successfully" do
    get "/console/sandbox"
    assert_response :success
    assert_select "title", /Console/i
  end
  
  test "sandbox variable persistence across commands" do
    # Set a variable
    post "/console/sandbox/execute", params: { command: 'name = "sandbox_test"' }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal "sandbox_test", response_data["result"]
    assert_equal "sandbox", response_data["mode"]
    
    # Access the variable in a new command
    post "/console/sandbox/execute", params: { command: "name" }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_equal "sandbox_test", response_data["result"]
    assert_equal "sandbox", response_data["mode"]
  end
  
  test "sandbox variables are separate from regular console variables" do
    # Set variable in regular console
    post "/console/execute", params: { command: 'regular_var = "regular_value"' }
    assert_response :success
    
    # Try to access in sandbox (should fail)
    post "/console/sandbox/execute", params: { command: "regular_var" }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_match /undefined local variable/, response_data["error"]
    
    # Set variable in sandbox
    post "/console/sandbox/execute", params: { command: 'sandbox_var = "sandbox_value"' }
    assert_response :success
    
    # Try to access in regular console (should fail)
    post "/console/execute", params: { command: "sandbox_var" }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_match /undefined local variable/, response_data["error"]
  end
  
  test "sandbox clear history clears variables" do
    # Set a variable
    post "/console/sandbox/execute", params: { command: 'test_var = "will_be_cleared"' }
    assert_response :success
    
    # Verify variable exists
    post "/console/sandbox/execute", params: { command: "test_var" }
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "will_be_cleared", response_data["result"]
    
    # Clear history
    delete "/console/sandbox/clear_history"
    assert_response :success
    
    # Try to access variable (should fail)
    post "/console/sandbox/execute", params: { command: "test_var" }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_match /undefined local variable/, response_data["error"]
  end
  
  test "sandbox blocks dangerous commands" do
    dangerous_commands = [
      "system('ls')",
      "exec('whoami')",
      "`pwd`",
      "File.delete('test.txt')",
      "exit"
    ]
    
    dangerous_commands.each do |command|
      post "/console/sandbox/execute", params: { command: command }
      assert_response 403
      
      response_data = JSON.parse(response.body)
      assert_match /not allowed/, response_data["error"]
    end
  end
  
  test "sandbox blocks additional restricted commands" do
    restricted_commands = [
      "kill 1234",
      "chmod 777 file.txt",
      "rm -rf /",
      "mv file1 file2",
      "cat /etc/passwd"
    ]
    
    restricted_commands.each do |command|
      post "/console/sandbox/execute", params: { command: command }
      assert_response 403
      
      response_data = JSON.parse(response.body)
      assert_match /not allowed/, response_data["error"]
    end
  end
  
  test "sandbox allows basic arithmetic and variable operations" do
    # Test basic arithmetic
    post "/console/sandbox/execute", params: { command: "2 + 3" }
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "5", response_data["result"] # format_result converts to string
    
    # Test string operations
    post "/console/sandbox/execute", params: { command: '"Hello " + "World"' }
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "Hello World", response_data["result"]
    
    # Test variable assignment and access
    post "/console/sandbox/execute", params: { command: "x = 42" }
    assert_response :success
    
    post "/console/sandbox/execute", params: { command: "x * 2" }
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "84", response_data["result"] # format_result converts to string
  end
  
  test "sandbox vars helper method shows current variables" do
    # Initially no variables
    post "/console/sandbox/execute", params: { command: "vars" }
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "No variables defined", response_data["result"]
    
    # Set some variables
    post "/console/sandbox/execute", params: { command: 'a = 1' }
    assert_response :success
    
    post "/console/sandbox/execute", params: { command: 'b = "test"' }
    assert_response :success
    
    # Check vars output
    post "/console/sandbox/execute", params: { command: "vars" }
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_match /a = 1/, response_data["result"]
    assert_match /b = "test"/, response_data["result"]
  end
  
  test "sandbox restricts method calls more than regular console" do
    # This should work in regular console but be restricted in sandbox
    post "/console/sandbox/execute", params: { command: "File.read('test.txt')" }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_match /undefined local variable/, response_data["error"]
  end
  
end
