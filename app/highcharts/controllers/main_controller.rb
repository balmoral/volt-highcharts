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
      watch_attributes('_title', _title) do |key, value|
        debug __method__, __LINE__, "#{key} CHANGED => updating titles"
        chart.set_title(_title.to_h, _subtitle.to_h, true) # redraw
      end
      watch_attributes('_subtitle', _subtitle) do |key, value|
        debug __method__, __LINE__, "#{key} CHANGED => updating titles"
        chart.set_title(_title.to_h, _subtitle.to_h, true) # redraw
      end
    end

    def watch_series
      # watch_series_size
      watch_each_series
    end

    def watch_series_size
      watch_attributes("_series", _series, nest: false) do |key, value|
        debug __method__, __LINE__, "_series.#{key} changed"
        refresh_all_series
      end
    end

    def watch_each_series
      _series.each_with_index do |outer_series, outer_index|
        debug __method__, __LINE__, "setting watches for series[#{outer_index}]"
        watch_attributes("_series[#{outer_index}]", outer_series, nest: true) do |key, value|
          inner_index = [/\[(.*)\]/][1].to_i
          inner_series = _series[inner_index]
          debug __method__, __LINE__, "#{key} CHANGED"
          case
            when key =~ /\._data/
              debug __method__, __LINE__, "chart.series[#{inner_index}].set_data(#{value.to_a})"
              chart.series[inner_index].set_data(value.to_a, true, animate)
            else
              debug __method__, __LINE__, "#{key} CHANGED => updating all of series[#{inner_index}]"
              chart.series[inner_index].update(inner_series.to_h, true)
          end
        end
      end
    end

    # Do complete refresh of all series:
    # 1. remove all series from chart with no redraw
    # 2. add all series in model to chart with no redraw
    # 3. redraw chart
    def refresh_all_series
      stop_watching
      until chart.series.empty? do
        chart.series.last.remove(false)
      end
      _series.each_with_index do |a_series, index|
        chart.add_series(a_series.to_h, false)
      end
      chart.redraw
      start_watching
    end

    # Create watches for (nested) attributes of a model.
    # TODO: better or built-in way ??
    def watch_attributes(owner, model, nest: true, &block)
      if model.is_a?(Volt::ArrayModel)
        watch_attribute(model, "#{owner}.size", :size, &block)
      else
        model.attributes.each do |attr, val|
          method = :"_#{attr}"
          key = "#{owner}.#{method}"
          watch_attribute(model, key, method, &block)
          if nest && (val.is_a?(Volt::Model) || val.is_a?(Volt::Model))
            watch_attributes(key, nest: true, except: except, &block)
          end
        end
      end
    end

    # Having watch_attribute in separate method ensures
    # correct scope of local variables for the proc
    # being watched.
    def watch_attribute(model, key, method, &block)
      watches << -> do
        debug 'watch!', __LINE__, "#{key} CHANGED"
        block.call key, model.send(method)
      end.watch!
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

    def debug(method, line, s = nil)
      Volt.logger.debug "#{self.class.name}##{method}[#{line}] : #{s}"
    end

  end
end

end # RUBY_PLATFORM == 'opal'
