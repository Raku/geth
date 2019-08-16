# Geth

An IRC bot written in the Perl 6 programming language, to announce GitHub
commits to various channels.

## Webhook Endpoint

The webhook endpoint is `https://geth.svc.tyil.net/?chan=#perl6` where `#perl6`
is the channel to report the commits to. Multiple channels can be specified,
separated with commas.

## Commit Filters

To add commit filters stick a `.pm6` file into `commit-filters/`
and make it contain 1 sub that takes 1 arg with a name.

1. Return undefined value to signal that filter did not match;
2. Return a `False` value to stop further processing of the event and do not
   send any response to IRC;
3. Return a string to send it to IRC.
