require "test_helper"

class ConsoleHelpersTest < ActiveSupport::TestCase
  include ConsoleHelpers

  test "models helper returns array of model names" do
    result = models
    assert result.is_a?(Array)
    assert result.include?("Post")
  end

  test "routes helper returns array of route descriptions" do
    result = routes
    assert result.is_a?(Array)
    assert result.first.is_a?(Hash)
    assert result.first.key?(:verb)
    assert result.first.key?(:path)
  end

  test "model_info helper returns model details" do
    result = model_info(Post)
    assert result.is_a?(Hash)
    assert result.key?(:table_name)
    assert result.key?(:columns)
  end

  test "model_info helper handles invalid model" do
    result = model_info(String)
    assert result.is_a?(String)
    assert_equal "Model not found", result
  end

  test "env_info helper returns environment information" do
    result = env_info
    assert result.is_a?(Hash)
    assert result.key?(:rails_env)
    assert result.key?(:rails_version)
  end

  test "db_info helper returns database information" do
    result = db_info
    assert result.is_a?(Hash)
    assert result.key?(:adapter) || result.key?(:error)
  end

  test "app_config helper returns application configuration" do
    result = app_config
    assert result.is_a?(Hash)
    assert result.key?(:cache_classes)
  end

  test "memory_info helper returns memory statistics" do
    result = memory_info
    assert result.is_a?(Hash)
    assert result.key?(:gc_count) || result.key?(:error)
  end

  test "find_by helper works with valid conditions" do
    post = Post.create!(title: "Test", body: "Content")
    result = find_by(Post, { title: "Test" })
    
    assert result.respond_to?(:each)
    assert result.count > 0
  end

  test "find_by helper handles no results" do
    result = find_by(Post, { title: "NonExistent" })
    assert result.respond_to?(:each)
    assert_equal 0, result.count
  end

  test "find_by helper handles invalid model" do
    result = find_by(String, { name: "test" })
    assert result.is_a?(String)
    assert_match(/Invalid model/, result)
  end

  test "last_records helper returns recent records" do
    # Create some test posts
    3.times { |i| Post.create!(title: "Post #{i}", body: "Content #{i}") }
    
    result = last_records(Post, 2)
    assert result.is_a?(Array)
    assert result.length <= 2
  end

  test "last_records helper handles empty table" do
    # Clear all posts
    Post.delete_all
    
    result = last_records(Post, 5)
    assert result.is_a?(Array)
    assert_equal 0, result.length
  end

  test "last_records helper handles invalid model" do
    result = last_records(String, 5)
    assert result.is_a?(String)
    assert_match(/Invalid model/, result)
  end

  test "last_records helper defaults to 5 records" do
    # Create more than 5 posts
    10.times { |i| Post.create!(title: "Post #{i}", body: "Content #{i}") }
    
    result = last_records(Post)
    assert result.is_a?(Array)
    # Should not exceed the default limit
    assert result.length <= 5
  end

  test "table_info helper returns table structure" do
    result = table_info("posts")
    assert result.is_a?(Hash)
    assert result.key?(:columns)
    assert result[:columns].any? { |col| col[:name] == "title" }
  end

  test "table_info helper handles invalid table" do
    result = table_info("nonexistent_table")
    assert result.is_a?(String)
    assert_match(/Table not found/, result)
  end

  test "connection_info helper returns database connection details" do
    result = connection_info
    assert result.is_a?(Hash)
    assert result.key?(:adapter) || result.key?(:error)
  end

  test "cache_info helper returns cache information" do
    result = cache_info
    assert result.is_a?(Hash)
    assert result.key?(:cache_store)
  end

  test "session_info helper returns session details" do
    result = session_info
    assert result.is_a?(Hash)
    assert result.key?(:session_store)
  end

  test "helper methods handle exceptions gracefully" do
    # Test that helpers don't crash on unexpected errors
    result = db_info
    assert result.is_a?(Hash)
    assert result.key?(:adapter) || result.key?(:error)
  end
end
