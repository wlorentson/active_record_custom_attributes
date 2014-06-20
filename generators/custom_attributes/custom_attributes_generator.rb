class CustomAttributesGenerator < Rails::Generator::Base
  
  def manifest
    record do |m|
      m.migration_template 'migrate/create_custom_attributes.rb', 'db/migrate'
    end
  end
  
  def file_name
    "create_custom_attributes"
  end
  
end