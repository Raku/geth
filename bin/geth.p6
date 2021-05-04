#!/usr/bin/env perl6

use Number::Denominate;
use IRC::Client;
use Geth::Config;
use Geth::Plugin::GitHub;
use Log:auth<cpan:TYIL>;

if (%*ENV<RAKU_LOG_CLASS>:exists) {
    $Log::instance = (require ::(%*ENV<RAKU_LOG_CLASS>)).new;
    $Log::instance.add-output($*OUT, %*ENV<RAKU_LOG_LEVEL> // Log::Level::Info);
}

class Geth::Plugin::Info is IRC::Client::Plugin {
    multi method irc-to-me ($ where /^ \s* ['help' | 'source' ] '?'? \s* $/) {
        "Source at https://github.com/perl6/geth "
        ~ "To add repo, add an 'application/json' webhook on GitHub "
        ~ "pointing it to https://geth.svc.tyil.net/?chan=%23perl6 and choose "
        ~ "'Send me everything' for events to send | use `ver URL to commit` "
        ~ "to fetch version bump changes";
    }
}

class Geth::Plugin::Uptime is IRC::Client::Plugin {
    multi method irc-to-me ($ where /^ \s* 'uptime' '?'? \s* $/) {
        denominate now - INIT now;
    }
}

.info("Connecting to {conf<host>} as {conf<nick>}") with $Log::instance;

my $client = IRC::Client.new(
    :debug,
    :nicks([conf<nick>, 'geth_', 'geth__', 'geth___']),
    :username<zofbot-geth>,
    :host(%*ENV<GETH_IRC_HOST> // conf<host>),
    :channels( |conf<channels> ),
    :plugins(
        Geth::Plugin::GitHub.new(
            :host(conf<hooks-listen-host>),
            :port(conf<hooks-listen-port>),
        ),
        Geth::Plugin::Info.new,
        Geth::Plugin::Uptime.new,
    )
).start;

react {
	whenever signal(SIGINT) {
		$client.stop;
		exit(0);
	}
}
