use IRC::Client;
unit class Geth::Plugin::GitHub is IRC::Client::Plugin;

use IRC::TextColor;
use Geth::Config;
use Geth::GitHub::Hooks;
use Geth::GitHub::Hooks::Preprocessor;

has $.host is required;
has $.port is required;

constant &Δ = &irc-style-text;
constant THROTTLE_LINES_UNTHROTTLED_MAX = 5;
constant THROTTLE_SLEEP    = 2;
constant THROTTLE_COOLDOWN = 8;
constant $NQP_API_URL    = 'https://api.github.com/repos/perl6/nqp';
constant $RAKUDO_API_URL = 'https://api.github.com/repos/rakudo/rakudo';
constant $NQP_URL        = 'https://github.com/perl6/nqp';
constant $MOAR_URL       = 'https://github.com/MoarVM/MoarVM';

my @COMMIT-FILTERS where {
    .all ~~ Callable && .all.count == 1 && .all.name
} = dir("commit-filters", test => *.ends-with: ".pm6").map: *.&EVALFILE
    andthen say "Loaded {+$_} commit filters";

method irc-to-me (
    $ where /^ 'ver' \s+ 'https://github.com/' <-[/]>+ '/'
        $<repo>=<-[/]>+ '/commit/' $<sha>=\S+ $/
) {
    Geth::GitHub::Hooks::Preprocessor.new.fetch-version-bump: |(
        $<repo> eq 'rakudo'
            ?? ("$RAKUDO_API_URL/commits/$<sha>", $NQP_URL)
            !! ("$NQP_API_URL/commits/$<sha>",   $MOAR_URL)
    )
    andthen "version bump brought in these changes: $_"
    orelse "Failed to fetch version bump info because reasons";
}

method irc-started {
    start react {
        whenever Geth::GitHub::Hooks.new(:$!host, :$!port, :9debug) -> $e {
            my @chans = ($e.query<chan> // '').split: ',';
            my @bot-chans = |conf<channels>;
            # XXX TODO: https://github.com/zoffixznet/perl6-IRC-Client/issues/37
            # $.irc.servers».channels.flat.map({
                # $_ ~~ Pair ?? .key !! $_
            # });

            dd [ 'chans', @chans, @bot-chans, @chans ⊆ @bot-chans ];

            if keys @chans ∩ @bot-chans -> @send-to-chans {
                my $text = make-text $e or next;
                for @send-to-chans -> $where {
                    for $text.lines -> $text {
                        throttle { $.irc.send: :$where, :$text }
                    }
                }
            }

            CATCH { default { .gist.say } }
        }
    }
}

sub throttle (&code) {
    state $throttle   = INIT now;
    state $sent-lines = 0;

    if now - $throttle < THROTTLE_COOLDOWN {
        if $sent-lines++ > THROTTLE_LINES_UNTHROTTLED_MAX {
            # dd ["Throttle sleeping for " ~ THROTTLE_SLEEP];
            sleep THROTTLE_SLEEP;
        }
        # else {
            # dd ["Throttle: too fast send, but few lines ($sent-lines)"];
        # }
    }
    else {
        # dd ["Throttle: resetting throttle state"];
        $sent-lines = 0;  # we're past the cooldown; reset line counter
    }
    $throttle = now;

    code();
}

sub make-text ($e) {
    for @COMMIT-FILTERS -> &filter {
        my $res = filter $e orelse next;
        say "Matched filter &filter.name()";
        return $res;
    }

    when $e ~~ Geth::GitHub::Hooks::Event::Push {
        if $e.commits.elems > 3 {
            my @branches = $e.commits».branch.unique.sort;
            prefix-lines $e.repo ~ (
                    @branches == 1 ?? "/@branches[0]"
                    !! @branches > 4 ?? "/\{" ~ +@branches ~ ' branches}'
                    !! '{' ~ @branches.join(',') ~ '}'
                ),
                Δ(:style<bold>, "$e.commits.elems() commits ")
                ~ "pushed by " ~(
                    $e.commits».author.unique».&karma-name.join(", ").substr(0,1000)
                ), (
                    $e.commits.map: *.&make-short-commit-message: $e
                        if $e.commits.elems < 10
                ),
                Δ(:style<bold>,
                    "review: https://github.com/$e.repo-full()/compare/"
                    ~ $e.sha-before.substr(0,10) ~ '...'
                    ~ $e.sha-after .substr(0,10)
                ),
                (
                    "version bump brought these changes: &Δ(:style<bold>, .values.head)"
                    with $e.meta<ver-bump>
                );
        }
        else {
            join "\n", flat $e.commits.map: *.&make-full-commit-message: $e;
        }
    }
    when $e ~~ Geth::GitHub::Hooks::Event::PullRequest {
        prefix-lines $e.repo,
            "&karma-name($e.sender) created pull request #$e.number(): "
            ~ Δ(:style<bold>, $e.title),
            Δ :style<bold>, "review: $e.url()";
    }
}

sub make-short-commit-message ($c, $e) {
    "$c.sha.substr(0, 10) | &Δ(:style<bold>, $c.title)"
}

sub make-full-commit-message ($c, $e) {
    my $header = $c.sha.substr(0, 10) ~ ' | '
        ~ karma-name($c.author) ~ committer-name($c) ~ ' | '
        ~ ($c.files == 1 ?? |$c.files !! "$c.files.elems() files");

    my $message = Δ(:style<bold>, $c.title);
    if $c.message.lines.elems -> $n {
        $message ~= "\n\n" ~ ($n < 10 ?? $c.message !! (
            join "\n", flat $c.message.lines[^5],
                Δ :style<bold>, "<…commit message has {$n - 5} more lines…>";
        ));
    }

    my $review = Δ :style<bold>,
        "review: https://github.com/$e.repo-full()/commit/$c.sha.substr(0, 10)";

    prefix-lines $e.repo ~ ("/$c.branch()" unless $c.branch eq 'master'),
        $header, $message, $review, (
            "version bump brought these changes: &Δ(:style<bold>, $_)"
            with $e.meta<ver-bump>{$c.sha}
        );
}

sub committer-name ($c) {
    with $c.committer {
        when $c.author { '' }
        when 'GitHub'  { ' (committed using GitHub Web editor)' }
        " (committed by $_)"
    }
}

sub karma-name {
    ($^author ~~ /\s/ ?? "($author)" !! $author) ~ '++'
}

sub prefix-lines ($pref, *@text) {
    join "\n", map {"¦ $pref: $_"}, @text.join("\n").lines;
}
