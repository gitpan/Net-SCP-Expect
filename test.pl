# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use Test;
use Term::ReadPassword;
BEGIN { plan tests => 2 };
use Net::SCP::Expect;

#########################

###############################################################################

print <<HERE;

   READ THIS!

   This test program will work, but isn't really set up the way it should be
   yet.  This is because of a major bug that needed fixing and I wanted to
   get the patched version out the door.

   KEEP READING IF YOU WANT TO CONTINUE

   In order to perform a real test of this module, you will need a valid login
   and password to a remote system.  You will also need to provide the name of
   at least one file that exists on the remote system and one that exists on
   your local system.  I will also test intentional failures.

   You will be prompted for a password.  Do not worry - it will not be echoed
   to the screen.

   Entering blank values will simply cause that question to reappear until
   you enter a valid value.  If you wish to exit in the middle of the test
   simply hit Ctrl-C.

   The file that is copied from the remote host to your local host will be
   deleted at the end of this test.  This test may optionally be skipped.

   The file that is copied from your local system to your remote system will
   have to be deleted manually.  Net::SCP::Expect cannot delete remote files,
   it only copies them.  This test may also optionally be skipped.

   If you skip both of these tests, did you ever test?

   If you have a problem with any of this, I suggest that you exit now.

HERE

my($ans,$rhost,$ruser,$rpasswd,$lfile,$rfile);

until($ans){
   print "Do you wish to continue (yes/no)? ";
   $ans = <STDIN>;
   chomp($ans);
}

if($ans =~ /[Nn]o?/){
   print "Terminating test for Net::SCP::Expect\n";
   exit;
}

until($rhost){
   print "Please enter the name of a remote host: ";
   $rhost = <STDIN>;
   chomp($rhost);
}

until($ruser){
   print "Please enter the user name: ";
   $ruser = <STDIN>;
   chomp($ruser);
}

until($rpasswd){
   $rpasswd = read_password("Please enter the password: ");
}

print "Please enter a remote file to copy to your local host (or just hit 'Enter' to skip): ";
$rfile = <STDIN>;
chomp($rfile);

print "Please enter a local file to copy to your remote host (or just hit 'Enter' to skip): ";
$lfile = <STDIN>;
chomp($lfile);

unless($rfile || $lfile){
   print <<NOFILES

      You appear to be skipping the real core of the testing since you did not
      provide either a remote file or a local file.  All that will be tested now
      are intentional failures.

NOFILES
}

my $scpe = Net::SCP::Expect->new(
   host     => $rhost,
   user     => $ruser,
   password => $rpasswd,
);

if($rfile){
   print "Test 1: Remote to local\n";
   $scpe->scp(":$rfile",".");
}

print "Remote to local appears to have completed\n";

if($lfile){
   print "Test 2: Local to remote\n";
   $scpe->scp("$lfile",":$lfile");
}

print "Local to remote appears to have completed\n";

#print "Test 3: Intentional failure - remote to local\n";
#$scpe->scp(":blah_blah_blah9999.txt",".");

#print "Test 4: Intentional failure - local to remote\n";
#$scpe->scp("blah_blah_blah9999.txt",":booga_booga_booga7777.txt");

#print "Test 5: Intentional failure - bad login/password\n";
#my $scpe_bogus = Net::SCP::Expect->new(
#   host     => 'exit999',
#   user     => 'blah_blah77',
#   password => '12345', 
#);
