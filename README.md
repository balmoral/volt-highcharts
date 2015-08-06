# Volt::Highcharts

A Volt component wrapping the Highcharts javascript charting tool.

It depends on opal-highcharts, a gem which wraps most Highcharts and Highstock functionality in a client-side Ruby API.

Highcharts is free for non-commercial use.

http://www.highcharts.com/products/highcharts
http://github.com/balmoral/volt-highcharts
https://rubygems.org/gems/volt-highcharts

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
<:highcharts chart="{{ chart_options }}" />
```

where `chart_options` is a Volt::Model or Hash provided by your controller or model. 

Reactivity is now supported. 

To implement a reactive chart, the options provided on chart creation should be wrapped in a Volt::Model.

NB reactivity is currently limited to chart titles, number of series, and individual series options and data. More coming soon.
  
Documentation for Highcharts options can be found at: http://api.highcharts.com/highcharts#chart.

For convenience, the last chart added can be accessed as ```page._chart```. 
The object returned is a Highcharts::Chart, which can be used to directly query and manipulate the chart (see opal-highcharts).
 
To query or modify multiple chart(s) on the page a unique :id should be set in each chart's options. 

For example:
```
    def fruit_chart_options
      Volt::Model.new( {
        # to identity the chart in volt
        id: 'fruit_chart',
        
        # highcharts options
        chart: {
          type: 'bar'
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
```

You can later find the chart in page._charts, the elements of which are Volt::Model's each having an _id and a _chart attribute.

For example, in your controller you might have a method to return the native chart:
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

As reactivity support is improved, there should be less need for direct manipulation of the chart.
 
## To do

1. remove debug traces
2. chart option/configuration checks
3. improved documentation
4. improved error handling
5. finer grained reactivity?

## Contributing

Contributions, comments and suggestions are welcome.
 
1. Fork it ( http://github.com/balmoral/volt-highcharts/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
