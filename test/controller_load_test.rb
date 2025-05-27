#!/usr/bin/env ruby

require_relative '../config/environment'

puts "Testing controller loading..."

begin
  controller = ConsoleController.new
  puts "✓ ConsoleController loaded successfully"
  
  # Check if new methods exist
  methods = controller.methods - Object.methods
  session_methods = methods.select { |m| m.to_s.include?('session') }
  puts "Session-related methods: #{session_methods}"
  
  # Test initialize_sessions method
  if controller.respond_to?(:initialize_sessions, true)
    puts "✓ initialize_sessions method exists"
  else
    puts "✗ initialize_sessions method missing"
  end
  
rescue => e
  puts "✗ Error loading controller: #{e.message}"
  puts e.backtrace.first(5)
end
