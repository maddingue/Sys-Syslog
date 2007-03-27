use strict;
use Config;
use ExtUtils::MakeMaker;
eval 'use ExtUtils::MakeMaker::Coverage';
use File::Copy;
use File::Path;
use File::Spec;
require 5.006;

if ($] < 5.008) {
    open(TYPEMAP, ">typemap") or die "fatal: can't write typemap: $!";
    print TYPEMAP "const char *\t\tT_PV\n";
    close(TYPEMAP);
}

# virtual paths given to EU::MM
my %virtual_path = ( 'Syslog.pm' => '$(INST_LIBDIR)/Syslog.pm' );

my (@extra_params, @extra_prereqs);
my $use_eventlog = $^O =~ /Win32/i;
$use_eventlog  ||= $^O =~ /Cygwin/i and eval "use Win32::EventLog; 1";

if ($use_eventlog) {
    print " * Win32::EventLog detected.\n";
    my $name = "PerlLog";

    push @extra_prereqs, "Win32::TieRegistry" => 0, "Win32::EventLog" => 0;

    $virtual_path{'win32/Win32.pm'   } = '$(INST_LIBDIR)/Syslog/Win32.pm';
    $virtual_path{'win32/PerlLog.dll'} = '$(INST_ARCHAUTODIR)/PerlLog.dll';

    # recreate the DLL from its uuencoded form if it's not here
    if (! -f File::Spec->catfile("win32", "$name.dll")) {
        # read the uuencoded data
        open(my $uufh, '<', File::Spec->catfile("win32", "$name\_dll.uu"))
            or die "fatal: Can't read file '$name\_dll.uu': $!";
        my $uudata = do { local $/; <$uufh> };
        close($uufh);

        # write the DLL
        open(my $dll, '>', File::Spec->catfile("win32", "$name.dll"))
            or die "fatal: Can't write DLL '$name.dll': $!";
        binmode($dll);
        print $dll unpack "u", $uudata;
        close($dll);
    }
}

WriteMakefile(
    NAME            => 'Sys::Syslog',
    LICENSE         => 'perl',
    VERSION_FROM    => 'Syslog.pm', 
    ABSTRACT_FROM   => 'Syslog.pm', 
    INSTALLDIRS     => 'perl',
    MAN3PODS        => {}, 	# Pods will be built by installman.
    XSPROTOARG      => '-noprototypes',
    PM              => \%virtual_path, 
    PREREQ_PM       => {
        'Test::More' => 0,
        'XSLoader'   => 0,
        @extra_prereqs,
    },
    dist            => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean           => { FILES => 'Sys-Syslog-*' }, 
    realclean       => { FILES => 'const-c.inc const-xs.inc macros.all PerlLog.h *.bak *.bin *.rc' },
    @extra_params
);

my $_PATH_LOG;

if (-S "/dev/log" and -w "/dev/log") {
    # Most unixes have a unix domain socket /dev/log.
    $_PATH_LOG = "/dev/log";
} elsif (-c "/dev/conslog" and -w "/dev/conslog") {
    # SunOS 5.8 has a worldwritable /dev/conslog STREAMS log driver.
    # The /dev/log STREAMS log driver on this platform has permissions
    # and ownership `crw-r----- root sys'.  /dev/conslog has more liberal
    # permissions.
    $_PATH_LOG = "/dev/conslog";
} else {
    $_PATH_LOG = "";
}

if(eval {require ExtUtils::Constant; 1}) {
    my @names = (
            # levels
            qw(
                LOG_ALERT LOG_CRIT LOG_DEBUG LOG_EMERG LOG_ERR 
                LOG_INFO LOG_NOTICE LOG_WARNING
            ), 

            # facilities
            qw(
                LOG_AUTH LOG_AUTHPRIV LOG_CRON LOG_DAEMON LOG_FTP
                LOG_INSTALL LOG_KERN LOG_LAUNCHD LOG_LFMT LOG_LOCAL0 
                LOG_LOCAL1 LOG_LOCAL2 LOG_LOCAL3 LOG_LOCAL4 LOG_LOCAL5 
                LOG_LOCAL6 LOG_LOCAL7 LOG_LPR LOG_MAIL LOG_NETINFO 
                LOG_NEWS LOG_RAS LOG_REMOTEAUTH LOG_SYSLOG LOG_USER LOG_UUCP 
            ), 

            # options
            qw(
                LOG_CONS LOG_PID LOG_NDELAY LOG_NOWAIT LOG_ODELAY LOG_PERROR 
            ), 

            # others macros
            qw(
                LOG_FACMASK LOG_NFACILITIES LOG_PRIMASK 
            ), 

           { name => "_PATH_LOG", type => "PV", default => [ "PV", qq("$_PATH_LOG") ] },
    );

    ExtUtils::Constant::WriteConstants(
        ($] > 5.009002 ? (PROXYSUBS => 1) : ()),
        NAME => 'Sys::Syslog',
        NAMES => \@names,
    );

    open(MACROS, '>macros.all') or warn "warning: Can't write 'macros.all': $!\n";
    print MACROS join $/, grep {!ref} @names;
    close(MACROS);

} else {
    foreach my $file ('const-c.inc', 'const-xs.inc') {
        my $fallback = File::Spec->catfile('fallback', $file);
        copy($fallback, $file) or die "fatal: Can't copy $fallback to $file: $!";
    }
}
