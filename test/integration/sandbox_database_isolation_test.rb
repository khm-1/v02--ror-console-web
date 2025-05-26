require "test_helper"

class SandboxDatabaseIsolationTest < ActionDispatch::IntegrationTest
  
  test "sandbox database changes are rolled back automatically" do
    # First, count existing posts
    initial_count = Post.count
    
    # Execute a command that creates a new post in sandbox
    post "/console/sandbox/execute", params: { 
      command: "Post.create!(title: 'Sandbox Test', body: 'This should not persist')" 
    }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    # The command should succeed but the post should have id: nil due to rollback
    assert_match /id: nil/, response_data["result"]
    assert_match /Sandbox Test/, response_data["result"]
    
    # Check the actual database count outside of sandbox
    # This should still be the original count because changes were rolled back
    actual_count = Post.count
    assert_equal initial_count, actual_count, "Database changes should be rolled back outside sandbox"
  end
  
  test "sandbox can read existing data but cannot persist changes" do
    # Create a post outside of sandbox
    test_post = Post.create!(title: "Real Post", body: "This persists")
    
    # Read the post in sandbox
    post "/console/sandbox/execute", params: { command: "Post.find(#{test_post.id})" }
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_match /Real Post/, response_data["result"]
    
    # Try to modify the post in sandbox - this will be rolled back
    post "/console/sandbox/execute", params: { 
      command: "Post.find(#{test_post.id}).update!(title: 'Modified in Sandbox')" 
    }
    assert_response :success
    
    # Verify the actual database record is unchanged due to rollback
    test_post.reload
    assert_equal "Real Post", test_post.title, "Original post should be unchanged due to rollback"
    
    # Clean up
    test_post.destroy
  end
  
  test "sandbox info method shows rollback warning" do
    post "/console/sandbox/execute", params: { command: "sandbox_info" }
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_match /SANDBOX MODE/, response_data["result"]
    assert_match /rolled back/, response_data["result"]
  end
  
  test "multiple sandbox sessions are isolated from each other" do
    # Create a post in first sandbox session
    post "/console/sandbox/execute", params: { 
      command: "Post.create!(title: 'Session 1', body: 'test')" 
    }
    assert_response :success
    
    # Clear sandbox session to simulate new browser session
    delete "/console/sandbox/clear_history"
    assert_response :success
    
    # In new sandbox session, the post should not exist
    # (because it was rolled back when the previous session ended)
    initial_count = Post.count
    post "/console/sandbox/execute", params: { command: "Post.where(title: 'Session 1').count" }
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "0", response_data["result"], "Posts from previous sandbox session should not exist"
  end
  
end
