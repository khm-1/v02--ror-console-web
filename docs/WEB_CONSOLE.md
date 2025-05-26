# Rails Web Console

A web-based interface for the Rails console that allows you to execute Ruby/Rails commands through your browser.

## Features

- **Safe Command Execution**: Built-in security measures to prevent dangerous operations
- **Command History**: Navigate through previous commands using arrow keys
- **Syntax Highlighting**: Clean, readable output with color coding
- **Session Persistence**: Command history persists across browser sessions
- **Rails Integration**: Access to all Rails models, helpers, and application context
- **Real-time Execution**: AJAX-based command execution without page reloads

## Usage

### Accessing the Console

1. Start your Rails server in development mode:
   ```bash
   rails server
   ```

2. Navigate to: `http://localhost:3000/console`

3. Start typing Ruby/Rails commands in the input field

### Available Commands

#### Basic Rails Commands
```ruby
# Model operations
Post.all
Post.count
Post.first
Post.create(title: "Test", content: "Content")

# Route inspection
routes

# Model information
models
model_info(Post)

# Environment details
env_info
db_info
app_config
```

#### Helper Methods
The console includes several helper methods:

- `models` - List all application models
- `routes` - Display all application routes
- `model_info(ModelClass)` - Get detailed information about a model
- `env_info` - Show environment and version information
- `db_info` - Display database connection details
- `memory_info` - Show memory usage statistics
- `find_by(Model, conditions)` - Quick record lookup
- `last_records(Model, count)` - Show recent records

### Keyboard Shortcuts

- **Enter**: Execute command
- **↑/↓**: Navigate command history
- **Ctrl+L**: Clear output
- **Click on history items**: Reuse previous commands

### Security Features

The web console includes several security measures:

1. **Environment Restrictions**: Only available in development and test environments
2. **Command Filtering**: Blocks dangerous system commands and file operations
3. **Safe Evaluation**: Commands run in a controlled binding context
4. **No Server Modifications**: Cannot restart or modify the Rails application

### Blocked Commands

For security reasons, the following types of commands are blocked:

- System commands (`system`, `exec`, backticks)
- File manipulation (`File.delete`, `FileUtils.rm`)
- Process control (`exit`, `quit`, `fork`)
- Dynamic code evaluation (`eval`, `instance_eval`)
- File loading (`load`, `require`)

## Architecture

### Components

1. **ConsoleController** (`app/controllers/console_controller.rb`)
   - Handles command execution and security
   - Manages session history
   - Formats output for web display

2. **Console View** (`app/views/console/index.html.erb`)
   - Terminal-like web interface
   - JavaScript for interactive features
   - CSS for VS Code-like styling

3. **Console Helpers** (`lib/console_helpers.rb`)
   - Utility methods for common Rails operations
   - Enhanced inspection and debugging tools

4. **Configuration** (`config/web_console_config.rb`)
   - Security settings and restrictions
   - Feature flags and limits

### Routes

```ruby
get "console", to: "console#index"
post "console/execute", to: "console#execute"
delete "console/clear_history", to: "console#clear_history"
```

## Customization

### Adding Custom Helper Methods

Add methods to `lib/console_helpers.rb`:

```ruby
module ConsoleHelpers
  def my_custom_helper
    # Your custom logic here
  end
end
```

### Modifying Security Rules

Edit `config/web_console_config.rb` to adjust blocked commands or limits:

```ruby
BLOCKED_COMMANDS = [
  # Add your custom restrictions
].freeze
```

### Styling

The console uses inline CSS for simplicity. To customize the appearance, modify the `<style>` section in `app/views/console/index.html.erb`.

## Development Notes

### Future Enhancements

- [ ] Auto-completion for Rails methods and models
- [ ] Syntax highlighting for input
- [ ] Multiple console tabs/sessions
- [ ] File browser integration
- [ ] Export command history
- [ ] Integration with Rails logger
- [ ] Performance monitoring
- [ ] Database query visualization

### Known Limitations

- No auto-completion (yet)
- Limited to text-based output
- Session history not persistent across server restarts
- No support for multi-line commands
- Cannot handle interactive commands (like debugger)

## Security Considerations

This web console is designed for development use only. Do not enable in production environments. The security measures are intended to prevent accidental damage but should not be considered production-grade security.

## Troubleshooting

### Console Not Loading
- Ensure you're in development environment
- Check that the server is running
- Verify routes are properly configured

### Commands Not Executing
- Check browser console for JavaScript errors
- Verify CSRF token is present
- Ensure command doesn't match blocked patterns

### Permission Errors
- Confirm you're accessing from an allowed environment
- Check that required gems are installed

## Contributing

To enhance the web console:

1. Add new helper methods to `ConsoleHelpers`
2. Improve the user interface in the view template
3. Enhance security measures in the controller
4. Add new features like auto-completion or syntax highlighting
