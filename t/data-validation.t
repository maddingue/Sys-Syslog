#!perl -Tw
use strict;
use File::Spec;
use Test::More;
use Sys::Syslog;


# --------------------------------------------------------------------
# The aim of this test is to start a syslog server (TCP or UDP) using 
# the one available in POE, make Sys::Syslog connect to it by manually 
# selecting the corresponding mechanism, sending some messages and 
# inside the POE syslog server, check that these message are correctly
# crafted. 
# 
# However, there is a problem: Sys::Syslog has currently no public way
# to allow one to manually select the syslog port to connect to, and 
# it seems that there is no way to override getservbyname() from Perl.
# A solution is to add a way to Sys::Syslog for selecting the syslog 
# port, but I'm quite reluctant if it's just for this very test.
# --------------------------------------------------------------------

# first check than POE is available
plan skip_all => "POE is not available" unless eval "use POE; 1";

# then check than POE::Component::Server::Syslog is available
plan skip_all => "POE::Component::Server::Syslog is not available"
    unless eval "use POE::Component::Server::Syslog; 1";

plan skip_all => "test not written";

plan tests => 1;


diag "[POE] create";
POE::Session->create(
    inline_states => {
        _start  => \&start, 
        _stop   => \&stop,
    },
);

diag "[POE] run";
POE::Kernel->run;

sub start {
    diag "[POE:start] spawning new Syslog server session ", $_[&SESSION]->ID;
    POE::Component::Server::Syslog->spawn(
        Alias       => 'syslog',
        Type        => 'udp', 
        BindAddress => '127.0.0.1',
        BindPort    => '5140',
        InputState  => \&input,
    );

    $_[&KERNEL]->post(syslog => 'run');
}

sub stop {
    diag "[POE:stop]";
    $_[&KERNEL]->post(syslog => 'shutdown');
}
