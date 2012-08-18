#!perl -w
# --------------------------------------------------------------------
# Try to send messages with all combinations of facilities and levels
# to a POE syslog server.
# --------------------------------------------------------------------
use strict;
use warnings;

use Test::More;
use Socket;
use Sys::Syslog 0.30 qw< :standard :extended :macros >;


# check than POE is available
plan skip_all => "POE is not available" unless eval "use POE; 1";

# check than POE::Component::Server::Syslog is available and recent enough
plan skip_all => "POE::Component::Server::Syslog is not available"
    unless eval "use POE::Component::Server::Syslog; 1";
plan skip_all => "POE::Component::Server::Syslog is too old"
    if POE::Component::Server::Syslog->VERSION < 1.14;


my $host    = "127.0.0.1";
my $port    = 5140;
my $proto   = "tcp";
my $ident   = "pocosyslog";

my @levels = qw< emerg alert crit err warning notice info debug >;
my @facilities = qw<
    auth cron daemon ftp kern lpr mail news syslog user uucp
    local0 local1 local2 local3 local4 local5 local6 local7
>;

my $parent_pid = $$;
my $child_pid  = fork();

if ($child_pid) {
    plan tests => @facilities * @levels * 2;

    POE::Kernel->has_forked;

    # parent: setup a syslog server
    POE::Component::Server::Syslog->spawn(
        Alias       => 'syslog',
        Type        => $proto, 
        BindAddress => $host,
        BindPort    => $port,

        InputState  => \&client_input,
        ErrorState  => \&client_error,
    );

    $SIG{TERM} = sub {
        POE::Kernel->post(syslog => "shutdown");
        POE::Kernel->stop;
    };

    POE::Kernel->sig_child($child_pid, sub { wait() });
    POE::Kernel->run;
}
else {
    # child: send messages to the syslog server
    sleep 2;
    setlogsock({ host => $host, type => $proto, port => $port });

    # first way, set the facility each time with openlog()
    for my $facility (@facilities) {
        openlog($ident, "ndelay,pid", $facility);

        for my $level (@levels) {
            eval { syslog($level => "<$facility\:$level>") }
                or warn "error: syslog($level => '<$facility\:$level>'): $@";
            select(undef, undef, undef, 0.001);
        }
    }

    # second way, set the facility once with openlog(), then set
    # the message facility with syslog()
    openlog($ident, "ndelay,pid", "user");

    for my $facility (@facilities) {
        for my $level (@levels) {
            eval { syslog("$facility.$level" => "<$facility\:$level>") }
                or warn "error: syslog('$facility.$level' => '<$facility\:$level>'): $@";
            select(undef, undef, undef, 0.001);
        }
    }

    sleep 2;

    # send SIGTERM to the parent
    kill 15 => $parent_pid;
}


sub client_input {
    my $message = $_[&ARG0];
    #delete $message->{'time'};  # too hazardous to test

    # extract the sent facility and level from the message text
    my ($sent_facility, $sent_level) = $message->{msg} =~ /<(\w+):(\w+)>/;

    # resolve their numeric values
    my ($sent_fac_num, $sent_lev_num);
    {
        no strict "refs";
        $sent_fac_num = eval { my $n = uc "LOG_$sent_facility"; &$n } >> 3;
        $sent_lev_num    = eval { my $n = uc "LOG_$sent_level";    &$n };
    }

    is_deeply(
        {   # received message
            facility => $message->{facility},
            severity => $message->{severity},
        },
        {   # sent message
            facility => $sent_fac_num,
            severity => $sent_lev_num,
        },
        "sent<facility=$sent_facility($sent_fac_num), level=$sent_level" .
        "($sent_lev_num)> - rcvd<facility=$message->{facility}, " .
        "level=$message->{severity}>"
    );
}


sub client_error {
    my $message = $_[&ARG0];

    require Data::Dumper;
    $Data::Dumper::Indent   = 0;    $Data::Dumper::Indent   = 0;
    $Data::Dumper::Sortkeys = 1;    $Data::Dumper::Sortkeys = 1;
    fail "checking syslog message";
    diag "[client_error] message = ", Data::Dumper::Dumper($message);

    kill 15 => $child_pid;
    POE::Kernel->post(syslog => "shutdown");
    POE::Kernel->stop;
}

