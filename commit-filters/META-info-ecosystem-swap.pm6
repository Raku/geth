sub swap-meta-info-to-meta-json ($e) {
    return unless $e ~~ Geth::GitHub::Hooks::Event::Push
        and $e.commits == 1;

    my $c = $e.commits.head;
    return unless $c.author eq 'Zoffix Znet'
        and $c.title ~~ /
            ^ '[automated commit] '
            'META.info→META6.json (' $<num>=\d+
        /;
    
    return "Swapped META.info → META6.json in $<num> dists in "
        ~ "https://github.com/$e.repo-full()/commit/$c.sha.substr(0, 10)"
}
