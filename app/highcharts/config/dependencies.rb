# Component dependencies

if RUBY_PLATFORM == 'opal'
  Opal.use_gem('opal-highcharts')
end

# highcharts.js is not required if highstock is loaded
# javascript_file 'http://code.highcharts.com/highcharts.src.js'
javascript_file 'https://code.highcharts.com/highcharts.src.js'
javascript_file 'https://code.highcharts.com/highcharts-more.js'
javascript_file 'https://code.highcharts.com/modules/exporting.js'
# javascript_file 'http://code.highcharts.com/maps/highmaps.src.js'

