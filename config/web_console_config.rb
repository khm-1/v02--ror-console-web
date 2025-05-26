# Configuration for Rails Web Console
module WebConsoleConfig
  # Security settings
  ALLOWED_ENVIRONMENTS = %w[development test].freeze
  
  # Command restrictions
  BLOCKED_COMMANDS = [
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
  ].freeze
  
  # Output formatting limits
  MAX_ARRAY_ITEMS = 10
  MAX_HASH_KEYS = 10
  MAX_STRING_LENGTH = 1000
  MAX_HISTORY_ITEMS = 50
  
  # Console features
  FEATURES = {
    command_history: true,
    syntax_highlighting: true,
    auto_completion: false, # Not implemented yet
    session_persistence: true
  }.freeze
end
