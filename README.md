# Volt::Highcharts

A Volt component wrapping the Highcharts javascript charting tool.

Highcharts is free for non-commercial use.

http://www.highcharts.com/products/highcharts

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

where `chart_options` is provided by your controller or model. Any object which responds to #to_h may be used, including of course a Volt::Model.

Documentation for Highcharts options can be found at: http://api.highcharts.com/highcharts#chart.

At present only a copy of the chart options are passed to Highcharts so the binding will not update the chart automatically.
 
For convenience, the last chart added can simply be accessed as ```page._chart```, wrapped by Opal's Native().
 
To query or modify multiple chart(s) on the page a unique :id should be set in each chart's options. 

For example:
```
    def fruit_chart_options
      {
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
      }
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

You can dynamically query or modify the chart(s) using Opal's Native() or inline scripting.

The chart object(s) found in ```page._chart``` and ```page._charts``` have been wrapped in Opal's Native(). This is because Volt::Model and Volt::ArrayModel can only hold Ruby objects.   

Opal's Native() wraps a JS object to provide access to properties and functions in the JS object via Ruby method calls. As of writing (July 30, 2015) Native has not yet been documented. If you prefer to use backticks or %x{} to inline JS code you can get the JS object using #to_n.

For example, to change a series in a chart using Native(), you might do:
```
  def update_sales
    e = page._charts.find { |e| e._id == 'sales' }
    series = Native(e._chart.series)
    Native(series[0]).setData(sales_data.to_n)
  end
```
The equivalent using backticks is:
```
  def update_sales
    native_chart = page._chart.to_n # get the native JS chart
    native_data = sales_data.to_n # get native sales data
    `native_chart.series[0].setData(native_data)`
  end
```

Always use #to_n to convert Ruby data to JS when passing to Highcharts.

In the future we hope to provide a fully wrapped Ruby implementation of Highcharts.

## Contributing

The author is new to things javascript, opal and volt, so contributions and suggestions are very welcome.
 
1. Fork it ( http://github.com/balmoral/volt-highcharts/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
