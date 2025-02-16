require 'test_helper'

class ContractsShowTest < ActionController::IntegrationTest
  include Redmine::I18n
  
  def setup
    @project = Project.generate!(:identifier => 'main').reload
    @contract = Contract.generate!(:project => @project)
    @user = User.generate_user_with_permission_to_manage_budget(:project => @project)
    
    login_as(@user.login, 'contracts')
  end

  should "block anonymous users from viewing the contract" do
    logout
    visit "/projects/#{@project.identifier}/contracts/#{@contract.id}"

    assert_requires_login
  end
  
  should "block unauthorized users from viewing the contract" do
    logout

    @user = User.generate!(:password => 'test', :password_confirmation => 'test')
    login_as(@user.login, 'test')
    
    visit "/projects/#{@project.identifier}/contracts/#{@contract.id}"

    assert_forbidden
  end

  should "allow authorized users to view the contract" do
    visit_contracts_for_project(@project)
    click_link @contract.id
    assert_response :success
    assert_template 'contracts/show'
    assert_equal "/projects/main/contracts/#{@contract.id}", current_url

    assert_select "div.title-bar" do
      assert_select 'h2', :text => @contract.name
    end
  end

  should "show contract metadata" do
    visit_contract_page(@contract)

    assert_select "div#contract_#{@contract.id}.contract" do
      assert_select '.contract-status'
      assert_select '.contract-account-manager'
      assert_select '.contract-type'
      assert_select '.contract-start-date'
      assert_select '.contract-end-date'
      
      assert_select '.contract-labor .spent'
      assert_select '.contract-labor .budget'
      assert_select '.contract-overhead .spent'
      assert_select '.contract-overhead .budget'
      assert_select '.contract-total .spent'
      assert_select '.contract-total .budget'

      assert_select '#contract-terms' do
        assert_select '.contract-client-point-of-contact'
        assert_select '.contract-executed'
        assert_select '.contract-discount-note'
        assert_select '.contract-payment-terms'
        assert_select '.contract-client-ap-contact-information'
        assert_select '.contract-po-number'
        assert_select '.contract-details'

        assert_select '.contract-labor .spent'
        assert_select '.contract-labor .budget'
        assert_select '.contract-overhead .spent'
        assert_select '.contract-overhead .budget'
        assert_select '.contract-fixed .spent'
        assert_select '.contract-fixed .budget'
        assert_select '.contract-profit .spent'
        assert_select '.contract-profit .budget'
        # assert_select '.contract-discount .spent'
        # assert_select '.contract-discount .budget'
        assert_select '.contract-total .spent'
        assert_select '.contract-total .budget'

        assert_select '.contract-billable-rate'

        assert_select '.contract-labor-hour .spent'
        assert_select '.contract-labor-hour .budget'
        assert_select '.contract-overhead-hour .spent'
        assert_select '.contract-overhead-hour .budget'
        assert_select '.contract-total-hour .spent'
        assert_select '.contract-total-hour .budget'
      end
    end
  end

  should "have a link to create a new deliverable" do
    visit_contracts_for_project(@project)
    click_link @contract.id
    assert_response :success

    assert_select "a#new-deliverable", :text => /Add New/
    click_link "Add New"
    assert_response :success
    assert_template 'deliverables/new'
    assert_equal "/projects/main/contracts/#{@contract.id}/deliverables/new", current_url
  end

  should "show a list of deliverables for the contract" do
    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)
    @deliverable2 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)
    @deliverable3 = HourlyDeliverable.generate!(:contract => @contract, :manager => @manager)
    visit_contract_page(@contract)

    assert_select "table#deliverables" do
      [@deliverable1, @deliverable2].each do |deliverable|
        assert_select "td.end-date", :text => /#{format_date(deliverable.end_date)}/
        assert_select "td.type", :text => "F"
        assert_select "td.title", :text => /#{deliverable.title}/
        assert_select "td.manager", :text => /#{deliverable.manager.name}/
      end
      [@deliverable3].each do |deliverable|
        assert_select "td.end-date", :text => /#{format_date(deliverable.end_date)}/
        assert_select "td.type", :text => "H"
        assert_select "td.title", :text => /#{deliverable.title}/
        assert_select "td.manager", :text => /#{deliverable.manager.name}/
      end
    end

  end

  should "show the total labor budget for a Deliverable" do
    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)
    LaborBudget.generate!(:deliverable => @deliverable1,
                          :hours => 100,
                          :budget => 4000.5)
    LaborBudget.generate!(:deliverable => @deliverable1,
                          :hours => 100,
                          :budget => 200.0)

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "td.labor", :text => /4,201/
    end

  end

  should "show the total overhead budget for a Deliverable" do
    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)
    OverheadBudget.generate!(:deliverable => @deliverable1,
                             :hours => 100,
                             :budget => 4000.5)
    OverheadBudget.generate!(:deliverable => @deliverable1,
                             :hours => 100,
                             :budget => 200.0)

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "td.overhead", :text => /4,201/
    end

  end

  should "show the total labor budget spent for a Deliverable" do
    configure_overhead_plugin

    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)
    OverheadBudget.generate!(:deliverable => @deliverable1,
                             :hours => 100,
                             :budget => 4000.5)

    @issue1 = Issue.generate_for_project!(@project)
    @time_entry1 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 10,
                                       :user => @manager)

    @rate = Rate.generate!(:project => @project,
                           :user => @manager,
                           :date_in_effect => Date.yesterday,
                           :amount => 100)

    @deliverable1.issues << @issue1

    assert_equal 1, @deliverable1.issues.count

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "td.labor", :text => /1,000/
    end

  end

  should "show the total overhead budget spent for a Deliverable" do
    configure_overhead_plugin

    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)
    OverheadBudget.generate!(:deliverable => @deliverable1,
                             :hours => 100,
                             :budget => 4000.5)

    @issue1 = Issue.generate_for_project!(@project)
    @time_entry1 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @non_billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 20,
                                       :user => @manager)

    @rate = Rate.generate!(:project => @project,
                           :user => @manager,
                           :date_in_effect => Date.yesterday,
                           :amount => 100)

    @deliverable1.issues << @issue1

    assert_equal 1, @deliverable1.issues.count

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "td.overhead", :text => /2,000/
    end

  end

  should "show the total fixed budget for a Deliverable" do
    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)

    FixedBudget.generate!(:deliverable => @deliverable1, :budget => '$1,000', :markup => '$100')
    FixedBudget.generate!(:deliverable => @deliverable1, :budget => '$2,000', :markup => '200%')

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "td.fixed", :text => /3,000/
    end

  end

  should "show the total fixed budget spent for a Deliverable" do
    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)

    FixedBudget.generate!(:deliverable => @deliverable1, :budget => '$1,000', :markup => '$100', :paid => true)
    FixedBudget.generate!(:deliverable => @deliverable1, :budget => '$2,000', :markup => '200%')

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "td.fixed.spent-amount", :text => /1,000/
    end
  end

  should "show the total budget for a Deliverable" do
    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager, :total => '5404')

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "td.total.total-amount", :text => /5,404/
    end

  end

  should "show the total spent for a Deliverable" do
    configure_overhead_plugin
    @manager = User.generate!
    @contract.billable_rate = 200
    assert @contract.save

    @deliverable1 = HourlyDeliverable.generate!(:contract => @contract, :manager => @manager, :total => '1504')

    @issue1 = Issue.generate_for_project!(@project)
    @time_entry1 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 15,
                                       :user => @manager)

    @rate = Rate.generate!(:project => @project,
                           :user => @manager,
                           :date_in_effect => Date.yesterday,
                           :amount => 100)

    @deliverable1.issues << @issue1

    assert_equal 1, @deliverable1.issues.count

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      # Using the contract billable rate and not the user rate because it's income, not an expense
      assert_select "td.total.spent-amount", :text => /3,000/
    end

  end

  should "show each fixed budget item in the details for the Deliverable" do
    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)

    @budget1 = FixedBudget.generate!(:deliverable => @deliverable1, :title => 'Item 1', :budget => '$1,000', :markup => '$100', :paid => true)
    @budget2 = FixedBudget.generate!(:deliverable => @deliverable1, :title => 'Item 2', :budget => '$2,000', :markup => '200%')

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "#deliverable_details_#{@deliverable1.id}" do
        assert_select "tr#fixed_budget_#{@budget1.id}" do
          assert_select 'td.fixed_title', :text => /#{@budget1.title}/
          assert_select 'td.fixed_budget_spent', :text => '1,000'
          assert_select 'td.fixed_budget_total', :text => '1,000'
        end

        assert_select "tr#fixed_budget_#{@budget2.id}" do
          assert_select 'td.fixed_title', :text => /#{@budget2.title}/
          assert_select 'td.fixed_budget_spent', :text => '0'
          assert_select 'td.fixed_budget_total', :text => '2,000'
        end
      end
    end

  end

  should "show the total fixed markup budget in the details for the Deliverable" do
    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)

    @budget1 = FixedBudget.generate!(:deliverable => @deliverable1, :title => 'Item 1', :budget => '$1,000', :markup => '$100', :paid => true)
    @budget2 = FixedBudget.generate!(:deliverable => @deliverable1, :title => 'Item 2', :budget => '$2,000', :markup => '200%')

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "#deliverable_details_#{@deliverable1.id}" do
        assert_select 'td.fixed_markup_budget_spent', :text => '4,100'
        assert_select 'td.fixed_markup_budget_total', :text => '4,100'
      end
    end
  end

  should "show the labor hours for the deliverable" do
    configure_overhead_plugin

    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)
    LaborBudget.generate!(:deliverable => @deliverable1,
                          :hours => 100,
                          :budget => 4000.5)

    @issue1 = Issue.generate_for_project!(@project)
    @time_entry1 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 10,
                                       :user => @manager)

    @rate = Rate.generate!(:project => @project,
                           :user => @manager,
                           :date_in_effect => Date.yesterday,
                           :amount => 100)

    @deliverable1.issues << @issue1

    assert_equal 1, @deliverable1.issues.count

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "td.labor_hours_spent", :text => /10/
      assert_select "td.labor_hours", :text => /100/
    end

  end
  
  should "show the overhead hours for the deliverable" do
    configure_overhead_plugin

    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)
    OverheadBudget.generate!(:deliverable => @deliverable1,
                          :hours => 100,
                          :budget => 4000.5)

    @issue1 = Issue.generate_for_project!(@project)
    @time_entry1 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @non_billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 5,
                                       :user => @manager)

    @rate = Rate.generate!(:project => @project,
                           :user => @manager,
                           :date_in_effect => Date.yesterday,
                           :amount => 100)

    @deliverable1.issues << @issue1

    assert_equal 1, @deliverable1.issues.count

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "td.overhead_hours_spent", :text => /5/
      assert_select "td.overhead_hours", :text => /100/
    end

  end

  should "show the total hours for the deliverable" do
    configure_overhead_plugin

    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)
    LaborBudget.generate!(:deliverable => @deliverable1,
                          :hours => 100,
                          :budget => 4000.5)
    OverheadBudget.generate!(:deliverable => @deliverable1,
                          :hours => 100,
                          :budget => 4000.5)

    @issue1 = Issue.generate_for_project!(@project)
    @time_entry1 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 10,
                                       :user => @manager)
    @time_entry2 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @non_billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 5,
                                       :user => @manager)

    @rate = Rate.generate!(:project => @project,
                           :user => @manager,
                           :date_in_effect => Date.yesterday,
                           :amount => 100)

    @deliverable1.issues << @issue1

    assert_equal 1, @deliverable1.issues.count

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "td.total_hours_spent", :text => /15/
      assert_select "td.total_hours", :text => /200/
    end

  end

  should "show the count of the issues by status for the deliverable" do
    configure_overhead_plugin

    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)
    @status1 = IssueStatus.generate!
    @status2 = IssueStatus.generate!

    @issue1 = Issue.generate_for_project!(@project, :status => @status1)
    @issue2 = Issue.generate_for_project!(@project, :status => @status1)
    @issue3 = Issue.generate_for_project!(@project, :status => @status1)
    @issue4 = Issue.generate_for_project!(@project, :status => @status2)

    @deliverable1.issues = [@issue1, @issue2, @issue3, @issue4]

    assert_equal 4, @deliverable1.issues.count

    visit_contract_page(@contract)
    assert_select "table#deliverables" do
      assert_select "tr" do
        assert_select "td a", :text => /#{@status1}/
        assert_select "td.number a", :text => /3/
      end
      assert_select "tr" do
        assert_select "td a", :text => /#{@status2}/
        assert_select "td.number a", :text => /1/
      end
      assert_select "tr" do
        assert_select "td strong a", "All"
        assert_select "td.number a", :text => /4/
      end
    end
  end

  should "show overages in red" do
    configure_overhead_plugin

    @manager = User.generate!

    @deliverable1 = HourlyDeliverable.generate!(:contract => @contract, :manager => @manager)
    @issue1 = Issue.generate_for_project!(@project)
    @time_entry1 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 10,
                                       :user => @manager)
    @time_entry2 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @non_billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 5,
                                       :user => @manager)
    @deliverable1.issues << @issue1
    @rate = Rate.generate!(:project => @project,
                           :user => @manager,
                           :date_in_effect => Date.yesterday,
                           :amount => 100)
    
    assert_equal 1, @deliverable1.issues.count

    visit_contract_page(@contract)

    # Overages on:
    assert_select '.overage', :count => 14
    assert_select '.contract-labor .overage', :count => 2
    assert_select '.contract-overhead .overage', :count => 2
    assert_select '.contract-labor-hour .overage'
    assert_select '.contract-overhead-hour .overage'
    assert_select '.contract-total-hour .overage'

    assert_select '#deliverables .spent-amount.labor.overage'
    assert_select '#deliverables .spent-amount.overhead.overage'
    assert_select '#deliverables .labor_budget_spent.overage'
    assert_select '#deliverables .overhead_budget_spent.overage'
    assert_select '#deliverables .labor_hours_spent .overage'
    assert_select '#deliverables .overhead_hours_spent .overage'
    assert_select '#deliverables .total_hours_spent .overage'
    
  end
  

  should "show an alert if there is orphaned time or issues" do
    configure_overhead_plugin

    @manager = User.generate!

    @deliverable1 = FixedDeliverable.generate!(:contract => @contract, :manager => @manager)

    @issue1 = Issue.generate_for_project!(@project)
    @time_entry1 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 10,
                                       :user => @manager)
    @time_entry2 = TimeEntry.generate!(:issue => @issue1,
                                       :project => @project,
                                       :activity => @non_billable_activity,
                                       :spent_on => Date.today,
                                       :hours => 5,
                                       :user => @manager)
    @deliverable1.issues << @issue1

    @orphaned_issue = Issue.generate_for_project!(@project)
    @time_entry_on_orphaned_issue = TimeEntry.generate!(:issue => @orphaned_issue,
                                                        :project => @project,
                                                        :activity => @billable_activity,
                                                        :spent_on => Date.today,
                                                        :hours => 10,
                                                        :user => @manager)

    @time_entry_on_project = TimeEntry.generate!(:issue => nil,
                                                 :project => @project,
                                                 :activity => @billable_activity,
                                                 :spent_on => Date.today,
                                                 :hours => 10,
                                                 :user => @manager)

    @rate = Rate.generate!(:project => @project,
                           :user => @manager,
                           :date_in_effect => Date.yesterday,
                           :amount => 100)


    assert_equal 1, @deliverable1.issues.count

    visit_contract_page(@contract)
    assert_select "div.error_msg" do
      assert_select "p", :text => /2,000/
      assert_select "a", :text => /update/i
    end
    
  end
  
  should "show the current period for a Retainer" do
    today_mock = Date.new(2010,2,15)
    Date.stubs(:today).returns(today_mock)

    @manager = User.generate!
    @retainer_deliverable = RetainerDeliverable.generate!(:contract => @contract, :manager => @manager, :title => "Retainer", :start_date => '2010-01-01', :end_date => '2010-03-31')

    visit_contract_page(@contract)

    assert_select "table#deliverables" do
      assert_select "#deliverable_details_#{@retainer_deliverable.id}" do
        assert_select ".deliverable-current-period", :text => /February 2010/i
      end
    end

  end

  should "show a selector for changing the currently shown Retainer's period" do
    @manager = User.generate!
    @retainer_deliverable = RetainerDeliverable.generate!(:contract => @contract, :manager => @manager, :title => "Retainer", :start_date => '2010-01-01', :end_date => '2010-03-31')

    visit_contract_page(@contract)

    assert_select "table#deliverables" do
      assert_select "#deliverable_details_#{@retainer_deliverable.id}" do
        assert_select "select#retainer_period_change_#{@retainer_deliverable.id}" do
          assert_select "option", /All/
          assert_select "option", /January 2010/
          assert_select "option", /February 2010/
          assert_select "option", /March 2010/
        end
      end
    end
    
  end
end
