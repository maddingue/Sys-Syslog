#!perl -wT
use strict;
use Test::More;
use Pod::Checker;

plan skip_all => "Test::Pod 1.14 required for testing POD"
    unless eval "use Test::Pod 1.14; 1";

all_pod_files_ok();

my $checker = Pod::Checker->new(-warnings => 1);
$checker->parse_from_file($_, \*STDERR) for all_pod_files();
