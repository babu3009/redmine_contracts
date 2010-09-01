# A RetainerDeliverable is an HourlyDeliverable that is renewed at
# regular calendar periods.  The Company bills a regular number of
# hours for a hourly rate whereby the budgets are reset over a
# regular cyclical period (often monthly).
class RetainerDeliverable < HourlyDeliverable
  unloadable

  # Associations

  # Validations
  ValidFrequencies = ["monthly", "quarterly"]
  validates_inclusion_of :frequency, :in => ValidFrequencies, :allow_nil => true, :allow_blank => true
  
  # Accessors

  # Callbacks
  before_update :check_for_extended_period
  
  def short_type
    'R'
  end

  def current_period
    'TODO'
  end

  def beginning_date
    start_date && start_date.beginning_of_month.to_date
  end

  def ending_date
    end_date && end_date.end_of_month.to_date
  end

  def months
    month_acc = []

    current_date = beginning_date
    return [] if current_date.nil? || ending_date.nil?
    
    while current_date < ending_date do
      month_acc << current_date
      current_date = current_date.advance(:months => 1)
    end
    
    month_acc
  end

  def labor_budgets_for_date(date)
    labor_budgets.all(:conditions => {:year => date.year, :month => date.month})
  end

  def overhead_budgets_for_date(date)
    overhead_budgets.all(:conditions => {:year => date.year, :month => date.month})
  end

  def create_budgets_for_periods
    # For each month in the time span
    months.each do |month|
      # Iterate over all un-dated budgets, created dated versions
      undated_labor_budgets = labor_budgets.all(:conditions => ["#{LaborBudget.table_name}.year IS NULL AND #{LaborBudget.table_name}.month IS NULL"])
      undated_labor_budgets.each do |template_budget|
        labor_budgets.create(template_budget.attributes.merge(:year => month.year, :month => month.month))
      end

      undated_overhead_budgets = overhead_budgets.all(:conditions => ["#{OverheadBudget.table_name}.year IS NULL AND #{OverheadBudget.table_name}.month IS NULL"])
      undated_overhead_budgets.each do |template_budget|
        overhead_budgets.create(template_budget.attributes.merge(:year => month.year, :month => month.month))
      end
    end
    # Destroy origional un-dated budgets
    labor_budgets.all(:conditions => ["#{LaborBudget.table_name}.year IS NULL AND #{LaborBudget.table_name}.month IS NULL"]).collect(&:destroy)
    overhead_budgets.all(:conditions => ["#{OverheadBudget.table_name}.year IS NULL AND #{OverheadBudget.table_name}.month IS NULL"]).collect(&:destroy)
  end

  def check_for_extended_period
    # TODO: brute force. Alternative would be to check end_date_changes to see if the period actually shifted
    if end_date_changed?
      extend_period_to_new_end_date
    end

    # TODO: brute force. Alternative would be to check start_date_changes to see if the period actually shifted
    if start_date_changed?
      extend_period_to_new_start_date
    end
  end

  def self.frequencies_to_select
    ValidFrequencies.collect {|f| [l("text_#{f}"), f]}
  end

  private

  def extend_period_to_new_end_date
    last_labor_budget = labor_budgets.last(:order => 'year ASC, month ASC')
    last_overhead_budget = overhead_budgets.last(:order => 'year ASC, month ASC')
      
    months.each do |new_period|
      create_budgets_for_new_period(new_period, last_labor_budget, last_overhead_budget)
    end
  end

  def extend_period_to_new_start_date
    first_labor_budget = labor_budgets.first(:order => 'year DESC, month DESC')
    first_overhead_budget = overhead_budgets.first(:order => 'year DESC, month DESC')
    
    months.each do |new_period|
      create_budgets_for_new_period(new_period, first_labor_budget, first_overhead_budget)
    end

  end

  def create_budgets_for_new_period(new_period, labor_budget_to_copy, overhead_budget_to_copy)
    existing_labor = labor_budgets.first(:conditions => {:year => new_period.year, :month => new_period.month})
    unless existing_labor
      create_new_labor_budget_based_on_existing_budget(labor_budget_to_copy, 'year' => new_period.year, 'month' => new_period.month)
    end

    existing_overhead = overhead_budgets.first(:conditions => {:year => new_period.year, :month => new_period.month})
    unless existing_overhead
      create_new_overhead_budget_based_on_existing_budget(overhead_budget_to_copy, 'year' => new_period.year, 'month' => new_period.month)
    end
      
  end
  
  def create_new_labor_budget_based_on_existing_budget(existing_labor_budget, attributes={})
    labor_budgets.create(existing_labor_budget.attributes.except('id').merge(attributes))
  end

  def create_new_overhead_budget_based_on_existing_budget(existing_overhead_budget, attributes={})
    overhead_budgets.create(existing_overhead_budget.attributes.except('id').merge(attributes))
  end
end
