# Simple Page/Notes system, will grow into a full Wiki once I get the time..
class PagesController < ApplicationController
  def show
    @page = Page.find(params[:id], :conditions => ["company_id = ?", current_user.company.id] )
  end

  def new
    @page = Page.new(params[:page])
  end

  def create
    @page = Page.new(params[:page])

    @page.user = current_user
    @page.company = current_user.company
    if @page.save
      create_work_log(EventLog::PAGE_CREATED, "- #{@page.name} Created")
      flash['notice'] = _('Note was successfully created.')
      redirect_to :action => 'show', :id => @page.id
    else
      @page.valid?
      render :action => 'new'
    end
  end

  def edit
    @page = Page.find(params[:id], :conditions => ["company_id = ?", current_user.company.id] )
  end

  def update
    @page = Page.find(params[:id], :conditions => ["company_id = ?", current_user.company.id] )

    old_name = @page.name
    old_body = @page.body

    if @page.update_attributes(params[:page])
      body = old_name != @page.name ? "- #{old_name} -> #{@page.name}\n" : ""
      body += "- #{@page.name} Modified\n" if old_body != @page.body
      create_work_log(EventLog::PAGE_MODIFIED, body)

      flash['notice'] = _('Note was successfully updated.')
      redirect_to :action => 'show', :id => @page
    else
      @page.valid?
      render :action => 'edit'
    end
  end

  def destroy
    @page = Page.find(params[:id], :conditions => ["company_id = ?", current_user.company.id] )
    create_work_log(EventLog::PAGE_DELETED, "- #{@page.name} Deleted")
    @page.destroy
    redirect_to :controller => 'tasks', :action => 'list'
  end

  # Renders a list of possible notable targets for a page
  def target_list
    @matches = []
    str = [ params[:target] ]

    @matches += User.search(current_user.company, str)
    @matches += Customer.search(current_user.company, str)
    @matches += current_user.all_projects.find(:all,
                              :conditions => Search.search_conditions_for(str))

    render :layout => false
  end

  private

  def create_work_log(type, body)
    worklog = WorkLog.new
    worklog.user = current_user
    worklog.project = @page.notable if @page.notable_type == "Project"
    worklog.company = @page.company
    worklog.customer = @page.notable if @page.notable_type == "Customer"
    worklog.body = "#{@page.name}"
    worklog.task_id = 0
    worklog.started_at = Time.now.utc
    worklog.duration = 0
    worklog.log_type = type
    worklog.body = body
    worklog.save
  end

end
