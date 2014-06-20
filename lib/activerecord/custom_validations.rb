#
# NOTE: all validations gutted from activerecord/lib/activerecord/validations.rb, Rails 2.3.4
#
module ActiveRecord

  class CustomValidationError < StandardError; end

  module CustomValidations
    
    def self.included(base) # :nodoc:
      base.extend ClassMethods
    end
    
    module ClassMethods

      #
      # Our custom check to see that only reserved_custom_attributes can be validates
      # NOTE: we use respond_to?(attr) because virtual attributes can still be validated (ex: validates_confirmation_of :password)
      #       but will not be considered 'custom attributes'
      #
      def validates_each(*attrs)
        attrs_to_check = attrs.dup

        options        = attrs_to_check.extract_options!.symbolize_keys
        attrs_to_check = attrs_to_check.flatten
        
        # check to see if this method is trying to be a custom attribute
        attrs_to_check.each do |attr|
          unless self.new.respond_to?(attr) || self.base_class.reserved_custom_attributes.include?(attr.to_s)
            if RAILS_ENV == 'test'
              puts "Warning: skipping custom validation due to missing reserved attribute #{attr}"
            else
              raise CustomValidationError.new("Error: '#{attr}', Cannot run validations on a custom attribute that has not been declare by reserved_custom_attribute")
            end
          end
        end
        
        super(*attrs)      
      end

      

      #
      # Override any validations that need special handling below
      #

      def validates_confirmation_of(*attr_names)
        super
      end

      def validates_acceptance_of(*attr_names)
        super
      end

      def validates_presence_of(*attr_names)
        super
      end

      def validates_length_of(*attrs)
        super
      end
      alias_method :validates_size_of, :validates_length_of

      def validates_uniqueness_of(*attr_names)
        options = attr_names.extract_options!
        
        #Handle symbols too
        attr_names = attr_names.map &:to_s
        
        #If any of the passed attributes have already been reserved as custom attributes, we'll validate those
        @unique_custom_attributes = attr_names.select {|attr|
          self.reserved_custom_attributes.include?(attr)
        }
        
        #pass on to the real validates_uniqueness_of, but only the real attributes
        real_attrs = self.new.attributes
        super(attr_names.select {|attr| real_attrs.include? attr}, options)
      end

      def validates_format_of(*attr_names)
        super
      end

      def validates_inclusion_of(*attr_names)
        super
      end

      def validates_exclusion_of(*attr_names)
        super
      end

      def validates_associated(*attr_names)
        super
      end

      def validates_numericality_of(*attr_names)
        super
      end

    end # end ClassMethods
  end # end CustomValidations

end # end ActiveRecord
