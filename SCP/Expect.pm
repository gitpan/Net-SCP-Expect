##################################################################
# Net::SCP::Expect
#
# Wrapper for scp, with the ability to send passwords via Expect.
#
# See POD for more details.
##################################################################
package Net::SCP::Expect;
use strict;
use Expect;
use POSIX qw(:signal_h WNOHANG);
use Carp;
use Cwd;

$SIG{CHLD} = \&reapChild;

BEGIN{
   use vars qw/$VERSION/;
   $VERSION = '.01';
}

# Options added as needed
sub new{
   my($class,%arg) = @_;

   my $self = {
      _host          => $arg{host},
      _user          => $arg{user},
      _password      => $arg{password},
      _cipher        => $arg{cipher},
      _port          => $arg{port},
      _preserve      => $arg{preserve} || 0,
      _recursive     => $arg{recursive} || 0,
      _verbose       => $arg{verbose} || 0,
      _timeout       => $arg{timeout} || 10,
   };

   bless($self,$class);
}

sub _get{
   my($self,$attr) = @_;
   croak("No attribute supplied to 'get()' method") unless defined $attr;
   return $self->{"_$attr"};
}

sub _set{
   my($self,$attr,$val) = @_;
   croak("No attribute supplied to 'set()' method") unless defined $attr;
   $self->{"_$attr"} = $val;
}

sub login{
   my($self,$user,$password) = @_;
   
   croak("No user supplied to 'login()' method") unless defined $user;
   croak("No password supplied to 'password()' method") unless defined $password;

   $self->_set('user',$user);
   $self->_set('password',$password);
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# If the hostname is not included as part of the source, it is assumed to
# be part of the destination.
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub scp{
   my($self,$from,$to) = @_;

   my $login     = $self->_get('user');
   my $password  = $self->_get('password');
   my $timeout   = $self->_get('timeout');
   my $cipher    = $self->_get('cipher');
   my $port      = $self->_get('port');
   my $recursive = $self->_get('recursive');
   my $verbose   = $self->_get('verbose');
   my $preserve  = $self->_get('preserve');

   croak("No login. Can't scp") unless $login;
   croak("No password. Can't scp") unless $password;

   my $host = $self->_get('host');
   $to = "$host:" unless $to;

   if($to =~ /^\w+:\w+$/){
      my $temp = $from;
      $from = $to;
      $to = $temp;
   }

   croak("No such file: $from") unless -e $from;

   # Gather flags.
   my $flags;

   $flags .= "-c $cipher " if $cipher;
   $flags .= "-P $port " if $port;
   $flags .= "-r " if $recursive;
   $flags .= "-v " if $verbose;
   $flags .= "-p " if $preserve;

   my $scp = Expect->new;
   $scp->raw_pty(1); # Don't take a chance on an echo'd password

   if($flags){
      $scp = Expect->spawn("scp $flags $from $to") or croak "Couldn't start program: $!\n";
   }
   else{
      $scp = Expect->spawn("scp $from $to") or croak "Couldn't start program: $!\n";
   }

   $scp->log_stdout(0);

   unless($scp->expect($timeout,-re=>'[Pp]assword')){
      my $err = $scp->before();
      if($err){
         croak("Problem performing scp: $err");
      }
      croak("scp timed out");
   }

   if($verbose){ print $scp->before() }

   $scp->log_file(\&handleErr);
   $scp->send("$password\n");

   if($verbose){ print $scp->after(),"\n" }

   $scp->soft_close();
   $scp->hard_close() if $scp;
}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# As far as I can tell, just about *all* output, regardless of whether or not
# it's a true error, will get sent here.  Hence, the regex check.
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub handleErr{
   my $err = shift;
   if($err =~ /permission denied/i){
      croak("Invalid password");
   }
}

sub reapChild{
   do {} while waitpid(-1,WNOHANG) > 0;
}
1;
__END__

=head1 NAME

Net::SCP::Expect - Wrapper for scp that allows passwords via Expect.

=head1 SYNOPSIS

B<Example 1 - uses login method, longhand scp:>

C<< my $scpe = Net::SCP::Expect->new; >>

C<< $scpe->login('user name', 'password'); >>

C<< $scpe->scp('file','host:/some/dir'); >>

.

B<Example 2 - uses constructor, shorthand scp:>

C<< my $scpe = Net::SCP::Expect->new(host=>'host', user=>'user', password=>'xxxx'); >>

C<< $scpe->scp('file','/some/dir'); # 'file' copied to 'host' at '/some/dir' >>

.

B<Example 3 - Copying from remote machine to local host>

C<< my $scpe = Net::SCP::Expect->new(user=>'user',password=>'xxxx'); >>

C<< $scpe->scp('host:/some/dir/filename','newfilename'); >>

=head1 PREREQUISITES

Expect 1.14.  May work with earlier versions, but was tested with 1.14 only.

=head1 DESCRIPTION

This module is simply a wrapper around the scp call.  The primary difference between
this module and I<Net::SCP> is that you may send a password programmatically, instead
of being forced to deal with interactive sessions.

=head1 USAGE

B<Net::SCP::Expect-E<gt>new(>I<option=E<gt>val>,...B<)>

Creates a new object and optionally takes a series of options (see below).

B<login(>I<login,password>B<)>

If the login and password are not passed as options to the constructor, they
must be passed with this method.  If they were already set, this method will
overwrite them with the new values.  Failure to pass a login or a password to
this method will cause the program to croak.

B<scp(>I<source, host:destination>B<);>

or

B<scp(>I<host:source, destination>B<);>

or

B<scp(>I<source, destination>B<);> # Same as B<scp(>I<source, host:destination>B<)>

Copies the file from source to destination.  If the host name is omitted from
this method, then it is assumed that you are copying from the local machine
to a remote destination on I<host>.  Of course, if you didn't specify a host,
then you are simply using scp as an expensive version of cp.

To copy from a remote location to your local machine, you must use the longhand form.

=head1 OPTIONS

B<cipher> - Selects the cipher to use for encrypting the data transfer.

B<host> - Specify the host name.  This is only useful if you are copying from
the local machine to a remote machine, but NOT vice-versa.

B<password> - The password for the given login.

B<port> - Use the specified port.

B<preserve> - Preserves modification times, access times, and modes from
the original file.

B<recursive> - Set to 1 if you want to recursively copy entire directories.

B<timeout> - Sets the timeout value for your operation. The default
is 10 seconds.

B<user> - The login name you wish to use.

B<verbose> - Set to 1 if you want verbose output sent to STDOUT.

=head1 NOTES

The -q option (disable progress meter) is automatically passed to scp.

The -B option may NOT be set.  If you don't want to send passwords, I
recommend using I<Net::SCP> instead.

In the event that Ben Trott releases a version of I<Net::SSH::Perl> that
supports scp, I recommend using that instead.

Don't whine to me about putting passwords in scripts.  Set your
permissions appropriately or use a .rc file of some kind.

=head1 FUTURE PLANS

There are a few options I haven't implemented.  If you *really* want to
see them added, let me know and I'll see what I can do.

A test suite

=head1 THANKS

Thanks to Roland Giersig (and Austin Schutz) for the Expect module.  Very handy.

=head1 AUTHOR

Daniel Berger

djberg96@hotmail.com
