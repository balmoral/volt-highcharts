

if RUBY_PLATFORM == 'opal'

require 'native'
require 'opal-highcharts'

module Highcharts
  class MainController < Volt::ModelController

    attr_reader :watches, :chart_options, :reactive

    def initialize(*args)
      super
      @watches = []
      @chart_options = nil
    end

    def index_ready
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : #{Time.now}")

      @chart_options = attrs.options
      unless @chart_options
        raise ArgumentError, "no options attribute set for :highcharts component"
      end
      unless @chart_options.is_a?(Volt::Model)
        if attr.chart[:reactive]
          raise ArgumentError, ":highcharts options attribute must be a Volt::Model if :reactive is true"
        end
        # now convert to a Volt::Model for consistency
        @chart_options = Volt::Model.new(@chart_options)
      end
      # if if not given, then create one
      @id = chart_options._id || random_id
      @reactive = chart_options._reactive

      # Create the highchart and add it to the page._charts.
      # page._charts ia an array of Volt::Models with an id and a highchart attribute.
      # Also set page._chart to the newly (last) created highchart.
      # Also set page._char_id to the id of the new (last) chart.
      @highchart = Highcharts::Chart.new(@chart_options.to_h)
      page._charts << Volt::Model.new({id: @id, chart: @highchart})
      page._chart = @highchart
      page._chart_id = @id

      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : page._charts='#{page._charts}' page._charts.size=#{page._charts.size}")
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : @highchart.config=#{@highchart.config.colors}")
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : @highchart.series=#{@highchart.series.first.name}")
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
      @id = @highchart = nil
    end

    private

    def start_watching
      return unless reactive
    end

    def stop_watching
    end

    # Generate a reasonably unique id for chart container.
    def random_id
      "hc_#{(rand * 1000000000).to_i}"
    end

  end
end

end # RUBY_PLATFORM == 'opal'
