#!perl -w
use strict;
use Test::More;

plan skip_all => "Pod spelling: for developer interest only :)" unless -d 'releases';
plan skip_all => "Test::Spelling required for testing POD spell"
    unless eval "use Test::Spelling; 1";

set_spell_cmd('aspell -l --lang=en');
add_stopwords(<DATA>);
all_pod_files_spelling_ok();

__END__

SAPER
Sébastien
Aperghis
Tramoni
Aperghis-Tramoni
Christiansen
Kobes
Hedden
Reini
Harnisch
AnnoCPAN
CPAN
README
TODO
AUTOLOADER
API
arrayref
arrayrefs
hashref
hashrefs
lookup
hostname
loopback
netmask
timestamp
INET
BPF
IP
TCP
tcp
UDP
udp
UUCP
NTP
FDDI
Firewire
HDLC
IEEE
IrDA
LocalTalk
PPP
unix
FreeBSD
NetBSD
Solaris
IRIX
endianness
failover
Failover
logopts
pathname
syslogd
Syslogging
logmask
AIX
SUSv
SUSv3
Tru
Tru64
UX
HP-UX
VOS
NetInfo
VPN
launchd
logalert
