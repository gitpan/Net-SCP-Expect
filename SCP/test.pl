# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use Test;
BEGIN { plan tests => 1 };
use Net::SCP::Expect;

#########################

ok(1); # Lame, lame, LAME!  Look for a real test suite in a later release
