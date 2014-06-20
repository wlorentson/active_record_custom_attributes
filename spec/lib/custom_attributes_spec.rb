# For now I've stuck this into our RAILS_ROOT/spec/lib/
# so that we maintain that it's tested when we do rake spec
#
# Maybe in the future this becomes a generator? -danny (2009.10.28)



# require File.dirname(__FILE__) + '/../spec_helper'
# 
# #We need our own AR class so that we can set class methods like validations without hosing anything else
# class DummyModel < ActiveRecord::CustomAttributes
#   set_table_name 'accounts'
# end
# 
# describe ActiveRecord::CustomAttributes do
#   before :each do
#     #using live database for now
#     @dummy = DummyModel.create
#     @dummy.write_custom_attribute('field1', 'value1') 
#     @dummy.write_custom_attribute('field2', 'value2') 
#     @dummy2 = DummyModel.create
#   end
#   
# 
#   it "creates a new attribute given a field name and value" do
#     v = @dummy.write_custom_attribute('new_field', 'new_value')
#     v.should be_a AttributeValue
#     AttributeValue.last.value.should == 'new_value'
#   end
# 
#   it "does not create a new attribute if given bad input values" do
#     @dummy.write_custom_attribute(nil, 'a value').should be_nil
#     @dummy.write_custom_attribute('a field', nil).should be_nil
#   end
# 
#   it "removes an attribute" do
#     lambda do
#       @dummy.remove_custom_attribute('field1')
#     end.should change(AttributeValue, :count).by(-1)
#   end
# 
#   it "loads all attributes" do
#     reloaded = DummyModel.find @dummy.id
#     reloaded.field1.should == 'value1'
#   end
# 
#   it "lists attribute for a field" do
#     @dummy.field1.should == "value1"
#   end
#   
#   it "should not list attributes for a different object" do
#     @dummy.write_custom_attribute('not_for', 'dummy_two')
#     @dummy2.get_custom_attribute('not_for').should be_nil
#   end
# 
#   it "should update an existing attribute rather than creating a new one" do
#     @dummy.field1.should == 'value1'
#     lambda do 
#       @dummy.write_custom_attribute('field1', 'a_new_value')
#     end.should change(AttributeValue, :count).by(0)
#   end
# 
#   it "should not cause trouble when record has not yet been saved" do
#     lambda do
#       DummyModel.new.custom_attributes
#       DummyModel.new.get_custom_attribute('foo')
#       DummyModel.new.set_custom_attribute('foo', 'bar')
#       DummyModel.new.write_custom_attribute('foo', 'bar')
#       DummyModel.new.remove_custom_attribute('baz')
#     end.should change(AttributeValue, :count).by(0)
#   end
# 
#   it "should handle method_missing for displaying an attribute" do
#     @dummy.field1.should == 'value1'
#   end 
# 
#   it "should handle method_missing for assigning an attribute" do
#     @dummy.new_field_name = 'new_field_value'
#     @dummy.save
#     @dummy.new_field_name.should == 'new_field_value'
#   end
# 
#   it "should handle method missing for deleting an attribute" do
#     lambda do
#       @dummy.field1 = nil
#       @dummy.save
#     end.should change(AttributeValue, :count).by(-1)
#     lambda do
#       @dummy.field1
#     end.should raise_error
#   end
#   
#   it "should return nil for a missing attribute that is in the custom_attributes_list" do
#     DummyModel.reserved_custom_attribute('i_am_reserved')
#     DummyModel.first.i_am_reserved.should be_nil
#   end
# 
#   it "should allow defaults for reserved attributes" do
#     DummyModel.reserved_custom_attribute('i_have_a_default', :default => 'this_is_my_default')
#     DummyModel.first.i_have_a_default.should == 'this_is_my_default' 
#   end
# 
#   it "should write the default value to the database when loading a default reserved attribute" do
#     lambda do
#       DummyModel.reserved_custom_attribute('i_am_lazy_loaded', :default => 'lazy_default')
#     end.should change(AttributeValue, :count).by(0)
#     lambda do
#       DummyModel.first.i_am_lazy_loaded.should == 'lazy_default'
#     end.should change(AttributeValue, :count).by(1)
#   end
# 
#   it "should work with symbols" do
#     @dummy.write_custom_attribute(:symbol, 'value')
#     @dummy.get_custom_attribute(:symbol).should == 'value'
#     lambda do
#       @dummy.remove_custom_attribute(:symbol)
#     end.should change(AttributeValue, :count).by(-1)
#   end
# 
#   it "should not allow custom attributes to collide with existing methods or attributes" do
#     #Class method
#     lambda do
#       DummyModel.reserved_custom_attribute(:first)
#     end.should raise_error
#     #Instance method
#     lambda do
#       DummyModel.reserved_custom_attribute(:error_on)
#     end.should raise_error
#   end
# 
#   it "should return nil for when get_custom_attribute is called on an  undefined custom attribute" do
#     @dummy.get_custom_attribute('not_defined').should be_nil
#   end
# 
#   it "should remove all attributes when the record is destroyed" do
#     conditions = {:instance_id => @dummy.id, :obj_id => AttributeValue.last.obj_id}
#     attr_count = AttributeValue.count :conditions => conditions 
#     lambda do
#       @dummy.destroy
#     end.should change(AttributeValue, :count).by(-1 * attr_count)
#   end
# 
#   it "should handle validations" do
#     #This test modifies the actual class validation_chain, so they've all got to be wrapped together
#     #
#     #validates_format_of
#     DummyModel.reserved_custom_attribute :needs_a_format
#     DummyModel.validates_format_of :needs_a_format, :with => /.*bar.*/
# 
#     @dummy.needs_a_format = 'not_what_we_need'
#     @dummy.errors_on(:needs_a_format).size.should_not == 0
# 
#     @dummy.needs_a_format = 'foobarbaz'
#     @dummy.errors_on(:needs_a_format).size.should == 0
# 
#     #validates_presence_of
#     DummyModel.reserved_custom_attribute :present
#     DummyModel.validates_presence_of :present
#     @dummy.errors_on(:present).size.should_not == 0
#     @dummy.present = 'present'
#     @dummy.valid?
#     @dummy.errors_on(:present).size.should == 0
# 
#     #validates_numericality_of
#     DummyModel.reserved_custom_attribute :numerical
#     DummyModel.validates_numericality_of :numerical
#     
#     @dummy.numerical = 'not a number'
#     @dummy.errors_on(:numerical).size.should_not == 0
#     
#     @dummy.numerical = '42'
#     @dummy.errors_on(:numerical).size.should == 0
# 
#     #validates_uniqueness_of
#     DummyModel.reserved_custom_attribute :oneandonly
#     DummyModel.validates_uniqueness_of :oneandonly  
#     
#     @dummy.oneandonly = 'taken'
#     @dummy.save
#     @dummy.get_custom_attribute('oneandonly').should == 'taken'
# 
#     @dummy2 = DummyModel.last
#     @dummy2.oneandonly = 'taken'
#     @dummy2.get_custom_attribute('oneandonly').should == 'taken'
#     @dummy2.errors_on(:oneandonly).size.should_not == 0
# 
#     @dummy2.oneandonly = 'not_taken'
#     @dummy2.errors_on(:oneandonly).size.should == 0
# 
#     #validates_length_of
#     DummyModel.reserved_custom_attribute :short
#     DummyModel.validates_length_of :short, :maximum => 5
#     @dummy.short = 'notshort'
#     @dummy.errors_on(:short).size.should_not == 0
# 
#     @dummy.short = 'short'
#     @dummy.errors_on(:short).size.should == 0
#   end
#     
# end
