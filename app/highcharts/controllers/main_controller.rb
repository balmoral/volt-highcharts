if RUBY_PLATFORM == 'opal'

require 'native'
require 'opal-highcharts'

module Highcharts
  class MainController < Volt::ModelController

    attr_reader :chart, :watches, :watch_counts

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
      unless options.is_a?(Volt::Model)
        # check the reactive option is not true for a Hash
        if attr.chart[:reactive]
          raise ArgumentError, ':chart options attribute must be a Volt::Model if [:reactive] is true'
        end
        # convert Hash to Volt::Model
        options = Volt::Model.new(options)
      end
      # set controller's model to options, which captures its methods for self
      self.model = options
      debug __method__, __LINE__, "model._id = #{_id}"
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
      if _reactive
        watch_titles
        watch_series
      end
    end

    def watch_titles
      watches << -> do
        # force dependencies TODO: must be better way
        [_title, _subtitle].each do |t|
          reference_attributes(t)
        end
        log_change "#{self.class.name}##{__method__}:#{__LINE__} : chart.set_title(#{_title.to_h} #{_subtitle.to_h})"
        chart.set_title(_title.to_h, _subtitle.to_h, true) # redraw
      end.watch!
    end

    def watch_series
      @series_size = _series.size
      watches << -> do
        size = _series.size
        if size == @series_size
          _series.each_with_index do |a_series, index|
            watches << -> do
              log_change "@@@  _series[#{index}] changed", a_series
              watches << -> do
                data = a_series._data
                log_change "@@@ _series[#{index}]._data changed", data
              end.watch!
            end.watch!
          end
        else
          log_change "@@@  _series.size changed to ", size
          @series_size = size
        end
      end.watch!
    end

    def reference_attributes(model, except = [])
      model.attributes.each { |k,v|
        unless except.include?(k)
          debug __method__, __LINE__, "#{t}.send(#{k})"
          t.send :"_#{k}"
        end
      }
    end

    def stop_watching
      @watches.each {|w| w.stop}
      @watches = @watch_counts = nil
    end

    def update_page
      debug __method__, _LINE__, Time.now.to_s
      # clear all references to this chart
      i = page._charts.find_index { |e| e._id == _id }
      if i
        deleted = page._charts.delete_at(i)
        debug __method__, __LINE__, "deleted='#{deleted}' page._charts.size=#{page._charts.size}"
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
