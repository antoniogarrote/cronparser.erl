Cronparser.erl
==============

A cronparser library inspired by the [parse-cron](https://github.com/siebertm/parse-cron) Ruby gem.
Cronparser.erl includes functionality to parse a crontab entry and compute the next occurrence of that entry,
provided a given date time.

The full library is packaged as an OTP application and can be build, tested and added as a dependency using Rebar.

## Functionality

To parse a crontab line, use the *time_specs* function:

```erlang
Spec = cronparser:time_specs("*/15 * * * *") .
```

To compute the next occurrence of an spec, use the *next* function:

```erlang
Now = calendar:local_time().
Next = cronparser:next(Now,Spec).
```

## Building

To test and build the library, use Rebar:

```shell
rebar get-deps compile eunit
```

The library has a dependency on [edate](https://github.com/dweldon/edate) that will be automatically
resolved by Rebar.

## Copyright

Released under the Apache License by Antonio Garrote (antoniogarrote@gmail.com), 2014.
