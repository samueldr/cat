`cat.sh`
========

A good enough approximation of `cat` for pure `busybox` `sh`.

This targets the busybox configuration used in `busybox-sandbox-shell` from *Nixpkgs*.

In turn, this a somewhat minimal configuration of busybox sh, but not the most minimal there could be.

Improvements to make it strictly POSIX-sh compatible would be nice, but probably not worth the pain.


* * *

Non-portable behaviour
----------------------

### `read -n`

```
In cat.sh line 15:
        while read -n 1 -d "" -r "char"; do
                   ^-- SC3045 (warning): In POSIX sh, read -n is undefined.
```

### `printf`

While `printf` [is POSIX](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/printf.html), 
the busybox shell *can* be configured with `ENABLE_ASH_PRINTF=n`.

This means that the explicit goals of supporting a dependency-free `sh` environment may or may not work for busybox sh

Additionally, it is possible that `printf` may not handle `%c` correctly, or that the parameter provided to `printf` will not be forwarder appropriately.

More testing with weirder POSIX-"compliant" shells may be needed.


* * *

FAQ
---

### *But why?*

As an exercise in futility, when needing to shuffle bytes around in a dependency-free `derivation` in Nix (without NixOS).

With this script, it's possible to produce files as a proper *derivation* from Nix expressions.

It's mostly entirely unneeded to be "this well done" for many use-cases, but I saw a challenge, and sniped myself into it.
