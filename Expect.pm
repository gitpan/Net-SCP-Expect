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
use File::Basename;
use Carp;
use Cwd;

$SIG{CHLD} = \&reapChild;

BEGIN{
   use vars qw/$VERSION/;
   $VERSION = '.04';
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
      _error_handler => $arg{error_handler},
      _preserve      => $arg{preserve} || 0,
      _recursive     => $arg{recursive} || 0,
      _verbose       => $arg{verbose} || 0,
      _auto_yes      => $arg{auto_yes} || 0,
      _timeout       => $arg{timeout} || 10,
      _timeout_auto  => $arg{timeout_auto} || 1,
      _timeout_err   => $arg{timeout_err} || 1,
      _no_check      => $arg{no_check} || 0,
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

sub auto_yes{
   my($self,$val) = @_;
   croak("No value passed to 'auto_yes()' method") unless defined $val;
   $self->_set('auto_yes',$val);
}

sub error_handler{
   my($self,$sub) = @_;
   croak("No sub supplied to 'error_handler()' method") unless defined $sub;
   $self->_set('error_handler',$sub)
}

sub login{
   my($self,$user,$password) = @_;
   
   croak("No user supplied to 'login()' method") unless defined $user;
   croak("No password supplied to 'password()' method") unless defined $password;

   $self->_set('user',$user);
   $self->_set('password',$password);
}

sub password{
   my($self,$password) = @_;
   croak("No password supplied to 'password()' method") unless $password;
   
   $self->_set('password',$password);
}

sub host{
   my($self,$host) = @_;
   croak("No host supplied to 'host()' method") unless $host;
   $self->_set('host',$host);
}


sub user{
   my($self,$user) = @_;
   croak("No user supplied to 'user()' method") unless $user;
   $self->_set('user',$user);
} 

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# If the hostname is not included as part of the source, it is assumed to
# be part of the destination.
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub scp{
   my($self,$from,$to) = @_;

   my $login        = $self->_get('user');
   my $password     = $self->_get('password');
   my $timeout      = $self->_get('timeout');
   my $timeout_auto = $self->_get('timeout_auto');
   my $timeout_err  = $self->_get('timeout_err');
   my $cipher       = $self->_get('cipher');
   my $port         = $self->_get('port');
   my $recursive    = $self->_get('recursive');
   my $verbose      = $self->_get('verbose');
   my $preserve     = $self->_get('preserve');
   my $host         = $self->_get('host');
   my $handler      = $self->_get('error_handler');
   my $auto_yes     = $self->_get('auto_yes');
   my $no_check     = $self->_get('no_check');
 
   my($check,$file,$reverse);

   ##################################################################
   # If the second argument is not provided, the remote file will be
   # given the same (base) name as the local file (or vice-versa).
   ##################################################################
   unless($to){
      $to = basename($from);
   }  

   # This is probably lame.  Bite me.
   if($from =~ /(\w+)?:(.*?)$/){
      my $temp = $to;
      $to = $from;
      $from = $temp;
      $reverse++;
   }
   else{
      $check++;
   }

   if($to =~ /^(\w+)@(\w+):(.*?)$/){
      $login = $1 || $login;
      $host  = $2 || $host;
      $file  = $3 || basename($from);
   }
   elsif($to =~ /^(\w+):(.*?)$/){
      $host = $1 || $host;
      $file = $2 || basename($from);
   }
   elsif($to =~ /^:?(.*?)$/){
      $file = $1 || basename($from);
   }
   else{}

   $to = "$login\@$host:$file";

   if($reverse){
      my $temp = $to;
      $to = $from;
      $from = $temp;
   }

   croak("No login. Can't scp") unless $login;
   croak("No password. Can't scp") unless $password;

   # Don't check in a remote-to-local scenario
   if($check){
      croak("No such file: $from") unless -e $from;
   }

   # Gather flags.
   my $flags;

   $flags .= "-c $cipher " if $cipher;
   $flags .= "-P $port " if $port;
   $flags .= "-r " if $recursive;
   $flags .= "-v " if $verbose;
   $flags .= "-p " if $preserve;
   $flags .= "-q ";  # Always pass this option (no progress meter)

   my $scp = Expect->new;
   #$scp->raw_pty(1); # Don't take a chance on an echo'd password

   $scp = Expect->spawn("scp $flags $from $to") or croak "Couldn't start program: $!\n";

   $scp->log_stdout(0);

   if($auto_yes){
      while($scp->expect($timeout_auto,-re=>'[Yy]es\/[Nn]o')){
         $scp->send("yes\n");
      }
   }

   unless($scp->expect($timeout,-re=>'[Pp]assword:|[Pp]assphrase:')){
      my $err = $scp->before();
      if($err){
         if($handler){ $handler->($err) }
         croak("Problem performing scp: $err");
      }
      croak("scp timed out while trying to connect to $host");
   }

   if($verbose){ print $scp->before() }

   #$scp->log_file(\&handleErr);
   $scp->send("$password\n");

   #############################################################
   # Check to see if we sent the correct password, or if we got
   # some other bizarre error.  Anything passed back to the
   # terminal at this point means that something went wrong.
   #############################################################
   unless($no_check){
      if($scp->expect($timeout_err,-re=>'[Pp]ass.*')){
         my $error = $scp->before() || $scp->match();
         if($handler){
            $handler->($error);
         }
        croak("Error: Bad password");
      }

      if($scp->expect($timeout_err,'.*?')){
         my $error = $scp->match();
         if($handler){
            $handler->($error);
         }
         croak("Error - last line returned was: $error");
      }
   }

   if($verbose){ print $scp->after(),"\n" }

   $scp->soft_close();
   $scp->hard_close() if $scp;
   return;
}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# As far as I can tell, just about *all* output, regardless of whether or not
# it's a true error, will get sent here.  Hence, the regex check.
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#sub handleErr{
#   my $err = shift;
#   if($err =~ /permission denied/i){
#      croak("Invalid password");
#   }
#}

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


See the B<scp()> method for more information on valid syntax.

=head1 PREREQUISITES

Expect 1.14.  May work with earlier versions, but was tested with 1.14 (and now 1.15)
only.

=head1 DESCRIPTION

This module is simply a wrapper around the scp call.  The primary difference between
this module and I<Net::SCP> is that you may send a password programmatically, instead
of being forced to deal with interactive sessions.

=head1 USAGE

B<Net::SCP::Expect-E<gt>new(>I<option=E<gt>val>,...B<)>

Creates a new object and optionally takes a series of options (see OPTIONS below).

=head2 METHODS

B<auto_yes> - Set this to 1 if you want to automatically pass a 'yes' string to
any yes or no questions that you may encounter before actually being asked for
a password, e.g. "Are you sure you want to continue connecting (yes/no)?" for
first time connections, etc.

B<error_handler(>I<sub ref>B<)>

This sets up an error handler to catch any problems with a call to 'scp()'.  If you
do not define an error handler, then a simple 'croak()' call will occur, with the last
line sent to the terminal added as part of the error message.

I highly recommend you forcibly terminate your program somehow within your handler
(via die, croak, exit, etc), otherwise your program may hang, as it sits there waiting
for terminal input.

B<host(>I<host>B<)>

Sets the host for the current object

B<login(>I<login,password>B<)>

If the login and password are not passed as options to the constructor, they
must be passed with this method (or set individually - see 'user' and 'password'
methods).  If they were already set, this method will overwrite them with the new
values.

B<password(>I<password>B<)>

Sets the password for the current user

B<user(>I<user>B<)>

Sets the user for the current object


B<scp()>

Copies the file from source to destination.  If no host is specified, you
will be using 'scp' as an expensive form of 'cp'.

There are several valid ways to use this method

B<LOCAL TO REMOTE>

B<scp(>I<source, user@host:destination>B<);>

B<scp(>I<source, host:destination>B<);> # User already defined

B<scp(>I<source, :destination>B<);> # User and host already defined

B<scp(>I<source, destination>B<);> # Same as previous

B<REMOTE TO LOCAL>

B<scp(>I<user@host:source, destination>B<);>

B<scp(>I<host:source, destination>B<);>

B<scp(>I<:source, destination>B<);>


=head1 OPTIONS

B<auto_yes> - Set this to 1 if you want to automatically pass a 'yes' string to
any yes or no questions that you may encounter before actually being asked for
a password, e.g. "Are you sure you want to continue connecting (yes/no)?" for
first time connections, etc.

B<cipher> - Selects the cipher to use for encrypting the data transfer.

B<host> - Specify the host name.  This is now useful for both local-to-remote
and remote-to-local transfers.

B<no_check> - Set this to 1 if you want to turn off error checking.  Use this
if you're absolutely positive you won't encounter any errors and you want to
speed up your scp calls - up to 2 seconds per call (based on the defaults).

B<password> - The password for the given login.

B<port> - Use the specified port.

B<preserve> - Preserves modification times, access times, and modes from
the original file.

B<recursive> - Set to 1 if you want to recursively copy entire directories.

B<timeout> - Sets the timeout value for your scp operation. The default
is 10 seconds.

B<timeout_auto> - Sets the timeout for the 'auto_yes' option.  I separated
this from the standard timeout because generally you won't need nearly as much
time as you would for a standard timeout, otherwise your script will drag
considerably.  The default is 1 second (which should be plenty).

B<timeout_err> - Sets the timeout for the additional error checking that the
module does.  Because errors come back almost instantaneously, I thought it
best to make this a separate option for the same reasons as the 'timeout_auto'
option above.  The default is 1 second.

B<user> - The login name you wish to use.

B<verbose> - Set to 1 if you want verbose output sent to STDOUT.

=head1 NOTES

The -q option (disable progress meter) is automatically passed to scp.

The -B option may NOT be set.  If you don't want to send passwords, I
recommend using I<Net::SCP> instead.

In the event that Ben Trott releases a version of I<Net::SSH::Perl> that
supports scp, I recommend using that instead.  Why?  First, it will be
a more secure way to perform scp.  Second, this module is not fast,
even with error checking turned off.  Both reasons have to do with TTY
interaction.

Don't whine to me about putting passwords in scripts.  Set your
permissions appropriately or use a .rc file of some kind.

=head1 FUTURE PLANS

There are a few options I haven't implemented.  If you *really* want to
see them added, let me know and I'll see what I can do.

A test suite (yes, I almost have one together) - no really, I promise!

=head1 KNOWN BUGS

At least one user has reported warnings related to POD parsing with Perl 5.00503.
These can be safely ignored.  They do not appear in Perl 5.6 or later.

I have one unconfirmed report of problems with wildcard characters.  I haven't
had a chance to test this yet.

=head1 THANKS

Thanks to Roland Giersig (and Austin Schutz) for the Expect module.  Very handy.

=head1 AUTHOR

Daniel Berger

djberg96@hotmail.com
