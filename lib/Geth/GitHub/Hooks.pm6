unit class Geth::GitHub::Hooks;

use Geth::GitHub::Hooks::Preprocessor;

use HTTP::Server::Tiny;
use JSON::Tiny;
use URI::Encode;

has $.debug = False;
has $.port = 8888;
has $.host = '0.0.0.0';
has $!supplier = Supplier.new;
has $.Supply   = $!supplier.Supply;

constant $OK_RES      = (200, ['Content-Type' => 'text/plain'], [ 'OK'      ]);
constant $IGNORED_RES = (200, ['Content-Type' => 'text/plain'], [ 'Ignored' ]);
constant @SUPPORTED_EVENTS = <push  pull_request  issues>;

submethod TWEAK {
    start {
        HTTP::Server::Tiny.new(:$!host , :$!port).run: sub ($env) {
            unless $env<HTTP_X_GITHUB_EVENT> ∈ @SUPPORTED_EVENTS {
                say "{DateTime.now} Ignoring unsupported event "
                    ~ "`{$env<HTTP_X_GITHUB_EVENT>//''}`";
                return $IGNORED_RES;
            }

            say "ENV $env.perl()" if $!debug;
            my $data = [~] $env<p6w.input>.List;
            $data .= decode unless $data ~~ Str;
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

            $OK_RES;
        };
        CATCH { default { .gist.say } }
    }
}

class Event {
    has $.repo;
    has $.repo-full;
    has $.stars;
    has $.issues;
    has %.query;
    has $.meta;
}

class Event::Push is Event {
    has $.compare-url;
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

class Event::Issues::Assigned is Event {
    has $.sender;
    has $.assignee;
    has $.url;
    has $.title;
    method self-self { $!sender eq $!assignee }
}
class Event::Issues::Unassigned is Event {
    has $.sender;
    has $.assignee;
    has $.url;
    has $.title;
    method self-self { $!sender eq $!assignee }
}

sub make-event ($e, :$event, :$query) {
    Geth::GitHub::Hooks::Preprocessor.new.preprocess($e, :$event);
    my %basics =
        repo      => $e<repository><name>,
        repo-full => $e<repository><full_name>,
        stars     => $e<repository><stargazers_count>,
        issues    => $e<repository><open_issues_count>,
        meta      => $e<geth-meta> || {},
        query     => (
            $query ?? $query.split(/<[=&]>/).map(*.&uri_decode).Hash !! %()
        ),
    ;

    given $event {
        when 'push' {
            Event::Push.new:
                |%basics,
                compare-url => $e<compare>,
                commits     => $e<commits>.map: -> $commit {
                    Event::Push::Commit.new:
                        sha       => $commit<id>,
                        branch    => $e<ref>.subst(/^'refs/heads/'/, ''),
                        url       => $commit<url>,
                        author    => $commit<author><name>,
                        committer => $commit<committer><name>,
                        title     => $commit<message>.lines.head,
                        message   => $commit<message>.lines[1..*].join("\n").trim,
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
        when $event eq 'issues' and $e.<action> eq 'assigned' {
            Event::Issues::Assigned.new: |%basics,
                sender   => $e<sender><login>,
                assignee => $e<assignee><login>,
                url      => $e<issue><html_url>,
                title    => $e<issue><title>,
            ;
        }
        when $event eq 'issues' and $e.<action> eq 'unassigned' {
            Event::Issues::Unassigned.new: |%basics,
                sender   => $e<sender><login>,
                assignee => $e<assignee><login>,
                url      => $e<issue><html_url>,
                title    => $e<issue><title>,
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
