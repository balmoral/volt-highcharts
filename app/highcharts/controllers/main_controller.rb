if RUBY_PLATFORM == 'opal'

require 'opal-highcharts'
require 'volt-watch'

module Highcharts
  class MainController < Volt::ModelController
    include Volt::Watch

    attr_reader :chart, :watch_counts, :reactive

    def index_ready
      set_model
      create_chart
      start_watches
    end

    def before_index_remove
      stop_watches
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

    def start_watches
      if reactive
        watch_animation
        watch_titles
        watch_series
      end
    end

    def watch_animation
      activate {
        _animate
        debug __method__, __LINE__, "__animate changed to #{_animate}"
        # refresh_all_series
      }
    end

    def watch_titles
      on_change_in(_title, _subtitle) do
        # debug __method__, __LINE__, "_title #{_title} or _subtitle #{_subtitle} changed"
        chart.set_title(_title.to_h, _subtitle.to_h, true)
      end
    end

    def watch_series
      activate {
        _series.size
        refresh_all_series
      }
      _series.size.times do |i|
        on_change_in(_series[i]) do |a_series, attr, value|
          # debug __method__, __LINE__, "_series[#{i}]: #{a_series}.#{attr} changed to #{value}"
          case attr
            when :data
              chart.series[i].set_data(value.to_a, true, _animate)
            when :visible
              visible = value.nil? ? true : value # in case not defined
              chart.series[i].set_visible(visible, true)
            else
              # something we can't set specifically changed
              chart.series[i].update(a_series.to_h.dup, true)
          end
        end
      end
    end

    # Do complete refresh of all series:
    # 1. remove all series from chart with no redraw
    # 2. add all series in model to chart with no redraw
    # 3. redraw chart
    def refresh_all_series
      until chart.series.empty? do
        chart.series.last.remove(false)
      end
      _series.each do |a_series|
        chart.add_series(a_series.to_h, false, _animate)
      end
      chart.redraw
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
