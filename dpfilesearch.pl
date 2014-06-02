#!/usr/bin/perl -w
BEGIN { our($_pathname,$_filename)=($0=~m#(.*)/([^/]+)$#)?($1,$2):(".",$0); push @INC,$_pathname; };
sub usage {
################################################################
#
# Title       : dpfilesearch.pl
#
# Autor		  : Christian Sandrini
#
# Description :
print STDERR "\nERROR: $_[0]\nUsage:\n", <<"EndOfDescription";

     $_filename

	 Required Parameters:
		--filesystem 'host:dir'		Filesystem with format host:fs
						ex. server:/SHARED	
		--label 'label'			Label
		--dir 'directory'		Directory to search

	 Optional Parameters:
		--recursive			Recursive search
		--maxCount			Maximum allowed item count. Default: 10000
EndOfDescription
exit 2
}

# -------------------------
# Required libraries
# -------------------------
use strict;
use Data::Dumper;
use Getopt::Long;
use Carp;
use IPC::Open3;
use Term::ANSIColor;

# -------------------------
# Global Variables
# -------------------------
my $omnidb = '/opt/omni/bin/omnidb';
my %data = ();
my $maxNumberOfItems = 10000;
my $itemCount = 0;

# -------------------------
# Argument handling
# -------------------------
my( $filesystem, $label, $directory, $recursive );
Getopt::Long::Configure("pass_through");
GetOptions(
                q{filesystem=s} => \$filesystem,
                q{label=s} => \$label,
                q{dir=s} => \$directory,
                q{recursive!} => \$recursive,
				q{maxCount=i} => \$maxNumberOfItems
);

usage "Invalid argument(s)." if (grep {/^-/o } @ARGV);

my( @args ) = @ARGV;
if ( !($filesystem || $label || $directory) ) {
	usage "Not enough arguments." if (! @args );
}

# -------------------------
# Methods
# -------------------------
sub pullDataFromDbWithDirectory {
	my $_dir = $_[0];
	my @list = ();

	my @retval = grep { /dir|file/ } map { s/^Dir\s+|^File\s+|\n//g; $_ } qx($omnidb -filesystem $filesystem  '$label'  -listdir '$_dir');

	foreach my $item (@retval) {
		$itemCount++;

		if ($itemCount le $maxNumberOfItems) {

			push(@list,$item) if $item =~ /^file/;

			if ($item =~ /^dir/) {
				my $subdir = "$_dir/$item";
				$data{$subdir} = ();

				if ($recursive) {
					pullDataFromDbWithDirectory($subdir);
				}
			}
		}
	}

	$data{$_dir} = \@list;
}

sub printData {
	foreach my $key (sort keys %data) {
		print "$key\n";
		foreach my $item (@{$data{$key}}) {
			print "$key/$item\n";
		}
	}
	print colored ['red on_black'], "\nWARNING: Maximum item count of $maxNumberOfItems has been reached. Please adjust your filter\n";	
}



# -------------------------
# Main
# -------------------------
pullDataFromDbWithDirectory($directory);
printData;
