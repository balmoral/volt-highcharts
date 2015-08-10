if RUBY_PLATFORM == 'opal'

require 'native'
require 'opal-highcharts'

module Highcharts
  class MainController < Volt::ModelController

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

    private

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
      @watch_counts = {}
      if reactive
        watch_animation
        watch_titles
        watch_series
      end
      @in_start = false
    end

    def bind_deep(computation, to: nil)
      bind computation, to: to, descend: true
    end

    def bind(computation, to: nil, descend: false, tag: nil)
      @bindings ||= []
      @bindings << -> do
        val = compute(computation, descend)
        if @in_start
          debug __method__, __LINE__, "bind @in_start=true not updating #{_title.to_h}"
        else
          if to.arity == 0
            to.call
          elsif to.arity == 1
            to.call tag ? tag : val
          elsif to.arity == 2
            to.call tag, val
          end
        end
      end.watch!
    end

    def compute(computation, descend = false)
      v = computation.call
      descend(v) if descend
      v
    end

    def descend(o)
      if o.is_a?(Volt::Model)
        descend_model(o)
      elsif o.is_a?(Volt::ReactiveArray)
        descend_array(o)
      elsif o.is_a?(Volt::ReactiveHash)
        descend_hash(o)
      end
    end

    def descend_array(array)
      # this way to force dependency
      array.size.times do |i|
        descend(array[i])
      end
    end

    def descend_hash(hash)
      hash.each_key do |k|
        # this way to force dependency
        descend(hash[k])
      end
    end

    def descend_model(model)
      model.attributes.each_key do |attr|
        # this way to force dependency
        descend(model.send(:"_#{attr}"))
      end
    end

    def watch_animation
      bind ->{ _animate }, to: ->{
        debug __method__, __LINE__, "_animate=#{_animate} : refresh_all_series"
        refresh_all_series
      }
    end

    def watch_titles
      [->{ _title }, ->{ _subtitle }].each do |computation|
        bind_deep computation, to: ->{ chart.set_title(_title.to_h, _subtitle.to_h, true) }
      end
    end

    def watch_series
      # watch_series_size
      watch_each_series
    end

    def watch_series_size
      watch_attributes("_series", _series, recurse: false) do |key, value|
        debug __method__, __LINE__, "_series.#{key} changed"
        refresh_all_series
      end
    end

    def watch_each_series
      # debug __method__, __LINE__, "setting watches for _series"
      _series.each_with_index do |a_series, i|
        bind ->{ a_series }, tag: i, to: ->(tag, val) do
         debug __method__, __LINE__, "chart.series[#{tag}].set_data(#{val.to_a}, true, #{_animate})"
          chart.series[tag].set_data(val.to_a, true, _animate)
        end
      end
    end

    def process_change(name, value)
      # debug __method__, __LINE__, "#{name} CHANGED"
      if name =~ /_title/ || name =~ /_subtitle/
        chart.set_title(_title.to_h, _subtitle.to_h, true) # redraw
      elsif name =~ /_series\[(.*)\]/
        inner_index = name[/\[(.*)\]/][1].to_i
        inner_series = _series[inner_index]
        if name.split('.').last == '_data'
          # debug __method__, __LINE__, "chart.series[#{inner_index}].set_data(#{value.to_a})"
          chart.series[inner_index].set_data(value.to_a, true, animate)
        else
          # debug __method__, __LINE__, "#{name} CHANGED => updating all of series[#{inner_index}]"
          chart.series[inner_index].update(inner_series.to_h, false)
          chart.redraw
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
      _series.each do |a_series|
        chart.add_series(a_series.to_h, false)
      end
      chart.redraw
      start_watching
    end

    # Create watches for attributes of a model.
    # TODO: better or built-in way ??
    def watch_attributes(name, model, recurse: true)
      if model.is_a?(Volt::ArrayModel)
        watch_array_model(name, model, recurse: recurse)
      elsif model.is_a?(Volt::Model)
        watch_model(name, model, recurse: recurse)
      end
    end

    def watch_array_model(name, model, recurse: true)
      watch_attribute("#{name}.size", model, :size)
      if recurse
        model.each_with_index do |e,i|
          if e.is_a?(Volt::Model) || e.is_a?(Volt::ArrayModel)
            watch_attributes("#{name}[#{i}]", e, recurse: recurse)
          end
        end
      end
    end

    def watch_model(owner_name, model, recurse: true)
      model.attributes.each do |attr, val|
        method = :"_#{attr}"
        name = "#{owner_name}.#{method}"
        watch_attribute(name, model, method)
        if recurse && (val.is_a?(Volt::Model) || val.is_a?(Volt::ArrayModel))
          watch_attributes(name, val, recurse: true)
        end
      end
    end

    def watch_attribute(name, model, method)
      watches << -> do
        # debug 'watch!', __LINE__, "#{name} CHANGED"
        process_change(name, model.send(method))
      end.watch!
    end

    def stop_watching
      @watches.each {|w| w.stop}
      @watches = @watch_counts = nil
    end

    def destroy_chart
      # clear all references to this chart
      i = page._charts.find_index { |e| e._id == _id }
      if i
        deleted = page._charts.delete_at(i)
        begin
          deleted._chart.destroy # TODO: sometimes this fails - why?
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
