#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use Reporty;

Reporty->setup_engine('PSGI');
my $app = sub { Reporty->run(@_) };

