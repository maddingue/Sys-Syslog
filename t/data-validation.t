#!/usr/bin/perl -Tw
use strict;
use File::Spec;
use Test::More;
use Sys::Syslog;

eval "use POE::Component::Server::Syslog";
plan skip_all => "POE::Component::Server::Syslog is not available";

plan skip_all => "test not written";

POE::Component::Server::Syslog->spawn(
	Type        => 'udp', 
	BindAddress => '127.0.0.1',
	BindPort    => '5140',
	InputState  => \&input,
);
