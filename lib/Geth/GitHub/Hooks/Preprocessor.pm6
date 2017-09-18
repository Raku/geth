unit class Geth::GitHub::Hooks::Preprocessor;

use HTTP::UserAgent;
use JSON::Tiny;
use URI::Encode;

has $!ua = HTTP::UserAgent.new: :useragent('github.com/perl6/geth');
constant $NQP_API_URL    = 'https://api.github.com/repos/perl6/nqp';
constant $RAKUDO_API_URL = 'https://api.github.com/repos/rakudo/rakudo';
constant $NQP_URL        = 'https://github.com/perl6/nqp';
constant $MOAR_URL       = 'https://github.com/MoarVM/MoarVM';
constant $RAKUDO_URL     = 'https://github.com/rakudo/rakudo';

method preprocess ($json, :$event) {
    given $event {
        when 'push' {
            self.moar-version-bump: $json
                if  $json<ref> eq 'refs/heads/master'
                    and $json<repository><html_url> eq $NQP_URL;

            self.nqp-version-bump: $json
                if  $json<ref> eq 'refs/heads/nom'
                    and $json<repository><html_url> eq $RAKUDO_URL;
        }
    }
}

method nqp-version-bump ($json) {
    my $commit = $json<commits>.first: {
        .<added> + .<removed> == 0 and .<modified> == 1
        and .<modified>[0] eq 'tools/build/NQP_REVISION'
    } or return;

    self.fetch-version-bump: "$RAKUDO_API_URL/commits/$commit<id>", $NQP_URL
        andthen $json<geth-meta><ver-bump>{$commit<sha>} = $_;
}

method moar-version-bump ($json) {
    my $commit = $json<commits>.first: {
        .<added> + .<removed> == 0 and .<modified> == 1
        and .<modified>[0] eq 'tools/build/MOAR_REVISION'
    } or return;

    self.fetch-version-bump: "$NQP_API_URL/commits/$commit<id>", $MOAR_URL
        andthen $json<geth-meta><ver-bump>{$commit<id>} = $_;
}

method fetch-version-bump ($commit-url, $compare-url-part) {
    given $!ua.get($commit-url) {
        unless .is-success {
            say "Failed to fetch $commit-url via API: "
                ~ .status-line ~ .content;
            return;
        }

        my $patch = try {
            CATCH { say "Failed to decode API JSON: $!"; return; }
            from-json(.content)<files>[0]<patch>;
        };

        "$compare-url-part/compare/" ~ $patch.lines[1,2]».substr(1).join('...');
    }
}
