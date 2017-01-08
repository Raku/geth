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
        say "-" x 100;
        say "Got $data" if $!debug;
        say "-" x 100;
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

class Event::PullRequest is Event {
    has $.number;
    has $.url;
    has $.title;
    has $.sender;
}

sub make-event ($e, :$event, :$query) {
    my %basics =
        repo      => $e<repository><name>,
        repo-full => $e<repository><full_name>,
        stars     => $e<repository><stargazers_count>,
        issues    => $e<repository><open_issues_count>,
        query     => $query.split(/<[=&]>/).map(*.&uri_decode).Hash,
    ;

    given $event {
        when 'push' {
            Event::Push.new:
                |%basics,
                pusher  => $e<pusher><name>,
                commits => $e<commits>.map: -> $commit {
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
        when $event eq 'pull_request' and $e.<action> eq 'opened' {
            Event::PullRequest.new:
                |%basics,
                sender => $e<sender><login>,
                number => $e<pull_request><number>,
                url    => $e<pull_request><html_url>,
                title  => $e<pull_request><title>,
            ;
        }
        default {
            say "-" x 100;
            say "Got `$event` event";
            dd [$query, $e];
            say "-" x 100;
            return;
        }
    }
}
