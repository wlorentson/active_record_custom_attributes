module ActiveRecord

  class CustomAttributes < Base
    self.abstract_class = true

    # # # # # # # # # # # # # # #
    #  Class Methods            #
    # # # # # # # # # # # # # # #
    def self.reserved_custom_attribute(attr, options = {})
      attr = attr.to_s
      raise "Attribute #{attr} could not be added because it conflicted with an existing attribute or function" unless verify_attribute_name_okay(attr)
      @reserved_custom_attributes ||= {}
      @reserved_custom_attributes[attr] = options
    end

    def self.verify_attribute_name_okay(attr)
      begin
        return false if self.methods.include? attr #class method collisions
        return false if self.new.methods.include? attr #instance method collisions
        return true
      rescue #Mysql::Error
        # If we're trying to run the migration that creates our table, this check can create a chicken-egg error.
        # We'll note the mysql error, but ignore it.
        puts "Warning - skipping potentially invalid custom attribute #{attr}"
        return true
      end
    end

    def self.reserved_custom_attributes
      @reserved_custom_attributes ||= {}
    end

    def self.reserved_custom_attribute_names
      @reserved_custom_attributes.keys
    end

    def self.unique_custom_attributes
      @unique_custom_attributes ||= []
    end

    def self.default_custom_attribute(fieldname)
      @reserved_custom_attributes ||= {}
      options = @reserved_custom_attributes[fieldname]
      return options[:default] if options
      return nil
    end

    # # # # # # # # # # # # # # #
    #  Custom Attributes        #
    # # # # # # # # # # # # # # #

    def custom_attributes
      @custom_attributes_cache ||= load_custom_attributes
    end

    def get_custom_attribute(fieldname)
      load_custom_attributes unless @custom_attributes_are_loaded
      return nil unless fieldname
      fieldname = fieldname.to_s if fieldname.is_a?(Symbol) # in case you passed in a :symbol
      if @custom_attributes_cache[fieldname]
        return @custom_attributes_cache[fieldname]
      else
        default = self.class.default_custom_attribute(fieldname)
        if default
          write_custom_attribute(fieldname, default)
        end
        return default #could be nil
      end
    end

    def load_custom_attributes
      @custom_attributes_cache ||= {}
      @custom_attributes_are_loaded = false
      return unless self.id
      sql = ActiveRecord::Base.connection();
      select = "f.name AS field_name, v.value AS field_value"
      from = "attribute_values v JOIN attribute_fields f ON v.field_id = f.id JOIN attribute_objects o ON v.obj_id = o.id "
      where = "o.name = '#{self.class.table_name.to_s}' AND v.instance_id = #{self.id}"
      sql_res = sql.execute "SELECT #{select} FROM #{from} WHERE #{where} ORDER BY f.name, v.value"
      res = {}
      sql_res.all_hashes.each { |hash|
        res[hash["field_name"]] = hash["field_value"]
      }
      sql_res.free

      @custom_attributes_are_loaded = true
      @custom_attributes_cache = res
    end

    def set_custom_attribute(fieldname, value)
      return unless fieldname
      fieldname = fieldname.to_s if fieldname.is_a?(Symbol) # in case you passed in a :symbol
      @custom_attributes_cache ||= {}

      @custom_attributes_cache[fieldname] = value
    end

    def write_custom_attributes
      @custom_attributes_cache ||= {}
      @custom_attributes_cache.each {|key, value|
        write_custom_attribute(key, value)
      }
    end

    def write_custom_attribute(fieldname, value)
      return nil unless fieldname && !self.id.nil?
      return remove_custom_attribute(fieldname) if value.nil?
      fieldname = fieldname.to_s if fieldname.is_a?(Symbol) # in case you passed in a :symbol
      sql_sanitize!(fieldname)
      sql_sanitize!(value)
      o = AttributeObject.find_or_create_by_name self.class.table_name.to_s
      f = AttributeField.find_or_create_by_name fieldname
      if f.obj_id.nil?
        f.obj_id = o.id
        f.save
      end
      new_values = {
        :obj_id => o.id,
        :field_id => f.id,
        :instance_id => self.id
      }
      v = AttributeValue.find(:first, :conditions => new_values) || AttributeValue.create!(new_values)
      raise "Could not create new attribute" unless v
      v.value = value
      raise "Could not save new attribute" unless v.save
      v
    end

    def remove_all_attributes(instance_id)
      sql = ActiveRecord::Base.connection();
      o = AttributeObject.find_or_create_by_name self.class.table_name.to_s
      sql.execute "DELETE FROM attribute_values WHERE obj_id = '#{o.id}' AND instance_id = '#{instance_id}'"
    end

    def remove_custom_attribute(fieldname)
      fieldname = fieldname.to_s if fieldname.is_a?(Symbol) # in case you passed in a :symbol
      o = AttributeObject.find_by_name self.class.table_name.to_s
      f = AttributeField.find_by_name fieldname
      return unless o && f
      AttributeValue.destroy_all(
        :obj_id => o.id,
        :field_id => f.id,
        :instance_id => self.id
      )
      # Remove the value from the cache as well
      @custom_attributes_cache.delete(fieldname)
    end

    # # # # # # # # # # # # # # #
    #  AR Overrides             #
    # # # # # # # # # # # # # # #

    def initialize(attributes = {})
      return super(attributes)
    end

    def save(*args)
      # Saving can kill our cache, so we save a local copy
      cache = @custom_attributes_cache
      #save the record... if we succeed, write attributes
      if res = super(args)
        @custom_attributes_cache = cache
        write_custom_attributes
      end
      return res
    end

    def save!()
      # Saving can kill our cache, so we save a local copy
      cache = @custom_attributes_cache
      #save the record... if we succeed, write attributes
      if res = super()
        @custom_attributes_cache = cache
        write_custom_attributes
      end
      return res
    end

    def destroy
      #if the destroy succeeds, delete the attributes
      old_id = self.id
      if res = super
        remove_all_attributes(old_id)
      end
      return res
    end

    # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
    # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
    # (Alias for the protected read_attribute method).
    def [](attr_name)
      if self.attribute_names.include?(attr_name)
        read_attribute(attr_name)
      else
        get_custom_attribute(attr_name)
      end
    end

    def [](attr)
      get_custom_attribute(attr.to_s) || super(attr)
    end


    # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+.
    # (Alias for the protected write_attribute method).
    def []=(attr_name, value)
      if self.attribute_names.include?(attr_name.to_s)
        write_attribute(attr_name, value)
      else
        set_custom_attribute(attr_name, value)
      end
    end

    # Allows you to set all the attributes at once by passing in a hash with keys
    # matching the attribute names (which again matches the column names).
    #
    # If +guard_protected_attributes+ is true (the default), then sensitive
    # attributes can be protected from this form of mass-assignment by using
    # the +attr_protected+ macro. Or you can alternatively specify which
    # attributes *can* be accessed with the +attr_accessible+ macro. Then all the
    # attributes not included in that won't be allowed to be mass-assigned.
    #
    #   class User < ActiveRecord::Base
    #     attr_protected :is_admin
    #   end
    #
    #   user = User.new
    #   user.attributes = { :username => 'Phusion', :is_admin => true }
    #   user.username   # => "Phusion"
    #   user.is_admin?  # => false
    #
    #   user.send(:attributes=, { :username => 'Phusion', :is_admin => true }, false)
    #   user.is_admin?  # => true
    def attributes=(new_attributes, guard_protected_attributes = true)
      return if new_attributes.nil?
      attributes = new_attributes.dup
      attributes.stringify_keys!

      multi_parameter_attributes = []
      attributes = remove_attributes_protected_from_mass_assignment(attributes) if guard_protected_attributes

      attributes.each do |k, v|
        if k.include?("(")
          multi_parameter_attributes << [ k, v ]
        elsif respond_to?(:"#{k}=")
          send(:"#{k}=", v)
        elsif self.class.base_class.reserved_custom_attributes.include?(k) # we work our magic here
          set_custom_attribute(k, v)
        else
          raise(UnknownAttributeError, "unknown attribute: #{k}, note that mass assignment for custom attributes is not allowed unless it is specified by reserved_custom_attribute")
        end
      end

      assign_multiparameter_attributes(multi_parameter_attributes)
    end

    ### METHOD MISSING MAGIC ###
		# the magic is lost because we are allowing users to create their own custom_attribute fields. This way, they can create whatever they want and we don't have to block reserved methods.

    def method_missing(meth, *args, &block)
      method_name = meth.to_s

      assignment = false
      if method_name.last == '=' && args.size == 1
        assignment = true
        method_name = method_name.slice(0, method_name.length - 1) if method_name.length > 0
      end

      #Active Record uses this method to cast the type of attributes.  Need to implement it for validates_numericality_of.
      if method_name.ends_with? '_before_type_cast'
        method_name.gsub!(/_before_type_cast/, '')
      end

      #show?
      if args.size == 0 && !assignment && self.class.base_class.reserved_custom_attributes.include?(method_name)
        res = get_custom_attribute(method_name)
        return res || nil
      end

      #create/update?
      # NOTE: we don't check the reserved_custom_attributes on create, because they can
      #       technically create any attribute they like
      if assignment && !self.attributes.include?(method_name) && self.class.base_class.reserved_custom_attributes.include?(method_name)

        return set_custom_attribute(method_name, args[0])
      end

      #fall through
      super(meth, *args, &block)
    end

    protected

      def validate
        validate_unique_custom_attributes if self.class.unique_custom_attributes
      end

    # end protected methods

    private

      def sql_sanitize!(str)
        return nil if str.nil?
        str = str.to_s.gsub(/\\/, '\&\&').gsub(/'/, "''")
      end

      def validate_unique_custom_attributes
        self.class.unique_custom_attributes.each do |attr|
          #the present value within this instance
          value = get_custom_attribute(attr)

          #check the database table to see if someone else has already claimed this value
          sql = ActiveRecord::Base.connection();
          select = "f.name AS field_name, v.value AS field_value"
          from = "attribute_values v JOIN attribute_fields f ON v.field_id = f.id JOIN attribute_objects o ON v.obj_id = o.id "

          where = "o.name = '#{self.class.table_name.to_s}'" #We only care about other objects of our class
          where += " AND f.name = '#{sql_sanitize!(attr)}'" #We only care about other fields of this attribute type
          where += " AND v.value = '#{sql_sanitize!(value)}'" #And the value has to match
          where += " AND v.instance_id <> '#{self.id}'" #Let's not match ourselves either

          sql_res = sql.execute "SELECT #{select} FROM #{from} WHERE #{where}"

          #if we found a match, load the error
          if sql_res.num_rows > 0
            self.errors.add(attr, :taken, :default => "has already been taken", :value => value)
          end
          sql_res.free
        end
      end

    # end private methods

  end # end CustomAttribute class

  CustomAttributes.class_eval do
    include CustomValidations
    include CustomFinders
  end

end