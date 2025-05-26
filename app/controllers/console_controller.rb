class ConsoleController < ApplicationController
  # Console execution context
  class ConsoleContext
    def initialize
      # Make Rails application available
      @app = Rails.application
    end
    
    # Access to Rails application
    def app
      @app
    end
    
    # Reload method (safe version)
    def reload!
      "Application reload is not supported in web console for safety reasons"
    end
    
    # Helper method for model listing
    def models
      ApplicationRecord.descendants.map(&:name).sort
    end
    
    # Helper method for routes
    def routes
      Rails.application.routes.routes.map do |route|
        {
          verb: route.verb,
          path: route.path.spec.to_s,
          controller_action: route.defaults[:controller] ? "#{route.defaults[:controller]}##{route.defaults[:action]}" : nil
        }.compact
      end.first(20) # Limit to first 20 routes
    end
    
    # Method missing to delegate to main object if safe
    def method_missing(method_name, *args, &block)
      if safe_method?(method_name)
        Object.send(method_name, *args, &block)
      else
        super
      end
    end
    
    def respond_to_missing?(method_name, include_private = false)
      safe_method?(method_name) || super
    end
    
    private
    
    def safe_method?(method_name)
      # Allow certain safe methods to be called
      safe_methods = %w[puts p pp print require_relative]
      safe_methods.include?(method_name.to_s) || 
      method_name.to_s.match?(/\A[A-Z][a-zA-Z0-9_]*\z/) # Allow constant access
    end
  end
  
  # Skip CSRF protection for AJAX requests
  skip_before_action :verify_authenticity_token, only: [:execute]
  
  # Basic authentication - you might want to implement proper auth
  before_action :authenticate_console_user
  
  def index
    @command_history = session[:console_history] || []
  end
  
  def execute
    command = params[:command]&.strip
    
    return render json: { error: "Command cannot be empty" }, status: 400 if command.blank?
    
    # Security check - basic command filtering
    if dangerous_command?(command)
      return render json: { error: "Command not allowed for security reasons" }, status: 403
    end
    
    begin
      # Store command in session history
      session[:console_history] ||= []
      session[:console_history] << command
      session[:console_history] = session[:console_history].last(50) # Keep last 50 commands
      
      # Execute the command in a safe context
      result = execute_safe_command(command)
      
      render json: {
        command: command,
        result: format_result(result),
        timestamp: Time.current.to_s
      }
    rescue => e
      render json: {
        command: command,
        error: e.message,
        error_class: e.class.name,
        timestamp: Time.current.to_s
      }
    end
  end
  
  def clear_history
    session[:console_history] = []
    render json: { message: "History cleared" }
  end
  
  private
  
  def authenticate_console_user
    # Basic authentication - replace with your auth system
    # For development, you might want to restrict this to certain environments
    unless Rails.env.development?
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
  
  def execute_safe_command(command)
    # Create a safe execution context
    context = ConsoleContext.new
    context.instance_eval(command)
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
      result
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
end
