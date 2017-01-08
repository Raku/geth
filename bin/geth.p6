#!/usr/bin/env perl6

use lib <
    /home/zoffix/services/lib/IRC-Client/lib
    lib
>;

use IRC::Client;
use Geth::Config;
use Geth::Plugin::GitHub;

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
    );
