use strict;
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

my (@extra_params, @extra_prereqs);
if ($^O =~ /Win32/i) {
    my $name = "PerlLog";
    push @extra_params, MYEXTLIB => File::Spec->catfile("win32", "$name.RES");
    push @extra_prereqs, "Win32::TieRegistry" => 0, "Win32::EventLog" => 0;

    mkpath(File::Spec->catdir("lib", "Sys", "Syslog"))
        or die "fatal: Failed to create 'lib/Sys/Syslog': $!"
        if !-d "lib/Sys/Syslog";

    copy("win32/Win32.pm" => "lib/Sys/Syslog/Win32.pm")
        or die "fatal: Failed to copy Win32.pm into place: $!";

    # recreate the resource file from its uuencoded form if it's not here
    if (! -f File::Spec->catfile("win32", "$name.RES")) {
        open(my $uufh, '<', File::Spec->catfile("win32", "$name\_RES.uu"))
        or die "fatal: Can't read file '$name\_RES.uu': $!";
        my $uudata = do { local $/; <$uufh> };
        close($uufh);
        open(my $rsrc, '>', File::Spec->catfile("win32", "$name.RES"))
        or die "fatal: Can't write resource file '$name.RES': $!";
        print $rsrc pack "u", $uudata;
        close($rsrc);
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
