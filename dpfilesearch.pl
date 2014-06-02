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
EndOfDescription
exit 2
}

# -------------------------
# Required libraries
# -------------------------
use strict;
use Data::Dumper;
use Getopt::Long;

# -------------------------
# Main
# -------------------------

my( $filesystem, $label, $directory, $recursive );
Getopt::Long::Configure("pass_through");
GetOptions(
                q{filesystem=s} => \$filesystem,
                q{label=s} => \$label,
                q{dir} => \$directory,
                q{recursive!} => \$recursive,
);

usage "Invalid argument(s)." if (grep {/^-/o } @ARGV);

my( @args ) = @ARGV;
if ( !($filesystem || $label || $directory) ) {
	usage "Not enough arguments." if (! @args );
}


