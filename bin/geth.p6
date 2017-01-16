#!/usr/bin/env perl6

use lib <
    /home/zoffix/services/lib/IRC-Client/lib
    lib
>;

use IRC::Client;
use Geth::Config;
use Geth::Plugin::GitHub;

class Geth::Plugin::Info {
    multi method irc-to-me ($ where /^ \s* ['help' | 'source' ] '?'? \s* $/) {
        "Source at https://github.com/perl6/geth "
        ~ "To add repo, add an 'application/json' webhook on GitHub "
        ~ "pointing it to http://geth.perl6.party/?chan=#perl6 and choose "
        ~ "'Send me everything' for events to send | use `ver URL to commit` "
        ~ "to fetch version bump changes";
    }
}

.run with IRC::Client.new:
    :debug,
    :nick(conf<nick>),
    :username<zofbot-geth>,
    :host(%*ENV<GETH_IRC_HOST> // conf<host>),
    :channels( %*ENV<GETH_DEBUG> ?? |('#zofbot', '#perl6') !! |conf<channels> ),
    :plugins(
        Geth::Plugin::GitHub.new(
            :host(conf<hooks-listen-host>),
            :port(conf<hooks-listen-port>),
        ),
        Geth::Plugin::Info.new,
    );
