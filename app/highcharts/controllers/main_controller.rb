

if RUBY_PLATFORM == 'opal'

require 'native'
require 'opal-highcharts'

module Highcharts
  class MainController < Volt::ModelController

    attr_reader :watches

    def initialize(*args)
      super
      @watches = []
    end

    def index_ready
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : #{Time.now}")

      chart_model = attrs.chart ? attrs.chart : missing_chart
      chart_model = Volt::Model.new(chart_model.to_h) unless chart_model.is_a?(Volt::Model)

      # Create the highchart and add it to the page._charts.
      # page._charts ia an array of Volt::Models with an id and a highchart attribute.
      # Also set page._chart to the newly (last) created highchart.
      # Also set page._char_id to the id of the new (last) chart.
      @id = chart_model._id
      @chart_model = chart_model
      @highchart = Highcharts::Chart.new(@chart_model.to_h)
      page._charts << Volt::Model.new({id: @id, chart: @highchart})
      page._chart = @highchart # a simple way for later access
      page._chart_id = @id # so we know whether it's me
      # Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : page._charts='#{page._charts}' page._charts.size=#{page._charts.size}")

      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : @highchart.config=#{@highchart.config.colors}")
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : @highchart.series=#{@highchart.series.first.name}")

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
    end

    private

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

end # RUBY_PLATFORM == 'opal'
