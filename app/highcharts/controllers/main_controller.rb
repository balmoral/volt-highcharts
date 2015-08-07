if RUBY_PLATFORM == 'opal'

require 'native'
require 'opal-highcharts'

module Highcharts
  class MainController < Volt::ModelController

    attr_reader :chart, :watches, :watch_counts, :reactive, :animate

    def index_ready
      set_model
      create_chart
      start_watching
    end

    def before_index_remove
      stop_watching
      update_page
      @chart = nil
    end

    private

    def set_model
      options = attrs.options
      unless options
        raise ArgumentError, 'no options attribute set for :highcharts component'
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
      @animate = _animate == true
    end

    # Create the chart and add it to the page._charts.
    # page._charts ia an array of Volt::Models with an id and a chart attribute.
    # Also set page._chart to the newly (last) created Highcharts::Chart.
    # Also set page._char_id to the id of the new (last) chart.
    def create_chart
      @chart = Highcharts::Chart.new(model.to_h)
      page._charts << {id: _id, chart: @chart}
      page._chart = @chart
      page._chart_id = _id
    end

    # To be reactive we must watch for model changes
    def start_watching
      @watches = []
      @watch_counts = {}
      if reactive
        watch_titles
        watch_series
      end
    end

    def watch_titles
      watches << -> do
        setup_dependencies(_title)
        setup_dependencies(_subtitle)
        chart.set_title(_title.to_h, _subtitle.to_h, true) # redraw
      end.watch!
    end

    def watch_series
      watch_series_size
      watch_each_series
    end

    def watch_series_size
      @series_size = _series.size
      watches << -> do
        unless _series.size == @series_size
          @each_series_watch.stop if @each_series_watch
          @series_size = _series.size
          refresh_all_series
        end
      end.watch!
    end

    def watch_each_series
      watches << -> do
        debug __method__, __LINE__
        _series.size.times do |index|
          watches << -> do
            debug __method__, __LINE__, "series[#{index}],_data changed"
            data = _series[index]._data
            chart.series[index].set_data(data.to_a, true, animate)
          end.watch!
          watches << -> do
            debug __method__, __LINE__, "series[#{index}] something changed"
            setup_dependencies(_series[index], nest: true, except: [:data])
            chart.series[index].update(_series.to_h, true)
          end.watch!
        end.watch!
      end
      @each_series_watch = watches.last
    end

    # Do complete refresh of all series:
    # 1. remove all series from chart with no redraw
    # 2. add all series in model to chart with no redraw
    # 3. redraw chart
    def refresh_all_series
      until chart.series.empty? do
        chart.series.last.remove(false)
      end
      _series.each_with_index do |a_series, index|
        chart.add_series(a_series.to_h, false)
      end
      chart.redraw
    end

    # Force computation dependencies for attributes of a model
    # TODO: must be better or built-in way ??
    def setup_dependencies(model, nest: true, except: [])
      model.attributes.each { |key, val|
        unless except.include?(key)
          model.send :"_#{key}"
        end
        if nest && val.is_a?(Volt::Model)
          setup_dependencies(val, nest: true, except: except)
        end
      }
    end

    def stop_watching
      @watches.each {|w| w.stop}
      @watches = @watch_counts = nil
    end

    def update_page
      # clear all references to this chart
      i = page._charts.find_index { |e| e._id == _id }
      if i
        deleted = page._charts.delete_at(i)
        deleted._chart.destroy
        deleted._chart = nil
      end
      if page._chart_id == _id
        last = page._charts.last
        page._chart_id = last ? last._id : nil
        page._chart = last ? last._chart : nil
      end
    end

    def debug(method, line, s)
      Volt.logger.debug "#{self.class.name}##{method}[#{line}] : #{s}"
    end

    def log_change(label, object = 'nil')
      Volt.logger.debug "#{label} : #{object}"
    end

  end
end

end # RUBY_PLATFORM == 'opal'
