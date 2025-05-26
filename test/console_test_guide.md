# Console Test Configuration and Guidelines

## Test Structure Overview

The Rails Web Console has comprehensive test coverage across multiple layers:

### 1. Unit Tests
- **Controller Tests** (`test/controllers/console_controller_test.rb`)
  - Tests individual controller actions
  - Security validations
  - Response format verification
  - Error handling

- **Helper Tests** (`test/helpers/console_helpers_test.rb`)
  - Tests all helper methods
  - Error handling in helpers
  - Data formatting validation

### 2. Integration Tests
- **Integration Tests** (`test/integration/console_integration_test.rb`)
  - End-to-end workflow testing
  - Session management
  - Security enforcement
  - Database operations

### 3. System Tests
- **System Tests** (`test/system/console_test.rb`)
  - Full browser UI testing
  - JavaScript functionality
  - User interaction testing
  - Visual verification

### 4. JavaScript Tests
- **JavaScript Tests** (`test/javascript/console_test.js`)
  - Manual testing scenarios
  - Performance testing helpers
  - Memory leak detection

## Running Tests

### Run All Console Tests
```bash
# Run all tests
bundle exec rails test

# Run specific test files
bundle exec rails test test/controllers/console_controller_test.rb
bundle exec rails test test/system/console_test.rb
bundle exec rails test test/integration/console_integration_test.rb
bundle exec rails test test/helpers/console_helpers_test.rb
```

### Run System Tests (requires browser)
```bash
# Run system tests with headless browser
bundle exec rails test:system

# Run with visible browser (for debugging)
HEADLESS=false bundle exec rails test:system
```

### Run JavaScript Tests (manual)
1. Open browser to `/console`
2. Open browser console (F12)
3. Run: `runJavaScriptTests()`
4. Follow manual testing checklist

## Test Data Setup

### Fixtures
The tests use Rails fixtures and factory methods:

```ruby
# test/fixtures/posts.yml
post_one:
  title: "Test Post One"
  content: "Content for test post one"
  
post_two:
  title: "Test Post Two" 
  content: "Content for test post two"
```

### Test Database
Tests run against the test database configured in `config/database.yml`:

```yaml
test:
  <<: *default
  database: storage/test.sqlite3
```

## Security Testing

### Dangerous Command Tests
The test suite verifies that dangerous commands are properly blocked:

- System commands (`system`, `exec`, backticks)
- File operations (`File.delete`, `FileUtils.rm`)
- Code evaluation (`eval`, `instance_eval`)
- Process control (`exit`, `quit`, `fork`)

### Environment Restrictions
Tests verify that the console is only accessible in development/test environments.

## Performance Testing

### Manual Performance Tests
Use the JavaScript helpers for performance validation:

```javascript
// In browser console at /console
measureConsolePerformance()
checkMemoryLeaks()
```

### Load Testing
For production-like testing, use tools like:
- Apache Bench (ab)
- wrk
- Artillery

Example load test:
```bash
# Test console endpoint
ab -n 100 -c 10 -H "Content-Type: application/json" \
  -p console_command.json http://localhost:3000/console/execute
```

## Continuous Integration

### GitHub Actions Example
```yaml
name: Console Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bundle exec rails test
      - run: bundle exec rails test:system
```

### Test Coverage
Monitor test coverage using SimpleCov:

```ruby
# In test_helper.rb
require 'simplecov'
SimpleCov.start 'rails'
```

## Testing Best Practices

### 1. Test Isolation
- Each test should be independent
- Use setup/teardown to manage test data
- Don't rely on external services

### 2. Test Data
- Use factories or fixtures for consistent test data
- Clean up data after tests
- Use transactions for database tests

### 3. Error Testing
- Test both happy path and error cases
- Verify error messages and status codes
- Test edge cases and boundary conditions

### 4. Security Testing
- Always test security restrictions
- Verify access controls
- Test input validation

### 5. Performance Testing
- Set performance benchmarks
- Test with realistic data volumes
- Monitor memory usage

## Debugging Failed Tests

### Common Issues
1. **Environment Problems**
   - Ensure test environment is properly configured
   - Check that console is enabled for test environment

2. **Database Issues**
   - Run `rails db:test:prepare`
   - Check database permissions

3. **JavaScript Issues**
   - Verify asset pipeline is working
   - Check browser console for errors
   - Ensure JavaScript is enabled

4. **Timing Issues**
   - Increase wait times for async operations
   - Use proper assertions for dynamic content

### Debug Commands
```bash
# Reset test database
bundle exec rails db:test:prepare

# Run tests with verbose output
bundle exec rails test -v

# Run single test method
bundle exec rails test test/controllers/console_controller_test.rb -n test_should_execute_simple_ruby_command

# Debug system tests
HEADLESS=false bundle exec rails test:system -n test_executing_simple_commands
```

## Test Maintenance

### Regular Tasks
- Update test data when models change
- Review and update security tests
- Performance benchmark updates
- Browser compatibility testing

### When Adding Features
- Add corresponding tests for new functionality
- Update integration tests for new workflows
- Add security tests for new permissions
- Update documentation

### Code Coverage Goals
- Controller: 100% line coverage
- Helpers: 100% line coverage  
- Integration: Key workflows covered
- System: Critical user paths tested

## Test Environment Configuration

Ensure these settings in `config/environments/test.rb`:

```ruby
Rails.application.configure do
  # Console should be available in test environment
  config.console_enabled = true
  
  # Faster tests
  config.cache_classes = true
  config.eager_load = false
  
  # Test-specific settings
  config.action_dispatch.show_exceptions = false
  config.action_controller.allow_forgery_protection = false
end
```
