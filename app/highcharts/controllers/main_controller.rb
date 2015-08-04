

if RUBY_PLATFORM == 'opal'

require 'native'
require 'opal-highcharts'

module Highcharts
  class MainController < Volt::ModelController

    attr_reader :watches, :options, :reactive

    def initialize(*args)
      super
      @watches = []
      @options = nil
    end

    def index_ready
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : #{Time.now}")

      @options = attrs.options
      unless @options
        raise ArgumentError, "no options attribute set for :charts component"
      end
      unless @options.is_a?(Volt::Model)
        if attr.chart[:reactive]
          raise ArgumentError, ":charts options attribute must be a Volt::Model if :reactive is true"
        end
        # now convert to a Volt::Model for consistency
        @options = Volt::Model.new(@options)
      end
      # if if not given, then create one
      @id = options._id || random_id
      @reactive = options._reactive

      # Create the chart and add it to the page._charts.
      # page._charts ia an array of Volt::Models with an id and a chart attribute.
      # Also set page._chart to the newly (last) created Highcharts::Chart.
      # Also set page._char_id to the id of the new (last) chart.
      @chart = Highcharts::Chart.new(@options.to_h)
      page._charts << Volt::Model.new({id: @id, chart: @chart})
      page._chart = @chart
      page._chart_id = @id

      # keep an eye on the model for changes
      start_watching
    end

    def before_index_remove
      stop_watching
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
      @id = @chart = @options = nil
    end

    private

    def start_watching
      @watches = []
      if reactive
        watch_titles
        watch_series
      end
    end

    def watch_titles
      @watches << -> do
        log_change "#{self.class.name}##{__method__}:#{__LINE__} : set_title(#{@options._title} #{@options._subtitle})"
        @options._title._text
        @options._subtitle._text
        @chart.set_title(
          @options._title,
          @options._subtitle,
          true # redraw
        )
      end.watch!
    end

    def watch_series
      @series_size = options._series.size
      @watches << -> do
        size = options._series.size
        if size == @series_size
          options._series.each_with_index do |series, index|
            @watches << -> do
              log_change "@@@  options._series[#{index}] changed", series
              @watches << -> do
                data = series._data
                log_change "@@@ options._series[#{index}]._data changed", data
              end.watch!
            end.watch!
          end
        else
          log_change "@@@  options._series.size changed to ", size
          @series_size = size
        end
      end.watch!
    end

    def log_change(label, object = 'nil')
        Volt.logger.debug "#{self.class.name}##{__method__} : #{label} : #{object}"
    end

    def stop_watching
      @watches.each {|w| w.stop}
      @watches = []
    end

    # Generate a reasonably unique id for chart container.
    def random_id
      "hc_#{(rand * 1000000000).to_i}"
    end

  end
end

end # RUBY_PLATFORM == 'opal'
