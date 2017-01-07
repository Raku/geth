#!/usr/bin/env perl6

use lib <lib>;
use Geth::GitHub::Hooks;
use Geth::Config;

constant $port = 8888;
constant $host = '0.0.0.0';
my $events = Geth::GitHub::Hooks.new(
    :host(conf<hooks-listen-host>), :port(conf<hooks-listen-port>), :42debug
).supply;

react {
    whenever $events -> $e {
        say "----------------";
        say "Got a new event!";
        dd $e;
        CATCH { default { .gist.say } }
    }
}

=finish

use lib <
    /home/zoffix/CPANPRC/IRC-Client/lib
    /home/zoffix/services/lib/IRC-Client/lib
    lib
>;

use IRC::Client;

.run with IRC::Client.new:
    :nick<Geth>,
    :username<zofbot-geth>,
    :host(%*ENV<GETH_IRC_HOST> // 'irc.freenode.net'),
    :channels(
        %*ENV<GETH_DEBUG> ?? '#zofbot' !! |<#perl6  #perl6-dev  #zofbot>
    ),
    :debug,
    :plugins(
    );
