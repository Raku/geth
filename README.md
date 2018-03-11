# Geth
GitHub Push Updates to IRC Bot

## Location

The bot lives on hack. The code is located in C</home/geth/geth> and service
can be restarted with:

    sudo service geth restart

The webhook endpoint is `http://hack.p6c.org:8888/?chan=#perl6` where `#perl6`
is the channel to report the commits to. Multiple channels can be specified,
separated with commas.

## Commit Filters

To add commit filters stick a `.pm6` file into `commit-filters/`
and make it contain 1 sub that takes 1 arg with a name.

- Return undefined value to signal that filter did not match
- Return a false value to stop further processing of the
    event and do not send any response to IRC
- Return string to send to IRC to send it
