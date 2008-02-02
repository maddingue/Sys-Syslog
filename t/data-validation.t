#!perl -w
# --------------------------------------------------------------------
# The aim of this test is to start a syslog server (TCP or UDP) using 
# the one available in POE, make Sys::Syslog connect to it by manually 
# select the corresponding mechanism, send some messages and, inside 
# the POE syslog server, check that these message are correctly crafted. 
# --------------------------------------------------------------------
use strict;

my $port;
BEGIN {
    # override getservbyname()
    *CORE::GLOBAL::getservbyname = sub ($$) {
        my @v = CORE::getservbyname($_[0], $_[1]);

        if (@v) {
            $v[2] = $port;
        } else {
            @v = ($_[0], "", $port, $_[1]);
        }

        return @v
    }
}

use File::Spec;
use Test::More;
use Sys::Syslog qw(:DEFAULT setlogsock);


# check than POE is available
plan skip_all => "POE is not available" unless eval "use POE; 1";

# check than POE::Component::Server::Syslog is available
plan skip_all => "POE::Component::Server::Syslog is not available"
    unless eval "use POE::Component::Server::Syslog; 1";

plan tests => 1;

   $port    = 5140;
my $proto   = "tcp";
my $text    = "Close the world, txEn eht nepO.";


my $pid = fork();

if ($pid) {
    # parent: setup a syslog server
    diag "[POE spawn syslog]";
    POE::Component::Server::Syslog->spawn(
        Alias       => 'syslog',
        Type        => $proto, 
        BindAddress => '127.0.0.1',
        BindPort    => $port,
        InputState  => \&client_input,
        ErrorState  => \&client_error,
    );

    diag "[POE create session]";
    POE::Session->create(
        inline_states => {
            _start  => \&start, 
            _stop   => \&stop,
            _input  => \&client_input,
            _error  => \&client_error,
        },
    );

    diag "[POE run]";
    POE::Kernel->run;
}
else {
    # child: send a message to the syslog server setup in the parent
    diag "(child started)";
    sleep 2;
    diag "(openlog)";    openlog("pocosyslog", "ndelay,pid", "local0");
    diag "(setlogsock)"; setlogsock($proto);
    diag "(syslog)";     syslog(info => $text);
    closelog();
    diag "(child ending)";
}


sub start {
    diag "[start] session #", $_[&SESSION]->ID;
    $_[&KERNEL]->call(syslog => register => {
        InputEvent => '_input', ErrorEvent => '_error'
    });
    #$_[&KERNEL]->post(syslog => 'run');
}

sub stop {
    diag "[stop]";
    $_[&KERNEL]->post(syslog => 'shutdown');
}

sub client_input {
    my $message = $_[&ARG0];
    diag "[client_input] message = $message";
}

sub client_error {
    my $message = $_[&ARG0];
    diag "[client_error] message = $message";
}

