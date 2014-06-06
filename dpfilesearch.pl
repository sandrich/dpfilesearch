#!/usr/bin/perl -w
BEGIN { our($_pathname,$_filename)=($0=~m#(.*)/([^/]+)$#)?($1,$2):(".",$0); push @INC,$_pathname; };
sub usage {
################################################################
#
# Title       : dpfilesearch.pl
#
# Author	  : Christian Sandrini
#
# Description :
print STDERR "\nERROR: $_[0]\nUsage:\n", <<"EndOfDescription";

NAME
	dpfilesearch.pl - Queries files and directories in Data Protector db

SYNOPSIS
	$_filename --object <Object> --label <Label> --dir <Directory> 
				[--recursive] [--maxCount <count>] [--threads <Threads>] 
				[--exclude <Directory>] [--filter <regexp>]

DESCRIPTION

	 Required Parameters:
		--object
			Filesystem with format host:fs
			ex. server:/SHARED	

		--label
			Label of the object

		--dir
			Directory to search

	 Optional Parameters:
		--recursive			
			Recursive search

		--maxCount
			Maximum allowed item count. Default: 10000

		--threads		
			Amount of threads being used for search. Maximum allowed are 10. 

		--exclude dir		
			Can be specified muliple times

		--filter
			Any valid POSIX regular expression can be specified

EXAMPLES

	dpfilesearch.pl --object server:/pkgs/fs --label '/pkgs/fs' --dir '/pkgs/fs/dp/schema' --recursive --filter '.*_01_20.*.dmp'

AUTHORS

	Christian Sandrini
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
my $worker = Thread::Queue->new();
my @IDLE_THREADS :shared;
my $filter = '.*';
my $idle :shared = $maxNumberOfParallelJobs;

# -------------------------
# Argument handling
# -------------------------
my( $filesystem, $label, $directory, $recursive, $debug, @exclude );
Getopt::Long::Configure("pass_through");
GetOptions(
                q{object=s} => \$filesystem,
                q{label=s} => \$label,
                q{dir=s} => \$directory,
                q{recursive!} => \$recursive,
				q{maxCount=i} => \$maxNumberOfItems,
				q{threads=i} => \$maxNumberOfParallelJobs,
				q{debug!} => \$debug,
				q{exclude=s} => \@exclude,
				q{filter=s} => \$filter
);

usage "Invalid argument(s)." if (grep {/^-/o } @ARGV);

my( @args ) = @ARGV;
if ( !($filesystem || $label || $directory) ) {
	usage "Not enough arguments." if (! @args );
}

if ($maxNumberOfParallelJobs gt 10) {
	$maxNumberOfParallelJobs = 10;
	printError("Maximum allowed threads are 10"); 
}

# Remove trailing slash
$directory =~ s/\/$//g;

# Make sure the object has colon 
if (index($filesystem,':') == -1) {
	usage "Object is not in a proper format.";
}

# -------------------------
# Methods
# -------------------------
sub printError {
	my $message = @_;

	print STDERR colored ['red on_black'], "\nWARNING: $message\n";
}

sub pullDataFromDbWithDirectory {
	my $_dir = $_[0];

	if ($itemCount <= $maxNumberOfItems) {
		my @commandOutput = qx($omnidb -filesystem $filesystem  '$label'  -listdir '$_dir' 2>&1);
		my ($rc) = ($?>>8);

		if ($rc eq 0) {

			my @retval = grep { /^Dir|^File/ } qx($omnidb -filesystem $filesystem  '$label'  -listdir '$_dir');

			foreach my $item (@retval) {
				$itemCount++;
				(my $filename = $item) =~ s/^File\s+|^Dir\s+|\n//g;
				my $file = "$_dir/$filename";
			
				if (!($file ~~ @exclude)) {
					push(@data,$file);

					if ($item =~ /^Dir/) {
						$worker->enqueue($file);
						print "Add $file to queue\n" if $debug;
					}
				}
			}
		} else {
			print STDERR join('',@commandOutput);
			threads->self->kill('KILL')->join;
			exit $rc;
		}
	}
}

sub doOperation () {
	my $ithread = threads->tid();

	while( my $folder = $worker->dequeue() ) {
		{ lock $idle; --$idle }
		print "Read $folder from queue with thread $ithread\n" if $debug;
        pullDataFromDbWithDirectory($folder);
		{ lock $idle; ++$idle }
	}

	push(@IDLE_THREADS,$ithread);
}

sub printData {
	foreach my $file (sort grep {$_ =~ /$filter/ } @data) {
		print "$file\n";
	}

	if ($itemCount > $maxNumberOfItems) {
		print STDERR colored ['red on_black'], "\nWARNING: Maximum item count of $itemCount / $maxNumberOfItems has been reached. Please adjust your filter\n"; 
	}
}

# -------------------------
# Main
# -------------------------
$SIG{'KILL'} = sub { threads->exit() };
print "Exclude: " . Dumper(\@exclude) if $debug;
my @threads = map threads->create(\&doOperation), 1 .. $maxNumberOfParallelJobs;
pullDataFromDbWithDirectory($directory);

print "IDLE: $idle";
sleep 1 until $idle < $maxNumberOfParallelJobs; ## Wait for (some) thr
sleep 1 until $idle  == $maxNumberOfParallelJobs; ## wait until they a
$worker->enqueue((undef) x $maxNumberOfParallelJobs);
$_->join for @threads;

printData();

print "Still pending in queue: " . $worker->pending();
