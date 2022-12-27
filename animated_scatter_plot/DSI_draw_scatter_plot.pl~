#!/usr/bin/perl
use strict;
use warnings;
binmode(STDOUT, ":utf8");

### Load modules ###
use Text::CSV;
use Carp qw< croak >;
use Time::Piece;

### Get input files from user ###
my $usage = "$0 country_group_file data_table [scatter, residuals, group_residuals]";
unless ( $ARGV[0] && $ARGV[1] && $ARGV[2] ) { die "\n$usage\n\n" }

### Config
my @groups_to_plot = ('BRICS','G77','OECD');
my $start_year = 1986;
my $end_year = 2022;
my $six_month = 1; # filter data to only plot each half year?

# Read the country group file
my %country_grps = &readCountryGrps($ARGV[0]); # group->country simplified name->1

# Read the data table
my %data;
my @dates;
&readProcessedData($ARGV[1]); # fills %data, country->(use or provide)->array of values

# Output a chart
&start_html();

if ($ARGV[2] eq 'scatter') {
	&drawChart();
} elsif ($ARGV[2] eq 'residuals') {
	&drawChartResiduals();
} elsif ($ARGV[2] eq 'group_residuals') {
	&drawChartResidualsGroups();
}

&print_tail();

exit;


sub readCountryGrps {
	my $filepath = shift;
	
	my %country_grps_local;
	
	my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1, skip_empty_rows => 1 });
	open my $fh, "<:encoding(utf8)", $filepath or die "$filepath: $!";
	
	$csv->column_names( $csv->getline($fh) );
	while ( my $row = $csv->getline_hr($fh) ) {
		if ( $row->{COUNTRY} && $row->{GRP} ) {
			$country_grps_local{$row->{GRP}}->{$row->{COUNTRY}} = 1;
		}
	}
	close $fh;
	return %country_grps_local;
}

sub readProcessedData {
	my $filepath = shift;
	
	my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1, skip_empty_rows => 1 });
	open my $fh, "<:encoding(utf8)", $filepath or die "$filepath: $!";
	
	$csv->column_names( $csv->getline($fh) );
	while ( my $row = $csv->getline_hr($fh) ) {
		
	    # Parse the date information
		my $datetime = Time::Piece->strptime($row->{Date},'%Y-%m-%dT%T');
		next if ($datetime->year < $start_year || $datetime->year > $end_year);
		if ( $six_month ) {
			next unless ($datetime->mon == 1 || $datetime->mon == 6); # Only plot half-year increments
		}
		push @dates, $datetime;
		
		# foreach element in row
		foreach my $key ( keys %{$row} ) {
			my $country;
			
			# Process date information
			if ( $key eq 'Date' ) {
				next;
			} elsif ( $key =~ /^(.*?)\s+\[uses from\]$/ ) {
				$country = $1;
				push @{$data{$country}->{use}}, $row->{$key};
			} elsif ( $key =~ /^(.*?)\s+\[provides to\]$/ ) {
				$country = $1;
				push @{$data{$country}->{provide}}, $row->{$key};
			} else {
				die "something went wrong when try to parse data for $key";
			}
		}
	}
	
	close $fh;
}

# Writes a Chart.js javascript chart
sub drawChart {
    
    # Set various formatting variables
    my $x_scale = 'linear';
    my $x_min = 0;

    # Axis labels
    my $xaxis_label = "Uses data from x countries";
    my $yaxis_label = "Provides data to y countries";
    
    # Define the colors that will be used for the data 
    my @bordercolors = chart_colors(0.9);
    my @bgcolors = chart_colors(0.6);
    
    # Create the data arrays
    my $data_string = '';
    my $k = 0; # color selector
    my $color_max = @bordercolors;
    
    foreach my $group (@groups_to_plot) {
    	foreach my $country ( keys %{$country_grps{$group}} ) {
    		if ( $data{$country}->{use} ) {
    			my $date_string;
    			foreach my $date (@dates) {
    				$date_string .= "\"$country ($date)\",";
    			}
    			chop $date_string;
			
				# start a new data series
				$data_string .= "
				{  label: '$group',
				   labels: [$date_string],
				   showLine: 'true',
				   yAxisID: 'y',
				   borderColor: '$bordercolors[$k]',
				   backgroundColor: '$bgcolors[$k]',
				   data: [";
				
				my $max = @{$data{$country}->{use}} - 1;
				my ($x, $y);
				for ( 0 .. $max ) {
					$x = $data{$country}->{use}->[$_];
					$y = $data{$country}->{provide}->[$_];
					$data_string .= "," if $_;
					$data_string .= "{x: $x, y: $y}";
				}
				$data_string .= "]}, "; #closes data
			}
		}
		# increment color
		++$k;
		$k = 0 if $k == $color_max;
    }
    
    ## print the Chart.js script ##
    print <<EOF;
<div class="header">
	<h2>Relationship between DSI provision and use across time</h2>
	<p>Recreation of chart 6.1, using the 15 August 2022 dataset version. 
	The lines represent the progression of the DSI provision and use values for each country from $start_year to $end_year.</p>
</div>
<div class="row">
	<div class="column-main" style="width: 3%; float:left"></div>
	<div class="column-main" style="width: 82%; max-width: 725px">
		<div class="results">
			<canvas style="max-width: 700px; max-height: 700px;" id="myChart" aria-label="A chart showing the DSI provision and use histories of countries" role="img"></canvas>
		</div>
	</div>
	<div class="column-side" style="width: 15%">
		<div class="chart-actions" style="padding: 80 0 0 0; font-size: 18px;">
		  <div class="button_slide slide_down slide_normal" onclick="updateChart()"><span style='font-size:19px;'>&#8634;</span> Replay</div></br>
		  <div class="button_slide slide_right slide_fast" onclick="updateChartChangeSpeed(10)">Fast</div></br>
		  <div class="button_slide slide_right slide_normal" onclick="updateChartChangeSpeed(100)">Normal</div></br>
		  <div class="button_slide slide_right slide_slow" onclick="updateChartChangeSpeed(500)">Slow</div>
		</div>
	</div>
</div>

<script>
	Chart.defaults.color = "rgb(250,250,250)";

	var delayBetweenPoints = 100;

	const config = {
	  type: 'scatter',
	  data: {
		  datasets: [$data_string]
	  },
	
	  options: {
		locale: 'en-US',
		aspectRatio: 1,
		layout: { padding: 10 },
		animation: {
		  x: {
			type: 'number',
			easing: 'linear',
			duration: delayBetweenPoints,
			from: NaN, // the point is initially skipped
			delay(ctx) {
			  return ctx.index * delayBetweenPoints;
			}
		  },
		  y: {
			type: 'number',
			easing: 'linear',
			duration: delayBetweenPoints,
			from: NaN, // the point is initially skipped
			delay(ctx) {
			  return ctx.index * delayBetweenPoints;
			}
		  }
		},
		plugins: {
			tooltip: {
				mode: 'nearest', 
				callbacks: {
					label: function(ctx) {
						return [
                			ctx.dataset.label + ': ' + ctx.dataset.labels[ctx.dataIndex],
                			'Uses data from: ' + ctx.parsed.x, 
                			'Provides data to: ' + ctx.parsed.y
                		]
					}
				}
			}, 
			legend: {
				onClick: (evt, legendItem, legend) => {
					let newVal = !legendItem.hidden;
					legend.chart.data.datasets.forEach(dataset => {
						if (dataset.label === legendItem.text) {
							dataset.hidden = newVal
						}
					});
					legend.chart.update('none');
				},
				labels: {
					font: {
						size: 17
					},
					filter: (legendItem, chartData) => {
						let entries = chartData.datasets.map(e => e.label);
						return entries.indexOf(legendItem.text) === legendItem.datasetIndex;
					}
				}
			},
		},
		elements: { point: { hitRadius: 10, radius: 0 } },
		scales: {
		  x: {
			 type: '$x_scale',
			 position: 'bottom',
			 min: 0,
			 max: 200,
			 title: {
				text: '$xaxis_label',
				display: 'true',
				font: { size: 17 }
			 },
			 grid: { 
				color: 'rgb(50,50,50)'
			 }
		  },
		  y: {
			 type: 'linear',
			 position: 'left',
			 suggestedMin: 0, 
			 max: 200,
			 title: {
				text: '$yaxis_label',
				display: 'true',
				font: { size: 17 }
			 },
			 grid: { 
				color: 'rgb(50,50,50)'
			 }
		  }
	    }
	  }
	};
	
	let myChart = new Chart(
		document.getElementById('myChart'),
		config
	);
	
	function updateChart() {
		myChart.destroy();
		myChart = new Chart(
			document.getElementById('myChart'),
			config
		);
	}
	
	function updateChartChangeSpeed(duration) {
		myChart.destroy();
		delayBetweenPoints = duration;
		myChart = new Chart(
			document.getElementById('myChart'),
			config
		);
	}
	
</script>
EOF
}

# Writes a Chart.js javascript chart
sub drawChartResiduals {
    
    # Set various formatting variables
    my $x_min = $start_year;
    my $x_max = $end_year + 1;

    # Axis labels
    my $xaxis_label = "Year";
    my $yaxis_label = "Residual from equal provision and use";
    
    # Define the colors that will be used for the data 
    my @bordercolors = chart_colors(0.9);
    my @bgcolors = chart_colors(0.6);
    
    # Create the data arrays
    my $data_string = '';
    my $k = 0; # color selector
    my $color_max = @bordercolors;
    
    foreach my $group (@groups_to_plot) {
    	foreach my $country ( keys %{$country_grps{$group}} ) {
    		if ( $data{$country}->{use} ) {
			
    			my $date_string;
    			foreach my $date (@dates) {
    				my $date_label = $date->monname . " " . $date->year;
    				$date_string .= "\"$country ($date_label)\",";
    			}
    			chop $date_string;
			
				# start a new data series
				$data_string .= "
				{  label: '$group',
				   labels: [$date_string],
				   showLine: 'true',
				   yAxisID: 'y',
				   borderColor: '$bordercolors[$k]',
				   backgroundColor: '$bgcolors[$k]',
				   data: [";
				
				my $max = @{$data{$country}->{use}} - 1;
				my ($x, $y);
				for ( 0 .. $max ) {
					if ($dates[$_]->mon == 1 ) {
						$x = $dates[$_]->year;
					} else {
						$x = $dates[$_]->year . ".5";
					}
					$y = $data{$country}->{provide}->[$_] - (($data{$country}->{provide}->[$_] + $data{$country}->{use}->[$_] ) / 2 );

					$data_string .= "," if $_;
					$data_string .= "{x: $x, y: $y}";
				}
				$data_string .= "]}, "; #closes data
			}
		}
		# increment color
		++$k;
		$k = 0 if $k == $color_max;
    }
    
    ## print the Chart.js script ##
    print <<EOF;
<div class="header">
	<h2>Relationship between DSI provision and use across time</h2>
	<p>Recreation of chart 6.1, using the 15 August 2022 dataset version. 
	The line here charts how much a country's balance of DSI provision and use varies
	over time from an ideal of total equity, where a country always provides and uses from the 
	same number of countries. The chart covers DSI provision use from $start_year to $end_year. 
	A positive value indicates a country is providing more than it is using, while a negative value
	indicates a country is using more than providing.</p>
</div>
<div class="row">
	<div class="column-main" style="width: 3%; float:left"></div>
	<div class="column-main" style="width: 82%; max-width: 725px">
		<div class="results">
			<canvas style="max-width: 900px; max-height: 600px;" id="myChart" aria-label="A chart showing the DSI variance from perfect equity for countries" role="img"></canvas>
		</div>
	</div>
	<div class="column-side" style="width: 15%">
		<div class="chart-actions" style="padding: 80 0 0 0; font-size: 18px;">
		  <div class="button_slide slide_down slide_normal" onclick="updateChart()"><span style='font-size:19px;'>&#8634;</span> Replay</div></br>
		  <div class="button_slide slide_right slide_fast" onclick="updateChartChangeSpeed(10)">Fast</div></br>
		  <div class="button_slide slide_right slide_normal" onclick="updateChartChangeSpeed(100)">Normal</div></br>
		  <div class="button_slide slide_right slide_slow" onclick="updateChartChangeSpeed(500)">Slow</div>
		</div>
	</div>
</div>
    
<script>
	Chart.defaults.color = "rgb(250,250,250)";

	var delayBetweenPoints = 100;

	const config = {
	  type: 'scatter',
	  data: {
		  datasets: [$data_string]
	  },
	
	  options: {
		locale: 'en-US',
		aspectRatio: 1,
		layout: { padding: 10 },
		animation: {
		  x: {
			type: 'number',
			easing: 'linear',
			duration: delayBetweenPoints,
			from: NaN, // the point is initially skipped
			delay(ctx) {
			  return ctx.index * delayBetweenPoints;
			}
		  },
		  y: {
			type: 'number',
			easing: 'linear',
			duration: delayBetweenPoints,
			from: NaN, // the point is initially skipped
			delay(ctx) {
			  return ctx.index * delayBetweenPoints;
			}
		  }
		},
		plugins: {
			tooltip: {
				mode: 'nearest', 
				callbacks: {
					label: function(ctx) {
						return [
                			ctx.dataset.label + ": " + ctx.dataset.labels[ctx.dataIndex],
                			'Year: ' + ctx.parsed.x, 
                			'Residual: ' + ctx.parsed.y
                		]
					}
				}
			}, 
			legend: {
				onClick: (evt, legendItem, legend) => {
					let newVal = !legendItem.hidden;
					legend.chart.data.datasets.forEach(dataset => {
						if (dataset.label === legendItem.text) {
							dataset.hidden = newVal
						}
					});
					legend.chart.update('none');
				},
				labels: {
					font: {
						size: 17
					},
					filter: (legendItem, chartData) => {
						let entries = chartData.datasets.map(e => e.label);
						return entries.indexOf(legendItem.text) === legendItem.datasetIndex;
					}
				}
			}
		},
		elements: { point: { hitRadius: 10, radius: 0 } },
		scales: {
		  x: {
		  	 type: 'linear',
		  	 ticks: {
		  	     callback: (label) => `\${label}`,
      		 },
			 position: 'bottom',
			 min: $x_min,
			 max: $x_max,
			 title: {
				text: '$xaxis_label',
				display: 'true',
				font: { size: 17 }
			 },
			 grid: { 
				color: 'rgb(50,50,50)'
			 }
		  },
		  y: {
			 type: 'linear',
			 position: 'left',
			 title: {
				text: '$yaxis_label',
				display: 'true',
				font: { size: 17 }
			 },
			 grid: { 
				color: 'rgb(50,50,50)'
			 }
		  }
	    }
	  }
	};
	
	let myChart = new Chart(
		document.getElementById('myChart'),
		config
	);
	
	function updateChart() {
		myChart.destroy();
		myChart = new Chart(
			document.getElementById('myChart'),
			config
		);
	}
	
	function updateChartChangeSpeed(duration) {
		myChart.destroy();
		delayBetweenPoints = duration;
		myChart = new Chart(
			document.getElementById('myChart'),
			config
		);
	}
	
</script>
EOF
}

# Writes a Chart.js javascript chart
sub drawChartResidualsGroups {
    
    # Set various formatting variables
    my $x_min = $start_year;
    my $x_max = $end_year + 1;
    
    my $y_min = -80;
    my $y_max = 40;

    # Axis labels
    my $xaxis_label = "Year";
    my $yaxis_label = "Residual from equal provision and use";
    
    # Define the colors that will be used for the data 
    my @bordercolors = chart_colors(0.9);
    my @bgcolors = chart_colors(0.6);
    
    # Create the data arrays
    my $data_string = '';
    my $k = 0; # color selector
    my $color_max = @bordercolors;
    
    foreach my $group (@groups_to_plot) {
    	
    	my $date_string;
		foreach my $date (@dates) {
			my $date_label = $date->monname . " " . $date->year;
			$date_string .= "\"$date_label\",";
		}
		chop $date_string;

		$data_string .= "
		{  label: '$group',
		   labels: [$date_string],
		   showLine: 'true',
		   yAxisID: 'y',
		   borderColor: '$bordercolors[$k]',
		   backgroundColor: '$bgcolors[$k]',
		   data: [";

    	# foreach date ...create index to calls the country arrays
    	my $i = 0;
    	foreach my $date ( @dates ) {
    		my $total_residual = 0;
    		my $total_values = 0;
    		
    		foreach my $country ( keys %{$country_grps{$group}} ) {
				if ( $data{$country}->{use} ) {
					$total_residual += $data{$country}->{provide}->[$i] - (($data{$country}->{provide}->[$i] + $data{$country}->{use}->[$i] ) / 2 );
					++$total_values;
				}
			}

    		my $x;
    		my $y = $total_residual / $total_values;
			if ($date->mon == 1 ) {
				$x = $date->year;
			} else {
				$x = $date->year . ".5";
			}

			$data_string .= "," if $i;
			$data_string .= "{x: $x, y: $y}";
			++$i;
    	}
    	$data_string .= "]}, "; #closes data
    	# increment color
		++$k;
		$k = 0 if $k == $color_max;
	}
	
    ## print the Chart.js script ##
    print <<EOF;
<div class="header">
	<h2>Relationship between DSI provision and use across time</h2>
	<p>Recreation of chart 6.1, using the 15 August 2022 dataset version. 
	The line here charts how much a country's balance of DSI provision and use varies
	over time from an ideal of total equity, where a country always provides and uses from the 
	same number of countries. The chart covers DSI provision use from $start_year to $end_year. 
	A positive value indicates a country is providing more than it is using, while a negative value
	indicates a country is using more than providing.</p>
</div>
<div class="row">
	<div class="column-main" style="width: 3%; float:left"></div>
	<div class="column-main" style="width: 82%; max-width: 725px">
		<div class="results">
			<canvas style="max-width: 900px; max-height: 600px;" id="myChart" aria-label="A chart showing the DSI variance from perfect equity for countries" role="img"></canvas>
		</div>
	</div>
	<div class="column-side" style="width: 15%">
		<div class="chart-actions" style="padding: 80 0 0 0; font-size: 18px;">
		  <div class="button_slide slide_down slide_normal" onclick="updateChart()"><span style='font-size:19px;'>&#8634;</span> Replay</div></br>
		  <div class="button_slide slide_right slide_fast" onclick="updateChartChangeSpeed(10)">Fast</div></br>
		  <div class="button_slide slide_right slide_normal" onclick="updateChartChangeSpeed(100)">Normal</div></br>
		  <div class="button_slide slide_right slide_slow" onclick="updateChartChangeSpeed(500)">Slow</div>
		</div>
	</div>
</div>
    
<script>
	Chart.defaults.color = "rgb(250,250,250)";

	var delayBetweenPoints = 100;

	const config = {
	  type: 'scatter',
	  data: {
		  datasets: [$data_string]
	  },
	
	  options: {
		locale: 'en-US',
		aspectRatio: 1,
		layout: { padding: 10 },
		animation: {
		  x: {
			type: 'number',
			easing: 'linear',
			duration: delayBetweenPoints,
			from: NaN, // the point is initially skipped
			delay(ctx) {
			  return ctx.index * delayBetweenPoints;
			}
		  },
		  y: {
			type: 'number',
			easing: 'linear',
			duration: delayBetweenPoints,
			from: NaN, // the point is initially skipped
			delay(ctx) {
			  return ctx.index * delayBetweenPoints;
			}
		  }
		},
		plugins: {
			tooltip: {
				mode: 'nearest', 
				callbacks: {
					label: function(ctx) {
						return [
                			ctx.dataset.label + ": " + ctx.dataset.labels[ctx.dataIndex],
                			'Year: ' + ctx.parsed.x, 
                			'Mean Residual: ' + ctx.parsed.y
                		]
					}
				}
			}, 
			legend: {
				onClick: (evt, legendItem, legend) => {
					let newVal = !legendItem.hidden;
					legend.chart.data.datasets.forEach(dataset => {
						if (dataset.label === legendItem.text) {
							dataset.hidden = newVal
						}
					});
					legend.chart.update('none');
				},
				labels: {
					font: {
						size: 17
					},
					filter: (legendItem, chartData) => {
						let entries = chartData.datasets.map(e => e.label);
						return entries.indexOf(legendItem.text) === legendItem.datasetIndex;
					}
				}
			}
		},
		elements: { point: { hitRadius: 10, radius: 0 } },
		scales: {
		  x: {
		  	 type: 'linear',
		  	 ticks: {
		  	     callback: (label) => `\${label}`,
      		 },
			 position: 'bottom',
			 min: $x_min,
			 max: $x_max,
			 title: {
				text: '$xaxis_label',
				display: 'true',
				font: { size: 17 }
			 },
			 grid: { 
				color: 'rgb(50,50,50)'
			 }
		  },
		  y: {
			 type: 'linear',
			 position: 'left',
			 min: $y_min,
			 max: $y_max,
			 title: {
				text: '$yaxis_label',
				display: 'true',
				font: { size: 17 }
			 },
			 grid: { 
				color: 'rgb(50,50,50)'
			 }
		  }
	    }
	  }
	};
	
	let myChart = new Chart(
		document.getElementById('myChart'),
		config
	);
	
	function updateChart() {
		myChart.destroy();
		myChart = new Chart(
			document.getElementById('myChart'),
			config
		);
	}
	
	function updateChartChangeSpeed(duration) {
		myChart.destroy();
		delayBetweenPoints = duration;
		myChart = new Chart(
			document.getElementById('myChart'),
			config
		);
	}
	
</script>
EOF
}

sub chart_colors {
    my $transparency = shift; 
    return (
    	"rgba(252,174,30,$transparency)",
        "rgba(153,255,51,$transparency)",
        "rgba(0,51,204,$transparency)",
        "rgba(190,0,220,$transparency)",
        "rgba(0,204,255,$transparency)",
        "rgba(255,255,0,$transparency)",
        );
}

sub start_html {
    print <<EOF;

<html>
<head>
<title>DSI provision vs use</title>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/3.1.1/chart.min.js"></script>
<link rel="stylesheet" href="https://alhufton.com/css/tool.css">
<style>
.button_slide {
  color: #FFF;
  border: 2px solid rgb(250, 250, 250);
  border-radius: 0px;
  padding: 5px 15px;
  margin: 5px;
  display: inline-block;
  width: 90%;
  font-size: 16px;
  cursor: pointer;
}

.button_slide:active {
  color: #99ffe6;
  border-color: #99ffe6;
  transition-duration: 0.1s;
}

.slide_fast {
  box-shadow: inset 0 0 0 0 #708090;
  -webkit-transition: ease-out 0.4s;
  -moz-transition: ease-out 0.4s;
  transition: ease-out 0.4s;
}

.slide_normal {
  box-shadow: inset 0 0 0 0 #708090;
  -webkit-transition: ease-out 1s;
  -moz-transition: ease-out 1s;
  transition: ease-out 1s;
}

.slide_slow {
  box-shadow: inset 0 0 0 0 #708090;
  -webkit-transition: ease-out 2s;
  -moz-transition: ease-out 2s;
  transition: ease-out 2s;
}

.slide_down:hover {
  box-shadow: inset 0 100px 0 0 #708090;
}

.slide_right:hover {
  box-shadow: inset 400px 0 0 0 #708090;
}

</style>
</head>
<body>
    
EOF

}

sub print_tail {
    print <<EOF;  
</body>
</html>

EOF

}

