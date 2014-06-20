class CreateCustomAttributeTables < ActiveRecord::Migration

  def self.up
    # VALUES
    create_table :attribute_values, :force => true do |t|
      t.string :value
      t.integer :field_id
      t.integer :object_id
      t.integer :instance_id
      t.timestamps
    end
    add_index :attribute_values, :field_id
    add_index :attribute_values, :object_id
    add_index :attribute_values, :instance_id

    # FIELD NAMES -- these are things like 'email' or 'hair_color'
    create_table :attribute_fields, :force => true do |t|
      t.integer :object_id
      t.string :name
    end
    add_index :attribute_fields, :object_id

    # OBJECT NAMES -- these are classes
    create_table :attribute_objects, :force => true do |t|
      t.string :name
    end
  end

  def self.down
    drop_table :attribute_values
    drop_table :attribute_fields
    drop_table :attribute_objects
  end

end

