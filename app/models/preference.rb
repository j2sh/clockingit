# A simple key/value preference. 
class Preference < ActiveRecord::Base

  belongs_to :preferencable, :polymorphic => true
end

# == Schema Information
#
# Table name: preferences
#
#  id                 :integer(4)      not null, primary key
#  preferencable_id   :integer(4)
#  preferencable_type :string(255)
#  key                :string(255)
#  value              :text
#  created_at         :datetime
#  updated_at         :datetime
#

