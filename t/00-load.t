#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Net::Imgix' ) || print "Bail out!\n";
}

diag( "Testing Net::Imgix $Net::Imgix::VERSION, Perl $], $^X" );
