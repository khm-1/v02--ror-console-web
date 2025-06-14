class ConsoleController < ApplicationController
  require 'securerandom'
  
  # Console execution context
  class ConsoleContext
    # Include the console helpers module
    require_relative '../../lib/console_helpers'
    include ConsoleHelpers
    
    def initialize(session_variables = {})
      # Make Rails application available
      @app = Rails.application
      @session_variables = session_variables || {}
      @session_variables = {} unless @session_variables.is_a?(Hash)
    end
    
    # Access to Rails application
    def app
      @app
    end
    
    # Reload method (safe version)
    def reload!
      "Application reload is not supported in web console for safety reasons"
    end
    
    # Method to show current variables
    def vars
      if @session_variables.empty?
        "No variables defined"
      else
        @session_variables.map { |k, v| "#{k} = #{v.inspect}" }.join("\n")
      end
    end
    
    # Method to get session variables
    def session_variables
      @session_variables
    end
    
    # Method missing to handle session variable access
    def method_missing(method_name, *args, &block)
      method_str = method_name.to_s
      
      # Check if it's a variable assignment (ends with =)
      if method_str.end_with?('=')
        var_name = method_str[0..-2] # Remove the = 
        @session_variables[var_name] = args.first
        return args.first
      end
      
      # Check if it's a session variable access
      if @session_variables.key?(method_str)
        return @session_variables[method_str]
      end
      
      # Delegate to safe methods or super
      if safe_method?(method_name)
        Object.send(method_name, *args, &block)
      else
        raise NameError, "undefined local variable or method `#{method_name}'"
      end
    end
    
    def respond_to_missing?(method_name, include_private = false)
      method_str = method_name.to_s
      # Respond to session variables, variable assignments, or safe methods
      @session_variables.key?(method_str) || 
      method_str.end_with?('=') || 
      safe_method?(method_name) || 
      super
    end
    
    private
    
    def safe_method?(method_name)
      # Allow certain safe methods to be called
      safe_methods = %w[puts p pp print require_relative]
      safe_methods.include?(method_name.to_s) || 
      method_name.to_s.match?(/\A[A-Z][a-zA-Z0-9_]*\z/) # Allow constant access
    end
  end
  
  # Sandbox execution context - more restricted than ConsoleContext
  class SandboxContext
    def initialize(session_variables = {})
      @session_variables = session_variables || {}
    end
    
    # Method to show current variables
    def vars
      if @session_variables.empty?
        "No variables defined"
      else
        @session_variables.map { |k, v| "#{k} = #{v.inspect}" }.join("\n")
      end
    end
    
    # Method to show sandbox info
    def sandbox_info
      "🏖️  SANDBOX MODE: Database changes will be automatically rolled back.\nYou can safely experiment with data without affecting the real database!"
    end
    
    # Method to get session variables
    def session_variables
      @session_variables
    end
    
    # Method missing to handle session variable access and Rails model access
    def method_missing(method_name, *args, &block)
      method_str = method_name.to_s
      
      # Check if it's a variable assignment (ends with =)
      if method_str.end_with?('=')
        var_name = method_str[0..-2] # Remove the = 
        @session_variables[var_name] = args.first
        return args.first
      end
      
      # Check if it's a session variable access first
      if @session_variables.key?(method_str)
        return @session_variables[method_str]
      end
      
      # Allow access to Rails models and constants (like Post, User, etc.)
      # But only if it looks like a constant (starts with capital letter)
      if method_str.match?(/\A[A-Z]/) && Object.const_defined?(method_str)
        return Object.const_get(method_str)
      end
      
      # Allow basic safe methods
      if sandbox_safe_method?(method_name)
        if args.empty? && !block_given?
          # Handle method calls without arguments
          super
        else
          Object.send(method_name, *args, &block)
        end
      else
        raise NameError, "undefined local variable or method `#{method_name}' for sandbox mode"
      end
    end
    
    def respond_to_missing?(method_name, include_private = false)
      method_str = method_name.to_s
      # Respond to session variables, variable assignments, constants (capitalized), or sandbox safe methods
      @session_variables.key?(method_str) || 
      method_str.end_with?('=') || 
      (method_str.match?(/\A[A-Z]/) && Object.const_defined?(method_str)) ||
      sandbox_safe_method?(method_name) || 
      super
    end
    
    private
    
    def sandbox_safe_method?(method_name)
      # Allow basic safe methods and operations
      safe_methods = %w[puts p pp print to_s inspect class + - * / % ** == != < > <= >= <=> & | ^ ~ << >> && ||]
      method_str = method_name.to_s
      
      # Block dangerous classes and methods that could bypass sandbox
      blocked_patterns = [
        /\AFile\z/, /\ADir\z/, /\AIO\z/, /\AKernel\z/, /\AClass\z/, /\AModule\z/,
        /\Asystem\z/, /\Aexec\z/, /\Aeval\z/, /\Arequire\z/, /\Aload\z/
      ]
      
      return false if blocked_patterns.any? { |pattern| method_str.match?(pattern) }
      
      # Allow basic safe methods, numeric operations, and literals
      safe_methods.include?(method_str) ||
      method_str.match?(/\A[0-9]+\z/) || # Allow numeric literals
      method_str.match?(/\A(true|false|nil)\z/) || # Allow boolean/nil literals
      method_str.match?(/\A(String|Integer|Float|Array|Hash|TrueClass|FalseClass|NilClass|Numeric)\z/) # Allow basic class access
    end
  end
  
  # Skip CSRF protection for AJAX requests
  skip_before_action :verify_authenticity_token, only: [:execute, :new_session, :session_list, :select_session, :close_session]
  
  # Basic authentication - you might want to implement proper auth
  before_action :authenticate_console_user
  
  def index
    initialize_sessions
    @command_history = current_session_history
    @current_session_id = session[:current_console_session_id]
    @console_sessions = session[:console_sessions]
  end
  
  # Session management methods
  def new_session
    initialize_sessions
    
    session_id = SecureRandom.hex(8)
    session_name = params[:name] || "Session #{session_id[0..3]}"
    
    new_session_data = {
      "id" => session_id,
      "name" => session_name,
      "history" => [],
      "variables" => {},
      "created_at" => Time.current.to_s,
      "last_active" => Time.current.to_s
    }
    
    session[:console_sessions][session_id] = new_session_data
    
    # Switch to new session
    session[:current_console_session_id] = session_id
    
    render json: {
      message: "New console session created",
      session: new_session_data,
      active_session_id: session_id
    }
  end
  
  def session_list
    initialize_sessions
    
    sessions = session[:console_sessions].values.map do |sess|
      {
        id: sess["id"],
        name: sess["name"],
        created_at: sess["created_at"],
        last_active: sess["last_active"],
        history: sess["history"] || [],
        variables: sess["variables"] || {},
        command_count: (sess["history"] || []).length,
        variable_count: (sess["variables"] || {}).keys.length,
        is_active: sess["id"] == session[:current_console_session_id]
      }
    end
    
    current_session = session[:console_sessions][session[:current_console_session_id]]
    
    render json: {
      sessions: sessions,
      current_session: current_session,
      active_session_id: session[:current_console_session_id],
      total_sessions: sessions.length
    }
  end
  
  def select_session
    initialize_sessions
    
    session_id = params[:session_id] || params[:id]
    
    unless session[:console_sessions].key?(session_id)
      return render json: { error: "Session not found" }, status: 404
    end
    
    # Update last active time for new session
    session[:console_sessions][session_id]["last_active"] = Time.current.to_s
    
    # Switch to selected session
    session[:current_console_session_id] = session_id
    
    selected_session = session[:console_sessions][session_id]
    
    render json: {
      message: "Switched to session",
      session: selected_session,
      active_session_id: session_id,
      history: selected_session["history"] || [],
      variables: selected_session["variables"] || {}
    }
  end
  
  def close_session
    initialize_sessions
    
    session_id = params[:session_id] || params[:id]
    
    unless session[:console_sessions].key?(session_id)
      return render json: { error: "Session not found" }, status: 404
    end
    
    # Don't allow closing the last session
    if session[:console_sessions].keys.length == 1
      return render json: { error: "Cannot close the last session" }, status: 400
    end
    
    # Remove the session
    closed_session = session[:console_sessions].delete(session_id)
    
    # If we're closing the active session, switch to another one
    switched_to_session = nil
    if session[:current_console_session_id] == session_id
      session[:current_console_session_id] = session[:console_sessions].keys.first
      switched_to_session = session[:console_sessions][session[:current_console_session_id]]
    end
    
    render json: {
      message: "Session closed",
      closed_session: closed_session,
      switched_to: switched_to_session,
      active_session_id: session[:current_console_session_id],
      remaining_sessions: session[:console_sessions].keys.length
    }
  end
  
  def execute
    command = params[:command]&.strip
    
    return render json: { error: "Command cannot be empty" }, status: 400 if command.blank?
    
    # Security check - basic command filtering
    if dangerous_command?(command)
      return render json: { error: "Command not allowed for security reasons" }, status: 403
    end
    
    begin
      initialize_sessions
      current_session = get_current_session
      
      # Store command in current session history
      current_session["history"] ||= []
      current_session["history"] << command
      current_session["history"] = current_session["history"].last(50) # Keep last 50 commands
      current_session["last_active"] = Time.current.to_s
      
      # Update session in the main sessions hash
      session[:console_sessions][session[:current_console_session_id]] = current_session
      
      # Execute the command in a safe context
      result = execute_safe_command(command, current_session)
      
      render json: {
        command: command,
        result: format_result(result),
        timestamp: Time.current.to_s,
        session_id: session[:current_console_session_id]
      }
    rescue => e
      render json: {
        command: command,
        error: e.message,
        error_class: e.class.name,
        timestamp: Time.current.to_s,
        session_id: session[:current_console_session_id]
      }
    end
  end
  
  def clear_history
    initialize_sessions
    current_session = get_current_session
    
    current_session["history"] = []
    current_session["variables"] = {} # Also clear variables
    current_session["last_active"] = Time.current.to_s
    
    # Update session in the main sessions hash
    session[:console_sessions][session[:current_console_session_id]] = current_session
    
    render json: { 
      message: "History and variables cleared for current session",
      session_id: session[:current_console_session_id]
    }
  end
  
  # Sandbox mode - more restricted console
  def sandbox
    @command_history = session[:sandbox_history] || []
    @sandbox_mode = true
    render :index
  end
  
  def sandbox_execute
    command = params[:command]&.strip
    
    return render json: { error: "Command cannot be empty" }, status: 400 if command.blank?
    
    # Enhanced security check for sandbox mode
    if dangerous_command?(command) || sandbox_restricted_command?(command)
      return render json: { error: "Command not allowed in sandbox mode" }, status: 403
    end
    
    begin
      # Store command in sandbox session history
      session[:sandbox_history] ||= []
      session[:sandbox_history] << command
      session[:sandbox_history] = session[:sandbox_history].last(50)
      
      # Execute the command in sandbox context
      result = execute_sandbox_command(command)
      
      render json: {
        command: command,
        result: format_result(result),
        timestamp: Time.current.to_s,
        mode: "sandbox"
      }
    rescue SecurityError => e
      render json: {
        command: command,
        error: "undefined local variable or method for sandbox mode",
        error_class: "NameError",
        timestamp: Time.current.to_s,
        mode: "sandbox"
      }
    rescue => e
      render json: {
        command: command,
        error: e.message,
        error_class: e.class.name,
        timestamp: Time.current.to_s,
        mode: "sandbox"
      }
    end
  end
  
  def sandbox_clear_history
    session[:sandbox_history] = []
    session[:sandbox_variables] = {}
    render json: { message: "Sandbox history and variables cleared" }
  end

  private
  
  def authenticate_console_user
    # Basic authentication - replace with your auth system
    # For development and test, you might want to restrict this to certain environments
    unless Rails.env.development? || Rails.env.test?
      render plain: "Console access not allowed in this environment", status: 403
    end
  end
  
  def dangerous_command?(command)
    # List of dangerous commands/patterns to block
    dangerous_patterns = [
      /system\s*\(/i,
      /exec\s*\(/i,
      /`.*`/,
      /%x\{/,
      /File\.delete/i,
      /File\.unlink/i,
      /FileUtils\.rm/i,
      /Dir\.rmdir/i,
      /exit/i,
      /quit/i,
      /fork/i,
      /spawn/i,
      /eval\s*\(/i,
      /instance_eval/i,
      /class_eval/i,
      /module_eval/i,
      /define_method/i,
      /remove_method/i,
      /undef_method/i,
      /load\s*\(/i,
      /require\s*\(/i
    ]
    
    dangerous_patterns.any? { |pattern| command.match?(pattern) }
  end
  
  def sandbox_restricted_command?(command)
    # Additional restricted commands for sandbox mode
    restricted_patterns = [
      /chown\s+/i,
      /chmod\s+/i,
      /rm\s+-rf/i,
      /cp\s+-r/i,
      /mv\s+/i,
      /ln\s+/i,
      /tail\s+/i,
      /head\s+/i,
      /cat\s+/i,
      /less\s+/i,
      /more\s+/i,
      /nano\s+/i,
      /vim\s+/i,
      /emacs\s+/i,
      /gedit\s+/i,
      /open\s+/i,
      /xdg-open\s+/i,
      /kill\s+/i,
      /pkill\s+/i,
      /killall\s+/i,
      /shutdown\s+/i,
      /reboot\s+/i,
      /halt\s+/i,
      /poweroff\s+/i
    ]
    
    restricted_patterns.any? { |pattern| command.match?(pattern) }
  end
  
  def sandbox_command_restricted?(command)
    # Additional sandbox-specific restrictions
    sandbox_restricted_patterns = [
      /File\./i,
      /Dir\./i,
      /IO\./i,
      /Object\./i,
      /Class\./i,
      /Module\./i,
      /Kernel\./i,
      /require\s*\(/i,
      /load\s*\(/i,
      /eval\s*\(/i,
      /instance_eval\s*\(/i,
      /class_eval\s*\(/i,
      /module_eval\s*\(/i
    ]
    
    sandbox_restricted_patterns.any? { |pattern| command.match?(pattern) }
  end
  
  def execute_safe_command(command, current_session = nil)
    # Use provided session or get current session
    current_session ||= get_current_session
    
    # Get session variables from current session and ensure it's a hash
    session_variables = current_session["variables"] || {}
    session_variables = {} unless session_variables.is_a?(Hash)
    
    # Create a safe execution context with session variables
    context = ConsoleContext.new(session_variables)
    
    # Check if this is a variable assignment
    if match = command.match(/\A\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+)\z/)
      # Handle variable assignment manually
      var_name = match[1].strip
      expression = match[2].strip
      
      # Evaluate the right-hand side expression first
      value = context.instance_eval(expression)
      
      # Store the variable in context
      context.session_variables[var_name] = value
      
      # Store updated session variables back to current session
      current_session["variables"] = context.session_variables
      
      # Update session in the main sessions hash
      session[:console_sessions][session[:current_console_session_id]] = current_session
      
      return value
    else
      # For variable access and other expressions, use instance_eval
      result = context.instance_eval(command)
      
      # Store updated session variables back to current session (in case new variables were created)
      current_session["variables"] = context.session_variables
      
      # Update session in the main sessions hash
      session[:console_sessions][session[:current_console_session_id]] = current_session
      
      result
    end
  end
  
  def execute_sandbox_command(command)
    # Enhanced security check for specific sandbox restrictions
    if sandbox_command_restricted?(command)
      raise SecurityError, "Command contains restricted operations for sandbox mode"
    end
    
    # Initialize sandbox variables from session
    session[:sandbox_variables] ||= {}
    
    # Check if this is a variable assignment
    assignment_match = command.match(/^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+)$/)
    
    # Execute in a database transaction that always rolls back to prevent persistent changes
    result = nil
    ActiveRecord::Base.transaction do
      # Create sandbox context with session variables
      context = SandboxContext.new(session[:sandbox_variables])
      
      # Evaluate the command in the sandbox context
      result = context.instance_eval(command)
      
      # If this was an assignment, capture the assigned value
      if assignment_match
        var_name = assignment_match[1]
        session[:sandbox_variables][var_name] = context.instance_variable_get("@#{var_name}") || result
      else
        # Store any new variables that might have been created
        session[:sandbox_variables] = context.session_variables
      end
      
      # Always rollback the transaction to prevent database changes
      raise ActiveRecord::Rollback
    end
    
    result
  end
  
  def create_safe_binding
    # Create a binding with access to Rails console features
    console_binding = binding
    
    # You can add helper methods here
    console_binding.local_variable_set(:app, Rails.application)
    
    # Define reload! method in the binding context
    console_binding.define_singleton_method(:reload!) do
      reload_application
    end
    
    console_binding
  end
  
  def reload_application
    "Application reload is not supported in web console for safety reasons"
  end
  
  def format_result(result)
    case result
    when String
      # Check if this looks like formatted console output (contains " = " pattern)
      # If so, don't add quotes around it
      if result.include?(" = ") && result.count("\n") > 0
        result
      else
        # For regular strings, return them without quotes for compatibility
        # This maintains backward compatibility with existing tests
        result
      end
    when NilClass
      "nil"
    when TrueClass, FalseClass
      result.to_s
    when Numeric
      result.to_s
    when Array
      if result.length > 10
        formatted = result.first(10).map { |item| format_single_item(item) }
        formatted << "... (#{result.length - 10} more items)"
        formatted
      else
        result.map { |item| format_single_item(item) }
      end
    when Hash
      if result.keys.length > 10
        limited_hash = result.first(10).to_h
        limited_hash["..."] = "(#{result.keys.length - 10} more keys)"
        format_hash(limited_hash)
      else
        format_hash(result)
      end
    when ActiveRecord::Base
      format_activerecord_object(result)
    when ActiveRecord::Relation
      format_activerecord_relation(result)
    else
      result.inspect
    end
  end
  
  def format_single_item(item)
    case item
    when ActiveRecord::Base
      "#<#{item.class.name} id: #{item.id}>"
    when String
      item.length > 100 ? "#{item[0..97]}..." : item
    else
      item.inspect
    end
  end
  
  def format_hash(hash)
    hash.map { |k, v| "#{k.inspect} => #{format_single_item(v)}" }
  end
  
  def format_activerecord_object(obj)
    attributes = obj.attributes.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
    "#<#{obj.class.name} #{attributes}>"
  end
  
  def format_activerecord_relation(relation)
    count = relation.count
    if count > 5
      sample = relation.limit(5).map { |record| format_single_item(record) }
      sample << "... (#{count - 5} more records)"
      sample
    else
      relation.map { |record| format_single_item(record) }
    end
  end
  
  def initialize_sessions
    # Initialize console sessions structure if it doesn't exist
    session[:console_sessions] ||= {}
    
    # Create default session if none exist
    if session[:console_sessions].empty?
      default_session_id = SecureRandom.hex(8)
      session[:console_sessions][default_session_id] = {
        "id" => default_session_id,
        "name" => "Default Session",
        "history" => session[:console_history] || [],
        "variables" => session[:console_variables] || {},
        "created_at" => Time.current.to_s,
        "last_active" => Time.current.to_s
      }
      session[:current_console_session_id] = default_session_id
      
      # Clean up old session data
      session.delete(:console_history)
      session.delete(:console_variables)
    end
    
    # Ensure we have a current session
    unless session[:current_console_session_id] && session[:console_sessions].key?(session[:current_console_session_id])
      session[:current_console_session_id] = session[:console_sessions].keys.first
    end
  end
  
  def get_current_session
    initialize_sessions
    current_session = session[:console_sessions][session[:current_console_session_id]]
    
    # Ensure the session has the required structure
    current_session["history"] ||= []
    current_session["variables"] ||= {}
    
    current_session
  end
  
  def current_session_history
    get_current_session["history"] || []
  end
end
