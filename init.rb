config.gem 'formtastic', :version => '0.9.10'

require 'redmine'

Redmine::Plugin.register :redmine_contracts do
  name 'Redmine Contracts plugin'
  author 'Eric Davis'
  description 'A system to manage the execution of a client contract by separating it into deliverables and milestones.'
  url 'https://projects.littlestreamsoftware.com/projects/redmine-contracts'
  author_url 'http://www.littlestreamsoftware.com'
  version '0.1.0'

  requires_redmine :version_or_higher => '0.9.0'
  requires_redmine_plugin :redmine_rate, :version_or_higher => '0.1.0'
  requires_redmine_plugin :redmine_overhead, :version_or_higher => '0.1.0'
  
  project_module :contracts do
    permission(:manage_budget, {
                 :contracts => [:index, :new, :create, :show, :edit, :update, :destroy],
                 :deliverables => [:index, :new, :create, :show, :edit, :update, :destroy]
               })
  end

  project_module :issue_tracking do
    permission(:assign_deliverable_to_issue, {})
  end

  contract_list_submenu_items = Proc.new {|project|
    if project && project.module_enabled?(:contracts)

      project.contracts.inject([]) do |menu_items, contract|

        menu_items << ::Redmine::MenuManager::MenuItem.new("contract-#{contract.id}",
                                                           { :controller => 'contracts', :action => 'show', :id => contract.id, :project_id => project},
                                                           # TODO: http://www.redmine.org/issues/6426
                                                           # contract_path(project, contract),
                                                           {
                                                             :caption => contract.name, # h-escaped in Redmine
                                                             :param => :project_id,
                                                             :parent => :contracts
                                                           })
      end
      
    end
  }
  
  menu(:project_menu,
       :contracts,
       {:controller => 'contracts', :action => 'index'},
       :caption => :text_contracts,
       :param => :project_id,
       :children => contract_list_submenu_items)

  menu(:project_menu,
       :new_contract,
       {:controller => 'contracts', :action => 'new'},
       :caption => :text_new_contract,
       :param => :project_id,
       :parent => :contracts)

end

require 'dispatcher'
Dispatcher.to_prepare :redmine_contracts do

  require_dependency 'time_entry'
  TimeEntry.send(:include, RedmineContracts::Patches::TimeEntryPatch)
  gem 'inherited_resources', :version => '1.0.6'
  require_dependency 'inherited_resources'
  require_dependency 'inherited_resources/base'

  # Load and bootstrap formtastic
  gem 'formtastic', :version => '0.9.10'
  require_dependency 'formtastic'
  require_dependency 'formtastic/layout_helper'
  ActionView::Base.send :include, Formtastic::SemanticFormHelper
  ActionView::Base.send :include, Formtastic::LayoutHelper

  Formtastic::SemanticFormBuilder.all_fields_required_by_default = false
  Formtastic::SemanticFormBuilder.required_string = "<span class='required'> *</span>"
  Formtastic::SemanticFormBuilder.inline_errors = :none

  require_dependency 'payment_term' # Load so Enumeration will pick up the subclass in dev
  
  require_dependency 'project'
  Project.send(:include, RedmineContracts::Patches::ProjectPatch)
  require_dependency 'issue'
  Issue.send(:include, RedmineContracts::Patches::IssuePatch)
  require_dependency 'query'
  unless Query.included_modules.include? RedmineContracts::Patches::QueryPatch
    Query.send(:include, RedmineContracts::Patches::QueryPatch)
  end

  unless Query.available_columns.collect(&:name).include?(:deliverable)
    Query.add_available_column(QueryColumn.new(:deliverable, :sortable => "#{Deliverable.table_name}.title", :groupable => 'deliverable'))
  end

  # Hack in order to get the associated contract to be grouped by name
  # * Proxy method Issue#contract_name
  # * Naming Query column contract_name
  # * Grouping by 'contracts.name'
  unless Query.available_columns.collect(&:name).include?(:contract_name)
    Query.add_available_column(QueryColumn.new(:contract_name, :sortable => "#{Contract.table_name}.name", :groupable => 'contracts.name'))
  end

  require_dependency 'application_controller'
  ApplicationController.send(:helper, :contracts)
end

require 'redmine_contracts/hooks/view_layouts_base_html_head_hook'
require 'redmine_contracts/hooks/view_issues_show_details_bottom_hook'
require 'redmine_contracts/hooks/view_issues_form_details_bottom_hook'
require 'redmine_contracts/hooks/controller_issues_edit_before_save_hook'
require 'redmine_contracts/hooks/view_issues_bulk_edit_details_bottom_hook'
require 'redmine_contracts/hooks/controller_issues_bulk_edit_before_save_hook'
require 'redmine_contracts/hooks/helper_issues_show_detail_after_setting_hook'
require 'redmine_contracts/hooks/controller_timelog_available_criterias_hook'
