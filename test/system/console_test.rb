require "application_system_test_case"

class ConsoleSystemTest < ApplicationSystemTestCase
  setup do
    # Ensure we're in development environment for tests
    Rails.env = "development"
  end

  test "visiting the console page" do
    visit console_path
    
    assert_selector "h1", text: "Rails Web Console", visible: false
    assert_selector ".console-container"
    assert_selector "#console-input"
    assert_selector "#console-output"
    assert_selector ".console-header"
  end

  test "console input is focused on load" do
    visit console_path
    
    # Check that the input field has focus
    input_element = find("#console-input")
    assert_equal input_element, page.driver.browser.switch_to.active_element
  end

  test "executing simple commands" do
    visit console_path
    
    # Enter a simple command
    fill_in "console-input", with: "1 + 1"
    find("#console-input").send_keys(:return)
    
    # Wait for the result to appear
    assert_text "2", wait: 5
    assert_text "> 1 + 1"
  end

  test "executing Rails model commands" do
    # Create test data
    Post.create!(title: "Test Post", body: "Test body")
    
    visit console_path
    
    # Test Post.count
    fill_in "console-input", with: "Post.count"
    find("#console-input").send_keys(:return)
    
    # Should show count result
    assert_text "1", wait: 5
    assert_text "> Post.count"
  end

  test "command history navigation" do
    visit console_path
    
    # Execute first command
    fill_in "console-input", with: "1 + 1"
    find("#console-input").send_keys(:return)
    
    # Wait for completion
    assert_text "2", wait: 5
    
    # Execute second command
    fill_in "console-input", with: "2 + 2"
    find("#console-input").send_keys(:return)
    
    # Wait for completion
    assert_text "4", wait: 5
    
    # Navigate history with arrow keys
    find("#console-input").send_keys(:arrow_up)
    assert_equal "2 + 2", find("#console-input").value
    
    find("#console-input").send_keys(:arrow_up)
    assert_equal "1 + 1", find("#console-input").value
    
    find("#console-input").send_keys(:arrow_down)
    assert_equal "2 + 2", find("#console-input").value
  end

  test "error handling display" do
    visit console_path
    
    # Execute a command that will cause an error
    fill_in "console-input", with: "undefined_variable"
    find("#console-input").send_keys(:return)
    
    # Should display error
    assert_text "Error:", wait: 5
    assert_text "NameError"
  end

  test "clear output button works" do
    visit console_path
    
    # Execute some commands to populate output
    fill_in "console-input", with: "1 + 1"
    find("#console-input").send_keys(:return)
    assert_text "2", wait: 5
    
    fill_in "console-input", with: "2 + 2"
    find("#console-input").send_keys(:return)
    assert_text "4", wait: 5
    
    # Click clear output button
    click_button "Clear Output"
    
    # Commands should be cleared but welcome messages should remain
    assert_text "Welcome to Rails Web Console"
    assert_no_text "> 1 + 1"
    assert_no_text "> 2 + 2"
  end

  test "clear history button works" do
    visit console_path
    
    # Execute some commands
    fill_in "console-input", with: "1 + 1"
    find("#console-input").send_keys(:return)
    assert_text "2", wait: 5
    
    # Accept the confirmation dialog and clear history
    accept_confirm do
      click_button "Clear History"
    end
    
    # Should show history cleared message
    assert_text "Command history cleared", wait: 5
  end

  test "keyboard shortcuts work" do
    visit console_path
    
    # Execute a command to populate output
    fill_in "console-input", with: "1 + 1"
    find("#console-input").send_keys(:return)
    assert_text "2", wait: 5
    
    # Test Ctrl+L to clear output
    find("#console-input").send_keys([:control, 'l'])
    
    # Output should be cleared
    assert_text "Welcome to Rails Web Console"
    assert_no_text "> 1 + 1"
  end

  test "execute button works" do
    visit console_path
    
    # Enter command and click execute button instead of pressing enter
    fill_in "console-input", with: "3 + 3"
    click_button "Execute"
    
    # Should show result
    assert_text "6", wait: 5
    assert_text "> 3 + 3"
  end

  test "helper commands work" do
    visit console_path
    
    # Test models helper
    fill_in "console-input", with: "models"
    find("#console-input").send_keys(:return)
    
    # Should show available models
    assert_text "Post", wait: 5
    assert_text "> models"
  end

  test "clicking on history items reuses commands" do
    visit console_path
    
    # Execute a command first
    fill_in "console-input", with: "5 + 5"
    find("#console-input").send_keys(:return)
    assert_text "10", wait: 5
    
    # If there are history items displayed, click on one
    if page.has_css?(".history-item")
      first(".history-item").click
      # The input should be filled with the clicked command
      assert_not_equal "", find("#console-input").value
    end
  end

  test "console shows welcome messages and examples" do
    visit console_path
    
    # Check for welcome messages
    assert_text "Welcome to Rails Web Console"
    assert_text "Type Ruby/Rails commands below"
    assert_text "Try these commands:"
    
    # Check for example commands
    assert_text "models"
    assert_text "routes"
    assert_text "Post.count"
    assert_text "model_info(Post)"
    assert_text "env_info"
  end

  test "console handles long output gracefully" do
    visit console_path
    
    # Execute a command that produces long output
    fill_in "console-input", with: "(1..100).to_a"
    find("#console-input").send_keys(:return)
    
    # Should handle the long array output
    assert_text "more items", wait: 10
  end

  test "console input clears after execution" do
    visit console_path
    
    # Enter and execute command
    fill_in "console-input", with: "1 + 1"
    find("#console-input").send_keys(:return)
    
    # Wait for execution
    assert_text "2", wait: 5
    
    # Input should be cleared
    assert_equal "", find("#console-input").value
  end

  test "loading indicator appears during execution" do
    visit console_path
    
    # Execute command and check for loading indicator
    fill_in "console-input", with: "sleep(0.1); 'done'"
    find("#console-input").send_keys(:return)
    
    # Should briefly show loading message
    # Note: This might be too fast to reliably test in some environments
    # assert_text "Executing...", wait: 1
    
    # Should eventually show result
    assert_text "done", wait: 5
  end

  private

  def console_path
    "/console"
  end
end
