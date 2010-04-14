class ChartsController < ApplicationController

  unloadable

  menu_item :charts

  before_filter :find_project

  before_filter :authorize, :only => [:index]

  def controller_name
    "charts"
  end

  # Show main page with conditions form and chart
  def index
    @title = get_title

    @show_conditions = false

    if show_date_condition
      @date_condition = true
      @show_conditions = true
    else
      @date_condition = false
    end

    if show_pages
      @show_pages = true
    end

    unless get_grouping_options.empty?
      @grouping_options = RedmineCharts::GroupingUtils.to_options(get_grouping_options)
      @show_conditions = true
    else
      @grouping_options = []
    end

    @textconditions_options = []

    unless get_conditions_options.empty?
      @conditions_options = RedmineCharts::ConditionsUtils.to_options(get_conditions_options, @project.id)
      @textconditions_options = @conditions_options.select { |c1,c2| c2.nil? }
      @conditions_options = @conditions_options.select { |c1,c2| not c2.nil? }
      @show_conditions = true
    else
      @conditions_options = []
    end

    unless get_multiconditions_options.empty?
      @multiconditions_options = RedmineCharts::ConditionsUtils.to_options(get_multiconditions_options, @project.id)
      @textconditions_options = @multiconditions_options.select { |c1,c2| c2.nil? }
      @multiconditions_options = @multiconditions_options.select { |c1,c2| not c2.nil? }
      @show_conditions = true
    else
      @multiconditions_options = []
    end

    @show_left_column = @show_conditions

    unless get_help.blank?
      @help = get_help
      @show_left_column = true
    else
      @help = nil
    end

    @range = RedmineCharts::RangeUtils.from_params(params)
    @pagination = RedmineCharts::PaginationUtils.from_params(params)
    @grouping = RedmineCharts::GroupingUtils.from_params(get_grouping_options, params)
    @conditions = RedmineCharts::ConditionsUtils.from_params(get_conditions_options + get_multiconditions_options, @project.id, params)

    create_chart

    if @error
      @error_message = l(@error)
    end

    render :template => "charts/index"
  end

  protected

  # Return data for chart
  def create_chart
    chart = OpenFlashChart.new

    data = get_data

    if data[:error]
      @error = data[:error]
      @data = nil
    else
      get_converter.convert(chart, data)

      if get_y_legend
        y = YAxis.new
        y.set_range(0,(data[:max]*1.2).round,(data[:max]/get_y_axis_labels).round) if data[:max]
        chart.y_axis = y
      end

      if get_x_legend
        x = XAxis.new
        x.set_range(0,data[:count] > 1 ? data[:count] - 1 : 1,1) if data[:count]
        if data[:labels]
          labels = []
          if get_x_axis_labels > 0
            step = (data[:labels].size/get_x_axis_labels).to_i
            step = 1 if step == 0
          else
            step = 1
          end
          data[:labels].each_with_index do |l,i|
            if i % step == 0
              labels << l
            else
              labels << ""
            end
          end
          x.set_labels(labels)
        end
        chart.x_axis = x
      else
        x = XAxis.new
        x.set_labels([""])
        chart.x_axis = x
      end

      unless get_x_legend.nil?
        legend = XLegend.new(get_x_legend)
        legend.set_style('{font-size: 12px}')
        chart.set_x_legend(legend)
      end

      unless get_x_legend.nil?
        legend = YLegend.new(get_y_legend)
        legend.set_style('{font-size: 12px}')
        chart.set_y_legend(legend)
      end

      chart.set_bg_colour('#ffffff');

      @data = chart.to_s
    end
  end

  def title
    get_title
  end

  # Returns chart title
  def get_title
    nil
  end

  # Returns chart type: line, pie or stack
  def get_type
    :line
  end

  # Returns help string, displayed above chart
  def get_help
    nil
  end

  # Returns data for chart
  def get_data
    raise "overwrite it"
  end

  # Returns hints for given record and grouping type
  def get_hints(record)
    nil
  end

  # Returns Y legend
  def get_x_legend
    nil
  end

  # Returns Y legend
  def get_y_legend
    nil
  end

  # Returns how many labels should be displayed on x axis. 0 means all labels.
  def get_x_axis_labels
    5
  end

  # Returns how many labels should be displayed on y axis. 0 means all labels.
  def get_y_axis_labels
    5
  end

  # Returns true if date condition should be displayed
  def show_date_condition
    false
  end

  # Returns true if pagination should be displayed
  def show_pages
    false
  end
  
  # Returns values for grouping options
  def get_grouping_options
    []
  end

  # Returns type of conditions available for that chart
  def get_conditions_options
    []
  end

  # Returns type of conditions available for that chart
  def get_multiconditions_options
    []
  end

  private

  # Returns converter for given chart type
  def get_converter
    eval("RedmineCharts::#{get_type.to_s.camelize}DataConverter")
  end

  # Finds current project or raises 404
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end
