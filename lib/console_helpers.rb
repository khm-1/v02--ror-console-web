# Console Helper for Web Console
# This file contains helper methods available in the web console

module ConsoleHelpers
  # Show all routes
  def routes
    Rails.application.routes.routes.map do |route|
      {
        verb: route.verb,
        path: route.path.spec.to_s,
        controller: route.defaults[:controller],
        action: route.defaults[:action]
      }
    end
  end
  
  # Show all models
  def models
    Rails.application.eager_load!
    ApplicationRecord.descendants.map(&:name)
  end
  
  # Show model info
  def model_info(model_class)
    return "Model not found" unless model_class.is_a?(Class) && model_class < ApplicationRecord
    
    {
      table_name: model_class.table_name,
      columns: model_class.column_names,
      associations: model_class.reflect_on_all_associations.map { |a| "#{a.macro} :#{a.name}" },
      validations: model_class.validators.map(&:class).uniq,
      count: model_class.count
    }
  end
  
  # Show database info
  def db_info
    {
      adapter: ActiveRecord::Base.connection.adapter_name,
      database: ActiveRecord::Base.connection.current_database,
      tables: ActiveRecord::Base.connection.tables,
      version: ActiveRecord::Base.connection.select_value("SELECT version()")
    }
  rescue
    { error: "Unable to retrieve database information" }
  end
  
  # Show environment info
  def env_info
    {
      rails_env: Rails.env,
      rails_version: Rails::VERSION::STRING,
      ruby_version: RUBY_VERSION,
      gem_count: Gem.loaded_specs.count,
      load_path: $LOAD_PATH.first(5)
    }
  end
  
  # Quick find records
  def find_by(model, conditions)
    return "Invalid model" unless model.is_a?(Class) && model < ApplicationRecord
    model.where(conditions).limit(10)
  rescue => e
    "Error: #{e.message}"
  end
  
  # Show last N records
  def last_records(model, count = 5)
    return "Invalid model" unless model.is_a?(Class) && model < ApplicationRecord
    model.last(count)
  rescue => e
    "Error: #{e.message}"
  end
  
  # Show application config
  def app_config
    config = Rails.application.config
    {
      cache_classes: config.cache_classes,
      eager_load: config.eager_load,
      log_level: config.log_level,
      time_zone: config.time_zone,
      encoding: config.encoding
    }
  end
  
  # Helper to reload application (safe version)
  def safe_reload
    "Application reload disabled for safety in web console. Restart the server instead."
  end
  
  # Show memory usage
  def memory_info
    if defined?(GC)
      {
        gc_count: GC.count,
        gc_stat: GC.stat.slice(:count, :heap_allocated_pages, :total_allocated_objects),
        object_count: ObjectSpace.count_objects
      }
    else
      { error: "GC not available" }
    end
  end
  
  # Show table information
  def table_info(table_name)
    return "Invalid table name" unless table_name.is_a?(String)
    connection = ActiveRecord::Base.connection
    return "Table not found" unless connection.table_exists?(table_name)
    
    {
      columns: connection.columns(table_name).map { |c| { name: c.name, type: c.type, null: c.null } },
      indexes: connection.indexes(table_name).map { |i| { name: i.name, columns: i.columns, unique: i.unique } }
    }
  rescue => e
    "Error: #{e.message}"
  end
  
  # Show connection information
  def connection_info
    connection = ActiveRecord::Base.connection
    {
      adapter: connection.adapter_name,
      database: connection.current_database,
      pool_size: ActiveRecord::Base.connection_pool.size,
      active_connections: ActiveRecord::Base.connection_pool.connections.count
    }
  rescue => e
    { error: "Unable to retrieve connection information: #{e.message}" }
  end
  
  # Show cache information
  def cache_info
    cache = Rails.cache
    {
      cache_store: cache.class.name,
      stats: cache.respond_to?(:stats) ? cache.stats : "Stats not available"
    }
  rescue => e
    { error: "Unable to retrieve cache information: #{e.message}" }
  end
  
  # Show session information
  def session_info
    {
      session_store: ActionDispatch::Session::CookieStore,
      secret_key_base: Rails.application.secret_key_base ? "Set" : "Not set"
    }
  rescue => e
    { error: "Unable to retrieve session information: #{e.message}" }
  end
end
