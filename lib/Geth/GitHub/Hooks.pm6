unit class Geth::GitHub::Hooks;

use HTTP::Server::Tiny;
use JSON::Tiny;

has $.debug = False;
has $.port = 8888;
has $.host = '0.0.0.0';
has $!supplier = Supplier.new;
has $.supply   = $!supplier.Supply;

submethod TWEAK {
    HTTP::Server::Tiny.new(:$!host , :$!port).run: -> $env {
        my $data = $env<p6sgi.input>.slurp-rest;
        say "Got $data" if $!debug;
        my $decoded-data = (try from-json $data)
            // %( error => "Failed to decode data: $!" );
        $!supplier.emit: make-event $decoded-data;
        dd "sent event";
        dd make-event $decoded-data;
        dd "done";
        200, ['Content-Type' => 'text/plain'], [ 'OK' ]
    };
}

class Event {
    has $.repo is required;
}

sub make-event ($e) {
    Event.new: :repo($e<repository><full_name>);
}
