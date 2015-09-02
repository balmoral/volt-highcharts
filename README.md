# Volt::Highcharts

[![Join the chat at https://gitter.im/balmoral/volt-highcharts](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/balmoral/volt-highcharts?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

A Volt component wrapping the Highcharts javascript charting library.

It depends on opal-highcharts, a gem which wraps most Highcharts and Highstock functionality in a client-side Ruby API.

Highcharts is free for non-commercial use.

See
- https://www.highcharts.com
- https://github.com/balmoral/volt-highcharts-app
- https://github.com/balmoral/volt-highcharts
- https://github.com/balmoral/opal-highcharts
- https://rubygems.org/gems/volt-highcharts
- https://rubygems.org/gems/opal-highcharts

## Installation

Add this line to your application's Gemfile:

    gem 'volt-highcharts'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install volt-highcharts

## Usage

First include the gem in the project's Gemfile:

```gem 'volt-highcharts'```

Next add volt-highcharts to the dependencies.rb file:

```component 'highcharts'```

Pass a Ruby hash containing chart options in the appropriate view html file:

```html
<:highcharts options="{{ chart_options }}" />
```

where `chart_options` is a Volt::Model or Hash provided by your controller or model. 

**Reactivity** is now supported. 

To implement a reactive chart, the options provided on chart creation should be wrapped in a Volt::Model.

**NB** reactivity is currently limited to chart titles, number of series, and individual series options and data. More coming soon.
  
Documentation for Highcharts options can be found at: http://api.highcharts.com/highcharts#chart.

For convenience, the last chart added can be accessed as ```page._chart```. 
The object returned is a Highcharts::Chart, which can be used to directly query and manipulate the chart (see opal-highcharts).
 
For example, for your controller:

```
class ChartController < Volt::ModelController
  ...
  def chart_options
    Volt::Model.new( {

      # identity the chart in volt
      id: 'fruit',
      
      # highcharts options
      chart: {
        type: 'bar',
        renderTo: 'fruit_chart'
      },
      title: {
        text: 'Fruit Consumption'
      },
      xAxis: {
        categories: %w(Apples Bananas Oranges)
      },
      yAxis: {
        title: {
            text: 'Fruit eaten'
        }
      },
      series: [
        {
          name: 'Jane',
          data: [1, 0, 4]
        },
        {
          name: 'John',
          data: [5, 7, 3]
        },
        ...
      ]
    } )
  end
end
```

and your views .html file

```
<:Title>
  volt-highcharts
<:Body>
  <span id="fruit" >
    <:highcharts options="{{ chart_options }}" />
  </span>
```

The html element which contains the chart must have an id which matches the `chart: { renderTo: } ` value.

(At present Volt 0.9.5 does not support view bindings for setting element ids, so string literals are required.)
 
To later query or modify multiple chart(s) on a page, a unique `:id` value should be set. 
  
You can then find the chart in page._charts, the elements of which are Volt::Model's each having an _id and a _chart attribute.

For example, in your controller you might have a method to return a Highcharts::Chart:

```
  def find_chart(id)
    # NB use detect, not find
    e = page._charts.detect { |e| e._id == id }
    e ? e._chart : nil
  end
```

If you only have one chart on the page use ```page._chart```.

With opal-highcharts, which completely wraps the Highcharts API in client-side Ruby (and comes bundled with volt-highcharts),
you now have simple access to query and modify methods on the chart and all of its elements. No Native wraps or backticks required. 
However, as reactivity support is improved, there should be less need for direct manipulation of the chart.

### Example
 
An example application can be found at https://github.com/balmoral/volt-highcharts-app.

See it running at https://volt-highcharts-app.herokuapp.com/.

## To do

1. chart option/configuration checks
2. improved documentation
3. reactivity for more chart options
4. Highstock specific support

## Contributing

Contributions, comments and suggestions are welcome.
 
1. Fork it ( http://github.com/balmoral/volt-highcharts/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
