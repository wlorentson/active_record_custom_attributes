module ActiveRecord
  
  module CustomFinders
    def self.included(base) # :nodoc:
      base.extend ClassMethods
    end
    
    module ClassMethods

      #Returns an array of objects of our instance with a given value for a given field
      # def find_by_custom_attribute(fieldname, value)
      #   fieldname = fieldname.to_s
      #   value = value.to_s
      #   f = AttributeField.find_by_name(fieldname)
      #   o = AttributeObject.find_by_name self.table_name.to_s
      #   return [] unless f && o
      #   values = AttributeValue.find(:all, :conditions => {:obj_id => o.id, :field_id => f.id, :value => value})
      #   return self.find(values.map(&:instance_id)) 
      # end
      

      # This one is faster by a factor of about 10x (10,000 tries)
      #
      #                    user     system      total        real
      # custom_find:  38.930000   2.520000  41.450000 ( 49.222400)  
      # custom_find2:  3.130000   0.400000   3.530000 (  5.705937)
      #   
      def find_by_custom_attribute(fieldname, value, extra_conditions = '')
        table_name = self.table_name
        
        self.find_by_sql("
          SELECT obj.*, av.value AS #{fieldname} FROM #{table_name} AS obj
          	INNER JOIN attribute_values AS av
          	INNER JOIN attribute_fields AS af ON af.obj_id = av.obj_id
          	INNER JOIN attribute_objects AS ao ON ao.id = av.obj_id
          WHERE ao.name = '#{table_name}' AND af.name = '#{fieldname}' AND av.value = '#{value}' AND av.instance_id = obj.id
          #{'AND ' + extra_conditions unless extra_conditions.blank?}
        ")
      end
      
    end 
  end
  
end