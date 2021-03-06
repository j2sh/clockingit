class ScmRevision < ActiveRecord::Base
  belongs_to :company
  belongs_to :project
  belongs_to :user
  belongs_to :scm_changeset
  belongs_to :scm_file
end

# == Schema Information
#
# Table name: scm_revisions
#
#  id               :integer(4)      not null, primary key
#  company_id       :integer(4)
#  project_id       :integer(4)
#  user_id          :integer(4)
#  scm_changeset_id :integer(4)
#  scm_file_id      :integer(4)
#  revision         :string(255)
#  author           :string(255)
#  commit_date      :datetime
#  state            :string(255)
#

