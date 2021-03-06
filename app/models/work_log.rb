# A work entry, belonging to a user & task
# Has a duration in seconds for work entries

class WorkLog < ActiveRecord::Base
  has_many(:custom_attribute_values, :as => :attributable, :dependent => :destroy,
           # set validate = false because validate method is over-ridden and does that for us
           :validate => false)
  include CustomAttributeMethods

  belongs_to :user
  belongs_to :company
  belongs_to :project
  belongs_to :customer
  belongs_to :task
  belongs_to :scm_changeset

  has_one    :ical_entry, :dependent => :destroy
  has_one    :event_log, :as => :target, :dependent => :destroy
  has_many    :work_log_notifications, :dependent => :destroy
  has_many    :users, :through => :work_log_notifications

  named_scope :comments, :conditions => [ "work_logs.comment = ? or work_logs.log_type = ?", true, EventLog::TASK_COMMENT ]

  validates_presence_of :started_at

  after_update { |r|
    r.ical_entry.destroy if r.ical_entry
    l = r.event_log
    l.created_at = r.started_at
    l.save

    if r.task && r.duration.to_i > 0
      r.task.recalculate_worked_minutes
      r.task.save
    end

  }

  after_create { |r|
    l = r.create_event_log
    l.company_id = r.company_id
    l.project_id = r.project_id
    l.user_id = r.user_id
    l.event_type = r.log_type
    l.created_at = r.started_at
    l.save

    if r.task && r.duration.to_i > 0
      r.task.recalculate_worked_minutes
      r.task.save
    end

  }

  after_destroy { |r|
    if r.task
      r.task.recalculate_worked_minutes
      r.task.save
    end

  }
  #You must use two following methods to add unescaped user input!!!
  def user_input=(user_comment)
    self.body=CGI::escapeHTML(user_comment)
  end
  # this method must be named user_input<<
  # but I can't redefine <<
  def user_input_add(user_comment)
    self.body<< CGI::escapeHTML(user_comment)
  end

  ###
  # Creates and saves a worklog for the given task.
  # The newly created worklog is returned.
  # If anything goes worng, raise an exception
  ###
  def self.create_task_created!(task, user)
    worklog = WorkLog.new
    worklog.user = user
    worklog.company = task.project.company
    worklog.customer = task.project.customer
    worklog.project = task.project
    worklog.task = task
    worklog.started_at = Time.now.utc
    worklog.duration = 0
    worklog.log_type = EventLog::TASK_CREATED
    worklog.user_input =  task.description

    #worklog.comment = ??????
    worklog.save!

    return worklog
  end

  # Builds a new (unsaved) work log for task using the given params
  # params must look like {:work_log=>{...},:comment=>""}
  # build only if we have :duration or :comment else retur false
  def self.build_work_added_or_comment(task, user, params=nil)
    work_log_params=params[:work_log].clone unless params[:work_log].nil?
    if (work_log_params and !work_log_params[:duration].blank?) or (params and !params[:comment].blank?)
      unless params[:comment].blank?
        work_log_params[:body] = CGI::escapeHTML(params[:comment])
        work_log_params[:log_type]=EventLog::TASK_COMMENT
        work_log_params[:comment] =true
      end
      unless work_log_params[:duration].blank?
        work_log_params[:duration] = TimeParser.parse_time(user, work_log_params[:duration])
        work_log_params[:started_at] = TimeParser.date_from_params(user, work_log_params, :started_at)
        work_log_params[:log_type] = EventLog::TASK_WORK_ADDED
      else
        work_log_params[:duration]=0
        work_log_params[:started_at]=Time.now.utc
      end
      work_log_params[:user]=user
      work_log_params[:company]= task.company
      work_log_params[:project] = task.project
      work_log_params[:customer] = (task.customers.first || task.project.customer)
      task.work_logs.build( work_log_params)
    else
      return false
    end
  end

  def ended_at
    self.started_at + self.duration + self.paused_duration
  end

  # Sets the associated customer using the given name
  def customer_name=(name)
    self.customer = company.customers.find_by_name(name)
  end
  # Returns the name of the associated customer
  def customer_name
    customer.name if customer
  end

  alias :validate_custom_attributes :validate

  def validate
    if log_type == EventLog::TASK_WORK_ADDED
      validate_custom_attributes
    end
  end

  ###
  # This method will set up notifications. A block should be passed that will
  # send the actual emails, but this method will update the owners, worklog, etc
  # as required.
  ###
  def setup_notifications(notify_ids,&block)
    worklog=self
    task=self.task
    current_user=self.user
    ids = notify_ids || []
    emails = (task.notify_emails || "").strip.split(",")
    all_users = []

    if ids.any? or emails.any?
      all_users = ids.map { |id| current_user.company.users.find(id) }
      users = all_users.clone
      users.delete(current_user) if !current_user.receive_own_notifications?
      emails += users.map { |u| u.email }
      emails = emails.uniq.compact
      emails = emails.select { |e| !e.blank? }

      worklog.users = users

      emails.each do |email|
        yield(email)
      end

      if users.any?
        comments = users.map { |u| "#{ u.name } (#{ u.email })" }
        comment = _("Notification emails sent to %s", comments.join(", "))
        worklog.body ||= ""
        worklog.body += "\n\n" if !worklog.body.blank?
        worklog.body += comment
        worklog.save
      end

    end

    task.mark_as_notified_last_change(all_users)
    task.mark_as_unread(current_user)
  end
  ###
  # this function will send notifications
  # only if work log have comment or log type TASK_CREATED
  ###
  def send_notifications(notify_ids, update_type= :comment)
    if (self.comment? and self.log_type != EventLog::TASK_CREATED) or self.log_type == EventLog::TASK_COMMENT
        self.setup_notifications(notify_ids) do |recipients|
            email_body= self.user.name + ":\n"
            email_body<< CGI::unescapeHTML(self.body)
            Notifications::deliver_changed(update_type, self.task, self.user, recipients,
                                           email_body.gsub(/<[^>]*>/,''))
          end
    else
      if self.log_type == EventLog::TASK_CREATED
        self.setup_notifications(notify_ids) do |recipients|
          #note send without comment, user add comment will be sended another mail
          Notifications::deliver_created(self.task, self.user, recipients)
        end
      else
        #we don't have comment
        #don't bother our users
      end
    end
  end
end

# == Schema Information
#
# Table name: work_logs
#
#  id               :integer(4)      not null, primary key
#  user_id          :integer(4)      default(0), not null
#  task_id          :integer(4)
#  project_id       :integer(4)      default(0), not null
#  company_id       :integer(4)      default(0), not null
#  customer_id      :integer(4)      default(0), not null
#  started_at       :datetime        not null
#  duration         :integer(4)      default(0), not null
#  body             :text
#  log_type         :integer(4)      default(0)
#  scm_changeset_id :integer(4)
#  paused_duration  :integer(4)      default(0)
#  comment          :boolean(1)      default(FALSE)
#  exported         :datetime
#  approved         :boolean(1)
#

