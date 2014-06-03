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
use threads;
use Thread::Queue;

# -------------------------
# Global Variables
# -------------------------
my $omnidb = '/opt/omni/bin/omnidb';
my @data :shared;
my $maxNumberOfParallelJobs = 10;
my $maxNumberOfItems = 10000;
my $itemCount = 0;
my $debug = 0;
my $worker = Thread::Queue->new();

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

	if ($itemCount <= $maxNumberOfItems) {
		my @retval = grep { /dir|file/ } map { s/^Dir\s+|^File\s+|\n//g; $_ } qx($omnidb -filesystem $filesystem  '$label'  -listdir '$_dir');

		foreach my $item (@retval) {
			$itemCount++;
			my $file = "$_dir/$item";
			push(@data,$file);

			if ($item =~ /^dir/) {
				$worker->enqueue($file);
				print "Add $file to queue\n" if $debug;
			}
		}
	}
}

sub doOperation () {
	my $ithread = threads->tid();
	while (my $folder = $worker->dequeue()) {
		print "Read $folder from queue\n" if $debug;
		pullDataFromDbWithDirectory($folder);
	}
}

sub printData {
	foreach my $file (sort @data) {
		print "$file\n";
	}

	if ($itemCount > $maxNumberOfItems) {
		print colored ['red on_black'], "\nWARNING: Maximum item count of $itemCount / $maxNumberOfItems has been reached. Please adjust your filter\n"; 
	}
}

# -------------------------
# Main
# -------------------------
my @threads = map threads->create(\&doOperation), 1 .. $maxNumberOfParallelJobs;
pullDataFromDbWithDirectory($directory);
$worker->enqueue((undef) x $maxNumberOfParallelJobs);
$_->join for @threads;

printData();
