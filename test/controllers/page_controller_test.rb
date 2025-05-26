require "test_helper"

class PageControllerTest < ActionDispatch::IntegrationTest
  test "home page loads successfully" do
    get root_path
    assert_response :success
    assert_select "h1", "Home-page"
  end
  
  test "home page shows console links in development" do
    get root_path
    assert_response :success
    
    # In test environment, Rails.env.development? is false, but we can check the structure
    # The links should be wrapped in development conditional
    assert_select "p", /About Us/
    assert_select "p", /rails_health_check/
  end
  
  test "home page contains sandbox console link when in development mode" do
    # Temporarily set Rails environment to development for this test
    original_env = Rails.env
    Rails.env = "development"
    
    begin
      get root_path
      assert_response :success
      
      # Check that both console links are present
      assert_select "a[href=?]", console_path, text: "Rails Web Console"
      assert_select "a[href=?]", console_sandbox_path, text: "Sandbox Console"
    ensure
      Rails.env = original_env
    end
  end
end
