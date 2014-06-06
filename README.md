Usage:
======

NAME
-----
    dpfilesearch.pl - Queries files and directories in Data Protector db

SYNOPSIS
--------
    dpfilesearch.pl --object <Object> --label <Label> --dir <Directory>
                [--recursive] [--maxCount <count>] [--threads <Threads>]
                [--exclude <Directory>] [--filter <regexp>]

DESCRIPTION
------------

     Required Parameters:
     --------------------
        --object
            Filesystem with format host:fs
            ex. server:/SHARED

        --label
            Label of the object

        --dir
            Directory to search

     Optional Parameters:
     --------------------
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
---------

    dpfilesearch.pl --object server:/pkgs/fs --label '/pkgs/fs' --dir '/pkgs/fs/dp/schema' --recursive --filter '.*_01_20.*.dmp'

AUTHORS
--------

    Christian Sandrini
