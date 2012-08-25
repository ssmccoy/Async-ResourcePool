#!/usr/bin/perl

use Module::Build;

my $build = Module::Build->new(
    module_name  => "Async::ResourcePool",
    version      => "0.0.1",

    requires       => { },
    build_requires => {
        "Test::More" => 0,
    },
);

$build->create_build_script;
