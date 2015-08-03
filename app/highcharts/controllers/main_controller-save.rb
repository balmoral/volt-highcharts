
if RUBY_PLATFORM == 'hideaway'

module Highcharts
  class MainController < Volt::ModelController

    attr_reader :watches

    def initialize(*args)
      super
      @watches = []
    end

    def index_ready
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : #{Time.now}")

      # Get the containing html element.
      container = self.container
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : container='#{container}'")

      chart_model = attrs.chart ? attrs.chart : missing_chart
      chart_model = Volt::Model.new(chart_model.to_h) unless chart_model.is_a?(Volt::Model)
      chart_model._volt._id = random_id unless chart_model._id

      # If the view hasn't set a container id then
      # use the id in the chart options if present
      # otherwise to a random id.
      dom_id = `$(container).prop("id")`
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : initial container id is '#{dom_id}'")
      unless dom_id == nil || dom_id == 'undefined'
        dom_id = chart_model._id
        Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : char dom_id is undefined - setting to '#{dom_id}'")
        `$(container).prop("id", dom_id)`
      end

      # If :renderTo has been set in the options then it
      # should match the id of the container, otherwise
      # a Highcharts error #13 will occur. It should be
      # unique in the page. We do not check here.
      #
      # If :renderTo has not been set in the options then
      # it will be set here to the container id.
      unless chart_model._chart && chart_model._chart._renderTo
        # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : setting chart_model._chart._renderTo = '#{dom_id}'")
        (chart_model._chart ||= {})._renderTo = dom_id
      end

      # Create the highchart and add it to the page._charts.
      # page._charts ia an array of Volt::Models with an id and a highchart attribute.
      # Also set page._chart to the newly (last) created highchart.
      # Also set page._char_id to the id of the new (last) chart.
      @id = chart_model._volt._id
      @chart_model = chart_model
      @highchart = Native(`new Highcharts.Chart( #{ @chart_model.to_h.to_n } )`) # need to wrap in Native() for Volt::Model
      page._charts << Volt::Model.new({id: @id, chart: @highchart})
      page._chart = @highchart # a simple way for later access
      page._chart_id = @id # so we know whether it's me
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : page._charts='#{page._charts}' page._charts.size=#{page._charts.size}")

      # start_watching
    end

    def before_index_remove
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} #{Time.now}")
      # clear all references to this chart
      i = page._charts.find_index { |e| e._id == @id }
      if i
        deleted = page._charts.delete_at(i)
        # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : deleted='#{deleted}' page._charts.size=#{page._charts.size}")
        deleted._chart.destroy
        deleted._chart = nil
      end
      if page._chart_id == @id
        last = page._charts.last
        page._chart_id = last ? last._id : nil
        page._chart = last ? last._chart : nil
      end
      @id = @highchart = nil
      stop_watching
    end

    private

    def start_watching
      # Supported dynamic chart attributes
      #
      #   model change                : highcharts function
      #   =========================================================================
      #   model._title                : Chart.setTitle(title, subtitle)
      #   model._subtitle             : Chart.setTitle(title, subtitle)
      #
      #   model._chart._height        : Chart.setSize(width, height)
      #   model._chart._width         : Chart.setSize(width, height)
      #
      #   model._x_axis._min          : Axis.setExtremes(min, max, redraw)
      #   model._x_axis._max          : Axis.setExtremes(min, max, redraw)
      #   model._y_axis._min          : Axis.setExtremes(min, max, redraw)
      #   model._y_axis._max          : Axis.setExtremes(min, max, redraw)
      #
      #   model._x_axis._title        : Axis.setTitle(title, redraw)
      #   model._y_axis._title        : Axis.setTitle(title, redraw)
      #
      #   model.x_axis.categories     : Axis.setCategories(array_of_strings, redraw)
      #   model.y_axis.categories     : Axis.setCategories(array_of_strings, redraw)
      #
      #   model._series.size          : Chart.addSeries(options, redraw)
      #                               : Series.remove(redraw)
      #
      #   model._series[index]        : Series.update(options, redraw)
      #   model._series[index]._data  : Series.setData(array, redraw)
      #
      #   model                       : destroy chart add new one?
      #

      # TODO: this is a no-op at the moment since
      # we can't distinguish between what part of
      # the chart has changed and we're not sure
      # best way to deal with total chart update.
      watches << -> { chart_model_changed(@chart_model) }.watch!

      # Keep watch on chart size
      watches << -> { chart_size_changed(@chart_model._chart._height, :height) }.watch!
      watches << -> { chart_size_changed(@chart_model._chart._width, :width) }.watch!

      # Keep watch on chart title and subtitle
      title = @chart_model._title
      watches << -> { chart_title_changed(title, :title) }.watch!
      subtitle = @chart_model._subtitle
      watches << -> { chart_title_changed(subtitle, :subtitle) }.watch!

      # Keep watch on min and max of x and y axes.
      watches << -> { axis_extreme_changed(@chart_model._x_axis.min, :x, :min) }.watch!
      watches << -> { axis_extreme_changed(@chart_model._x_axis.max, :x, :max) }.watch!
      watches << -> { axis_extreme_changed(@chart_model._y_axis.min, :y, :min) }.watch!
      watches << -> { axis_extreme_changed(@chart_model._y_axis.max, :y, :max) }.watch!

      # TODO: Don't know how to distinguish between the data in a series
      # changing and something else in the series change. (This percolates
      # all the way up to the chart_model itself, as changes are propagated
      # from the inside out.) For now do whole series, not data level.
      @chart_model._series.each_with_index do |series, index|
        watches << -> { series_data_changed(index, series._data) }.watch!
        watches << -> { series_opts_changed(series, index) }.watch!
      end
      watches << -> { series_size_changed?(@chart_model._series.size) }.watch!
    end

    # TODO: completely update the highchart
    # with new totally new model. Don't know
    # how to without destroying existing chart
    # and creating a new instance...
    def chart_model_changed(model)
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : #{@chart_model.to_h}")
    end

    # Chart height or width has changed.
    # Highcharts only allows both height and width to be set together.
    # So it may be that if both change in our model we end up doing
    # two calls here, which may result in double render.
    # Value of 0 is default (~width/height of container)
    def chart_size_changed(val, which)
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} val=#{val} which=#{which}")
      if val
        Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : which=#{which} title=#{(title_model || {}).to_h}")
        width = which == :width ? val : 0
        height = which == :height ? val : 0
        @highchart.setSize(width, height)
      end
    end

    # Chart title or subtitle has changed.
    # Highcharts only allows both title and subtitle to be set together.
    # So it may be that if both change in our model we end up doing
    # two calls here, but probably not an issue.
    def chart_title_changed(title_model, which)
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : which=#{which} title=#{title_model}")
      # hc_options = Native(@highchart.options)
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : hc_options=#{hc_options.to_h}")
      # hc_title = which == :title ? (title_model || {}).to_h.to_n : @highchart.title
      # hc_subtitle = which == :subtitle ? (title_model || {}).to_h.to_n : @highchart.subtitle
      # @highchart.setTitle(hc_title, hc_subtitle)
    end

    # An axis extreme has changed.
    # Currently only support single X and single Y axis.
    # TODO: add support for multiple axes, here and in model definition.
    def axis_extreme_changed(val, which, extreme)
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : val=#{val} which=#{which} extreme=#{extreme}")
      # hc_axis = Native(which == :x ? @highchart.xAxis : @highchart.yAxis)[0]
      # hc_extremes = Native(hc_axis.getExtremes())
      # min = extreme == :min ? val : hc_extremes.min
      # max = extreme == :max ? val : hc_extremes.max
      # hc_axis.setExtremes(min, max)
    end

    # The number of series in the chart has changed.
    # Remove all series from highchart and add all
    # currently in our model. May be overkill, but
    # we're not to know what else may have changed
    # other than size (??).
    def series_size_changed?(size)
      model_series = @chart_model._series
      hc_series = Native(@highchart.series)
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : arg_size=#{size} model_series.size=#{model_series.size} hc_series.size=#{hc_series.size}")
      unless model_series.size == hc_series.size
        until hc_series.empty? do
          Native(hc_series[-1]).remove(false)
        end
        model_series.each do |s|
          @highchart.addSeries(s.to_h.to_n, false)
        end
        @highchart.redraw(false)
      end
    end

    # The model options of a series have changed
    # so update the series in the highchart.
    def series_opts_changed(series, index)
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : series='#{series._name}' index=#{index} series=#{series.to_h}")
      Native(@highchart.series[index]).update(series.to_h.to_n)
    end

    # The model data in a series have changed
    # so update the series data in the highchart.
    def series_data_changed(index, data)
      series = @chart_model._series[index]
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : series='#{series ? series._name : 'nil'}' index=#{index} data=#{data.to_a}")
      # Native(@highchart.series[index]).setData(data.to_n)
    end

    # Stop all watches (computations).
    def stop_watching
      until watches.empty? do
        w = watches.pop
        w.stop if w
      end
    end

    # Generate a unique id for chart container.
    def random_id
      "highcharts#{(rand * 1000000000).to_i}"
    end

    # Placeholder for missing chart in view
    def missing_chart
      { chart: { title: 'No chart attribute set for :highcharts component!!' } }
    end

  end
end

end # hideaway