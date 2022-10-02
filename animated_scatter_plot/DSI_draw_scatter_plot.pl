#!/usr/bin/perl
use strict;
use warnings;
binmode(STDOUT, ":utf8");

### Load modules ###
use Text::CSV;
use Carp qw< croak >;
use Time::Piece;

### Get input files from user ###
my $usage = "$0 country_group_file data_table";
unless ( $ARGV[0] && $ARGV[1] ) { die "\n$usage\n\n" }

my @groups_to_plot = ('BRICS','G77', 'OECD');

# Read the country group file
my %country_grps = &readCountryGrps($ARGV[0]); # group->country simplified name->1

# Read the data table
my %data;
my @dates;
&readProcessedData($ARGV[1]); # country->(use or provide)->array of values

# Output a chart
&start_html();
print <<EOF; 
<h2>Relationship between DSI provision and use across time</h2>
<p>Recreation of chart 6.1, using the 15 August 2022 dataset version. 
The lines represent the progression of the DSI provision and use values for each country from 1986 to 2022.</p>
<p><span style="background-color: rgba(252,174,30,0.9); color: white; padding: 2px;">BRICS</span>
<span style="background-color: rgba(153,255,51,0.9); color: black; padding: 2px;">G77</span>
<span style="background-color: rgba(0,51,204,0.9); color: white; padding: 2px;">OECD</span></p>
<canvas style="max-width: 800px; max-height: 800px;" id="myChart" aria-label="A chart showing the DSI provision and use histories of countries" role="img"></canvas>
EOF

&drawChart();
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
			#print STDERR $row->{COUNTRY} . " is in group " . $row->{GRP} . ".\n";
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
		# foreach element in row
		next if ( $row->{Date} =~ /^1985/ ); # skip the first year, since there is nothing happening
		foreach my $key ( keys %{$row} ) {
			my $country;
			if ( $key eq 'Date' ) {
				push @dates, $row->{Date};
				# for now, do nothing with the dates
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
			
				# start a new data series
				$data_string .= "
				{  label: '$country ($group)',
				   showLine: 'true',
				   borderColor: '$bordercolors[$k]',
				   backgroundColor: '$bgcolors[$k]',
				   data: [";
				
				my $max = @{$data{$country}->{use}} - 1;
				my ($x, $y);
				for ( 0 .. $max ) {
					# next if ( $i && $x == $data{$country}->{use}->[$_] && $y == $data{$country}->{provide}->[$_] );
					next if ( $_ % 5 );
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
<script>
Chart.defaults.color = "rgb(0,0,0)";

const delayBetweenPoints = 500;
// const previousY = (ctx) => ctx.index === 0 ? ctx.chart.scales.y.getPixelForValue(0) : ctx.chart.getDatasetMeta(ctx.datasetIndex).data[ctx.index - 1].getProps(['y'], true).y;

var ctx = document.getElementById('myChart').getContext('2d');
var myChart = new Chart(ctx, {
  type: 'scatter',
  data: {
      datasets: [$data_string]},

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
			  if (ctx.type !== 'data' || ctx.xStarted) {
				return 0;
			  }
			  ctx.xStarted = true;
			  return ctx.index * delayBetweenPoints;
			}
		  },
		  y: {
			type: 'number',
			easing: 'linear',
			duration: delayBetweenPoints,
			from: NaN, // the point is initially skipped
			delay(ctx) {
			  if (ctx.type !== 'data' || ctx.yStarted) {
				return 0;
			  }
			  ctx.yStarted = true;
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
                			ctx.dataset.label,
                			'Uses data from: ' + ctx.parsed.x, 
                			'Provides data to: ' + ctx.parsed.y
                		]
                	}
                }
            }, 
            legend: {
                display: false,
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
                font: { size: 16 }
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
                font: { size: 16 }
             },
             grid: { 
                color: 'rgb(50,50,50)'
             }
          }
        }
    }
});
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
<link rel="stylesheet" href="../css/tool.css">
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
