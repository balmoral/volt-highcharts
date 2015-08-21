if RUBY_PLATFORM == 'opal'

# requires now in app/highcharts/initializers/client/gems.rb
require 'opal-highcharts'
require 'volt-reactor'

module Highcharts
  class MainController < Volt::ModelController
    include Volt::Reactor

    attr_reader :chart, :bind_counts, :reactive

    def index_ready
      set_model
      create_chart
      start_reactor
    end

    def before_index_remove
      stop_reactor
      destroy_chart
      @chart = nil
    end

    protected

    def set_model
      options = attrs.options
      unless options
        raise ArgumentError, 'options attribute must be given for :highcharts component'
      end
      # if the options are a Hash then convert to a Volt::Model
      if options.is_a?(Volt::Model)
        @reactive = true
      else
        options = Volt::Model.new(options)
        @reactive = false
      end
      # set controller's model to options, which captures its methods for self
      self.model = options
    end

    # Create the chart and add it to the page._charts.
    # page._charts is an array of Volt::Models each having an _id and a _chart (Highcharts::Chart) attribute.
    # Also set page._chart to the newly (last) created Highcharts::Chart.
    # Also set page._char_id to the id of the new (last) chart.
    def create_chart
      @chart = Highcharts::Chart.new(model.to_h)
      page._charts << {id: _id, chart: @chart}
      page._chart = @chart
      page._chart_id = _id
    end

    def start_reactor
      @in_start = true
      if reactive
        puts "starting reactor"
        bind_animation
        bind_titles
        bind_series
      end
      @in_start = false
    end

    def bind_animation
      bind(->{ _animate }, condition: ->{ !@in_start} ) do
        debug __method__, __LINE__, "_animate=#{_animate} : refresh_all_series"
        refresh_all_series
      end
    end

    def bind_titles
      [->{ _title }, ->{ _subtitle }].each do |computation|
        bind(computation, condition: ->{ !@in_start}, descend: true) do
          chart.set_title(_title.to_h, _subtitle.to_h, true)
        end
      end
    end

    def bind_series
      # bind_series_size
      bind_series_data
      bind_series_visibility
      bind_series_other
    end

    def bind_series_other
      _series.each_with_index do |a_series, i|
        bind(->{ a_series }, condition: ->{ !@in_start}, descend: true, tag: i, except: [:_data, :visible]) do |tag, val|
          debug __method__, __LINE__, "chart.series[#{tag}].update(#{val.to_h}, true)"
          chart.series[tag].update(val.to_h, true)
        end
      end
    end

    def bind_series_data
      _series.each_with_index do |a_series, i|
        bind(->{ a_series._data }, condition: ->{ !@in_start}, tag: i) do |tag, val|
          debug __method__, __LINE__, "chart.series[#{tag}].set_data(#{val.to_a}, true, #{_animate})"
          chart.series[tag].set_data(val.to_a, true, _animate)
        end
      end
    end

    def bind_series_visibility
      _series.each_with_index do |a_series, i|
        bind(->{ a_series._visible }, condition: ->{ !@in_start}, tag: i) do |tag, val|
          debug __method__, __LINE__, "chart.series[#{tag}].set_visible(#{val}, true)"
          chart.series[tag].set_data(val.to_a, true)
        end
      end
    end

    def bind_series_size
      bind_attributes("_series", _series, condition: ->{ !@in_start}, recurse: false) do |key, value|
        debug __method__, __LINE__, "_series.#{key} changed"
        refresh_all_series
      end
    end

    # Do complete refresh of all series:
    # 1. remove all series from chart with no redraw
    # 2. add all series in model to chart with no redraw
    # 3. redraw chart
    def refresh_all_series
      stop_reactor
      until chart.series.empty? do
        chart.series.last.remove(false)
      end
      _series.each do |a_series|
        chart.add_series(a_series.to_h, false)
      end
      chart.redraw
      start_reactor
    end

    def stop_reactor
      puts "stop_reactor"
      super
    end

    def destroy_chart
      # clear all references to this chart
      i = page._charts.find_index { |e| e._id == _id }
      if i
        deleted = page._charts.delete_at(i)
        begin
          deleted._chart.destroy # TODO: sometimes this fails - seems ok since volt-0.9.5.pre4 after 2015-08-10
        rescue Exception => x
          debug __method__, __LINE__, "chart._destroy failed: #{x}"
        end
        deleted._chart = nil
      end
      if page._chart_id == _id
        last = page._charts.last
        # last = page._charts.empty? ? nil : page._charts.last # bug in ReactiveArray
        page._chart_id = last ? last._id : nil
        page._chart = last ? last._chart : nil
      end
    end

    def debug(method, line, s = nil)
      Volt.logger.debug "#{self.class.name}##{method}[#{line}] : #{s}"
    end

  end
end

end # RUBY_PLATFORM == 'opal'
