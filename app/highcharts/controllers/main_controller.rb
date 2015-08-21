if RUBY_PLATFORM == 'opal'

require 'native'
require 'opal-highcharts'
require 'reactor'

module Highcharts
  class MainController < Volt::ModelController
    include Reactor

    attr_reader :chart, :watches, :watch_counts, :reactive

    def index_ready
      set_model
      create_chart
      start_watching
    end

    def before_index_remove
      stop_watching
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

    # To be reactive we must watch for model changes
    def start_watching
      @in_start = true
      @watches = []
      if reactive
        watch_animation
        watch_titles
        watch_series
      end
      @in_start = false
    end

    def watch_animation
      watch(->{ _animate }) do
        # debug __method__, __LINE__, "_animate=#{_animate} : refresh_all_series"
        refresh_all_series
      end
    end

    def watch_titles
      [->{ _title }, ->{ _subtitle }].each do |computation|
        watch(computation, descend: true) do
          chart.set_title(_title.to_h, _subtitle.to_h, true)
        end
      end
    end

    def watch_series
      # watch_series_size
      watch_series_data
      watch_series_visibility
      watch_series_other
    end

    def watch_series_other
      _series.each_with_index do |a_series, i|
        watch ->{ a_series }, descend: true, tag: i, except: [:_data, :visible] do |tag, val|
          # debug __method__, __LINE__, "chart.series[#{tag}].update(#{val.to_h}, true)"
          chart.series[tag].update(val.to_h, true)
        end
      end
    end

    def watch_series_data
      _series.each_with_index do |a_series, i|
        watch ->{ a_series._data }, tag: i do |tag, val|
          # debug __method__, __LINE__, "chart.series[#{tag}].set_data(#{val.to_a}, true, #{_animate})"
          chart.series[tag].set_data(val.to_a, true, _animate)
        end
      end
    end

    def watch_series_visibility
      _series.each_with_index do |a_series, i|
        watch ->{ a_series._visible }, tag: i do |tag, val|
          # debug __method__, __LINE__, "chart.series[#{tag}].set_visible(#{val}, true)"
          chart.series[tag].set_data(val.to_a, true)
        end
      end
    end

    def watch_series_size
      watch_attributes("_series", _series, recurse: false) do |key, value|
        # debug __method__, __LINE__, "_series.#{key} changed"
        refresh_all_series
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
      _series.each do |a_series|
        chart.add_series(a_series.to_h, false)
      end
      chart.redraw
      start_watching
    end

    def stop_watching
      @watches.each {|w| w.stop}
      @watches = nil
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

    def watch(computation, descend: false, tag: nil, except: nil, &block)
      use_reactor = true
      if use_reactor
        bind computation, condition: ->{ !@in_start}, descend: false, tag: nil, except: nil, &block
      else
        @watches ||= []
        @watches << -> do
          val = compute(computation, descend, except)
          unless @in_start
            if block.arity == 0
              block.call
            elsif block.arity == 1
              block.call(tag ? tag : val)
            elsif block.arity == 2
              block.call(tag, val)
            end
          end
        end.watch!
      end
    end

    def compute(computation, descend, except)
      v = computation.call
      descend(v, except) if descend
      v
    end

    def descend(o, except)
      if o.is_a?(Volt::Model)
        descend_model(o, except)
      elsif o.is_a?(Volt::ReactiveArray)
        descend_array(o, except)
      elsif o.is_a?(Volt::ReactiveHash)
        descend_hash(o, except)
      end
    end

    def descend_array(array, except)
      # this way to force dependency
      array.size.times do |i|
        descend(array[i], except)
      end
    end

    def descend_hash(hash, except)
      hash.each_key do |k|
        # this way to force dependency
        descend(hash[k], except)
      end
    end

    def descend_model(model, except)
      model.attributes.each_key do |attr|
        # this way to force dependency
        _attr = :"_#{attr}"
        unless except && except.include?(_attr)
          descend(model.send(_attr), except)
        end
      end
    end

    def debug(method, line, s = nil)
      Volt.logger.debug "#{self.class.name}##{method}[#{line}] : #{s}"
    end

  end
end

end # RUBY_PLATFORM == 'opal'
