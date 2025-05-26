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
  def find_by(model, **conditions)
    model.where(conditions).limit(10)
  end
  
  # Show last N records
  def last_records(model, count = 5)
    model.last(count)
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
end
