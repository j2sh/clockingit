require File.dirname(__FILE__) + '/../test_helper'

class EmailTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_truth
    assert true
  end
end

# == Schema Information
#
# Table name: emails
#
#  id         :integer(4)      not null, primary key
#  from       :string(255)
#  to         :string(255)
#  subject    :string(255)
#  body       :text
#  company_id :integer(4)
#  user_id    :integer(4)
#  created_at :datetime
#  updated_at :datetime
#

