module Highcharts
  class MainController < Volt::ModelController

    def index_ready
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : #{Time.now}")

      # Get the containing html element.
      container = self.container
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : container='#{container}'")

      opts = attrs.chart ? attrs.chart.to_h : missing_chart

      # If the view hasn't set a container id then
      # use the id in the chart options if present
      # otherwise to a random id.
      id = `$(container).prop("id")`
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : initial container id is '#{id}'")
      unless id == nil || id == 'undefined'
        id = opts[:id] || random_id
        Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : char container id is undefined - setting to '#{id}'")
        `$(container).prop("id", id)`
      end

      # If :renderTo has been set in the options then it
      # should match the id of the container, otherwise
      # a Highcharts error #13 will occur. It should be
      # unique in the page. We do not check here.
      #
      # If :renderTo has not been set in the options then
      # it will be set here to the container id.
      unless opts[:chart] && opts[:chart][:renderTo]
        Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : setting opts[:chart][:renderTo]='#{id}'")
        (opts[:chart] ||= {})[:renderTo] = id
      end

      # Render the chart and add it to the page._charts.
      # _charts ia an array of Volt::Models with an id and a chart attribute.
      @id = opts[:id] || id
      chart = Native(`new Highcharts.Chart( #{opts.to_n} )`) # needs to wrapped for Volt::Model
      page._charts << Volt::Model.new({id: @id, chart: chart})
      page._chart = chart # a simple way for later access
      page._chart_id = id # so we know whether it's me
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : page._charts='#{page._charts}' page._charts.size=#{page._charts.size}")
    end

    def before_index_remove
      Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} #{Time.now}")
      # clear all references to this chart
      i = page._charts.find_index { |e| e._id == @id }
      if i
        deleted = page._charts.delete_at(i)
        Volt.logger.debug("#{self.class.name}##{__method__}:#{__LINE__} : deleted='#{deleted}' page._charts.size=#{page._charts.size}")
        deleted._chart.destroy
        deleted._chart = nil
      end
      page._chart = nil if page._chart_id == @id
      @id = nil
    end

    private

    # generate a unique id for chart container
    def random_id
      "highcharts#{(rand * 1000000000).to_i}"
    end

    def missing_chart
      { chart: { title: 'no chart attribute set for :highcharts component' } }
    end

  end
end