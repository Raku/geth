unit class Geth::GitHub::Hooks;

use HTTP::Server::Tiny;
use JSON::Tiny;
use URI::Encode;

has $.debug = False;
has $.port = 8888;
has $.host = '0.0.0.0';
has $!supplier = Supplier.new;
has $.Supply   = $!supplier.Supply;

submethod TWEAK {
    start HTTP::Server::Tiny.new(:$!host , :$!port).run: -> $env {
        my $data = $env<p6sgi.input>.slurp-rest;
        # say "ENV $env.perl()" if $!debug;
        say "Got $data" if $!debug;
        my $decoded-data = (try from-json $data)
            // %( error => "Failed to decode data: $!" );
        $!supplier.emit: $_ for make-event(
            $decoded-data,
            :event($env<HTTP_X_GITHUB_EVENT>),
            :query($env<QUERY_STRING>),
        );
        200, ['Content-Type' => 'text/plain'], [ 'OK' ]
    };
}

class Event {
    has $.repo;
    has $.repo-full;
    has $.stars;
    has $.issues;
    has %.query;
}

class Event::Push is Event {
    has $.pusher;
    has @.commits;

    class Commit {
        has $.sha;
        has $.branch;
        has $.url;
        has $.title;
        has $.message;
        has $.author;
        has $.committer;
        has @.files;
    }
}


sub make-event ($e, :$event, :$query) {
    gather { given $event {
        when 'push' {
            take Event::Push.new:
                repo      => $e<repository><name>,
                repo-full => $e<repository><full_name>,
                stars     => $e<repository><stargazers_count>,
                issues    => $e<repository><open_issues_count>,
                query     => $query.split(/<[=&]>/).map(*.&uri_decode).Hash,
                pusher    => $e<pusher><name>,

                commits   => do for |$e<commits> -> $commit {
                    Event::Push::Commit.new:
                        sha       => $commit<id>,
                        branch    => $e<ref>.subst(/^'refs/heads/'/, ''),
                        url       => $commit<url>,
                        author    => $commit<author><name>,
                        committer => $commit<committer><name>,
                        title     => $commit<message>.lines.head,
                        message   => $commit<message>.lines[2..*].join("\n"),
                        files     => [ sort unique
                            |$commit<modified>, |$commit<added>,
                            |$commit<removed>
                        ]
                };
        }
        default {
            say "Got `$event` event";
        }
    }}
}
