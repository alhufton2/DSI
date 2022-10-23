#!/usr/bin/perl
use strict;
use warnings;
binmode(STDOUT, ":utf8");

### Load modules ###
use Text::CSV;
use Carp qw< croak >;
use Time::Piece;

# For debugging
my $monitor = 'Benin'; # set to 0 to suppress STDERR messages

### Configure temporal range ###
my $start_date = Time::Piece->strptime('1985-01-01', '%Y-%m-%d');
my $end_date = Time::Piece->strptime('2022-07-01', '%Y-%m-%d');

### Get input files from user ###
my $usage = "$0 ena_sequences pmc_references country_file";
unless ( $ARGV[0] && $ARGV[1] && $ARGV[2] ) { die "\n$usage\n\n" }

### Data hash ###
my %country_provides_to; # provider_country->user_country = date_obj (records earliest use)

### Main ###

## Read the country file
# This hash converts countries to the WiLDSI simplified list (independent, UN-recognized countries only)
my %country_translator = &readCountry($ARGV[2]);

## Read the ENA file
# %sequences is a hash of hashes that stores the country(s) of origin for all sequences (ID->country->1)
# The other hashes store information on primary references, which are needed later to parse the PMC file
my ($sequences_ref, $primary_pmid_ref, $primary_pmcid_ref, $primary_doi_ref) = &readENA($ARGV[0]);
my %sequences = %$sequences_ref; 
my %primary_pmid = %$primary_pmid_ref;
my %primary_pmcid = %$primary_pmcid_ref;
my %primary_doi = %$primary_doi_ref;

## Read the PMC file
&readPMC($ARGV[1]); # uses the hashes above and fills %country_provides_to

## Output the data table
my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1 });
my $fh = *STDOUT;
my @countries = keys %country_provides_to;
my $current_date = $start_date;

# print the header row
my $hrow;
$hrow->[0] = 'Date';
foreach (@countries) {
	push @$hrow, "$_ [uses from]", "$_ [provides to]";
}
$csv->say($fh, $hrow); 

# print the data rows
while ( $current_date <= $end_date ) {
	my $drow;
	$drow->[0] = $current_date->datetime;
	
	foreach (@countries) {
		my $uses_from_num = 0;
		my $provides_to_num = 0;
		foreach my $country ( @countries ) {
			if ( $country_provides_to{$country}->{$_} 
				&& $country_provides_to{$country}->{$_} <= $current_date ) {
				++$uses_from_num;
			}
			if ( $country_provides_to{$_}->{$country} 
				&& $country_provides_to{$_}->{$country} <= $current_date ) {
				++$provides_to_num;
			}
		}
		push @$drow, $uses_from_num, $provides_to_num;
		#print STDERR "On " . $current_date->datetime . " $_ provided DSI to $provides_to_num countries and used DSI from $uses_from_num countries\n";
	}
	$current_date = $current_date->add_months(1);
	$csv->say($fh, $drow); 
}
	

exit;

sub readCountry {
	my $filepath = shift;
	my %country_translator_local;
	
	my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1, skip_empty_rows => 1 });
	open my $fh, "<:encoding(utf8)", $filepath or die "$filepath: $!";
	
	$csv->column_names( $csv->getline($fh) );
	while ( my $row = $csv->getline_hr($fh) ) {
		if ( $row->{NAME} && $row->{SIMPLIFIED_NAME} ) {
			my $temp_country = lc $row->{NAME};
			$temp_country =~ s/^the\s//;
			$country_translator_local{$temp_country} = $row->{SIMPLIFIED_NAME};
			print STDERR "mapping $temp_country to $row->{SIMPLIFIED_NAME}\n" if ( $row->{SIMPLIFIED_NAME} eq $monitor );
		}
	}
	close $fh;
	return %country_translator_local;
}

sub readENA {
	my $filepath = shift;
	my %sequences_local;
	my %pmid_local;
	my %pmcid_local;
	my %doi_local;
	
	my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1, skip_empty_rows => 1 });
	open my $fh, "<:encoding(utf8)", $filepath or die "$filepath: $!";
	
	$csv->column_names( $csv->getline($fh) );
	while ( my $row = $csv->getline_hr($fh) ) {
		if ( $row->{ACCESSION} && $row->{COUNTRY} && $row->{SUBMISSION_DATE} ) {
			# Convert countries
			foreach ( split(/;/, $row->{COUNTRY}) ) {			
				my $country;
				my $temp_country = lc $_;
				$temp_country =~ s/^the\s//;
				
				if ( $country_translator{$temp_country} ) {
					$country = $country_translator{$temp_country};
				} else {
					# print STDERR "no country found for $_\n";
					next;
				}
				
				$sequences_local{$row->{ACCESSION}}->{$country} = 1;
				print STDERR "recording $row->{ACCESSION} from $country\n" if ( $country eq $monitor );
			}
			
			# Record information on primary references
			# This is stupidly inefficient for any sequences that have multiple primary lit IDs
			if ($row->{PRIMARY_PMID}) {
				foreach my $pmid ( split(/;/, $row->{PRIMARY_PMID}) ) {	
					$pmid_local{$pmid}->{$row->{ACCESSION}} = 1;
					#print STDERR "recording " . $pmid . " for " . $row->{ACCESSION} . "\n";
				}
			}
			if ($row->{PRIMARY_PMCID}) {
				foreach my $pmcid ( split(/;/, $row->{PRIMARY_PMCID}) ) {	
					$pmcid_local{$pmcid}->{$row->{ACCESSION}} = 1;
				}
			}
			if ($row->{PRIMARY_DOI}) {
				foreach my $doi ( split(/;/, $row->{PRIMARY_DOI}) ) {
					$doi_local{$doi}->{$row->{ACCESSION}} = 1;
					#print STDERR "recording " . $doi . " for " . $row->{ACCESSION} . "\n";
				}
			}
		}
	}
	close $fh;
	return (\%sequences_local, \%pmid_local, \%pmcid_local,  \%doi_local);
}

sub readPMC {
	my $filepath = shift;
	
	my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1, skip_empty_rows => 1 });
	open my $fh, "<:encoding(utf8)", $filepath or die "$filepath: $!";
	
	my %primary_check; # helps reduce redundant primary ref searches
	
	$csv->column_names( $csv->getline($fh) );
	while ( my $row = $csv->getline_hr($fh) ) {
		if ( $row->{COUNTRY} ) {
			unless ( $row->{IDPMC} ) { die "Something has gone wrong"; }
			
			# Create a hash listing of all accession numbers associated with this reference line
			my %accessions;
			# This is always unique and therefore doesn't need a foreach
			if ( $row->{ACCESSION} ) {
				$accessions{$row->{ACCESSION}} = 1;
			}
				
			unless ( $primary_check{$row->{IDPMC}}->{$row->{COUNTRY}} ) {
				# Now merge in any accessions associated with this publication as a primary reference
				if ( $row->{SECONDARY_PMID} && $primary_pmid{$row->{SECONDARY_PMID}} ) {
					foreach my $acc ( keys %{$primary_pmid{$row->{SECONDARY_PMID}}} ) { $accessions{$acc} = 1; }
				}
				if ( $row->{SECONDARY_PMCID} && $primary_pmcid{$row->{SECONDARY_PMCID}} ) {
					foreach my $acc ( keys %{$primary_pmcid{$row->{SECONDARY_PMCID}}} ) { $accessions{$acc} = 1; }
				}
				if ( $row->{SECONDARY_DOI} && $primary_doi{$row->{SECONDARY_DOI}} ) {
					foreach my $acc ( keys %{$primary_doi{$row->{SECONDARY_DOI}}} ) { $accessions{$acc} = 1; }
				}
				$primary_check{$row->{IDPMC}}->{$row->{COUNTRY}} = 1;
			}	
			
			# Create a date object which we will treat as the date of use
			my $date_obj = Time::Piece->strptime($row->{FIRST_PUB_DATE}, '%d-%b-%y');
			
			# Compile a list of the provider countries
			my %provider_countries;
			foreach my $acc ( keys %accessions ) {
				if ( $sequences{$acc} ) {
					foreach my $provider_country ( keys %{$sequences{$acc}} ) {
						$provider_countries{$provider_country} = 1;
					}
				}
			}
			
			foreach ( split(/;/, $row->{COUNTRY}) ) {
				
				# Convert country name
				my $user_country;
				my $temp_country = lc $_;
				$temp_country =~ s/^the\s//;
				
				if ( $country_translator{$temp_country} ) {
					$user_country = $country_translator{$temp_country};
				} else {
					# print STDERR "no country found for $_\n";
					next;
				}
				
				foreach my $provider_country ( keys %provider_countries ) {	
					# Record the earliest date at which the user country used DSI from the provider country
					# Checks first to see if the pair is already defined, and then checks if it already has an earlier use date
					# If either check fails, record this use-instance as the earliest for the pair
					print STDERR "$provider_country identified as provider to $user_country on PMC reference " . $row->{IDPMC} . "\n" if ( $provider_country eq $monitor || $user_country eq $monitor );

					unless ( $country_provides_to{$provider_country}->{$user_country} ) {
						$country_provides_to{$provider_country}->{$user_country} = $date_obj;
					} elsif ( $country_provides_to{$provider_country}->{$user_country} > $date_obj ) {
						$country_provides_to{$provider_country}->{$user_country} = $date_obj;
					}
				}
			}	
		}
	}
	close $fh;
}
