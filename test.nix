{ pkgs ? import <nixpkgs> {} }:

{
  shellcheck = pkgs.callPackage (
    { runCommand
    , shellcheck
    }:
    runCommand "cat-shellcheck" {
      nativeBuildInputs = [
        shellcheck
      ];
      script = ./cat.sh;
    } ''
      (
      PS4=" $ "
      set -x
      shellcheck --shell=busybox "$script"
      shellcheck --shell=bash "$script"
      shellcheck --shell=sh "$script"
      ) | tee $out 2>&1
    ''
  ) {};
  unit-tests = pkgs.callPackage (
    { runCommand
    , busybox-sandbox-shell
    , xxd
    }:

    runCommand "busybox-shell-cat-test" {
      nativeBuildInputs = [
        xxd
      ];
      shell = "${busybox-sandbox-shell}/bin/sh";
      script = ./cat.sh;
    } ''
      mkdir -p "$out"
      (
      set -o pipefail
      PS4=" $ "
      exec 2>&1

      declare -A test_names
      declare -a tests

      _cat() {
        # Ensures no leaking of anything
        env -i "$shell" "$script" "$@"
      }

      _indent() {
        sed -e 's/^/    /'
      }

      _register_test() {
        name="$1"; shift
        title="$1"; shift
        tests+=( "$name" )
        test_names+=( ["$name"]="$title" )
      }

      _compare() {
        local orig
        orig="$1"; shift
        sha256sum "$orig" "$@"
        for f in "$@"; do
          diff --report-identical-files "$orig" "$f"
        done
      }

      test-simple() {
        echo "hello, world!" > first.txt
        < first.txt _cat > first.txt.a
        _cat first.txt > first.txt.b
        _compare first.txt first.txt.{a,b}
      }
      _register_test "test-simple" "Simple test"

      # This is a bit on the heavy side, but this helps verify that every byte (individually) is
      # shuffled about correctly on stdout, *and* that longer sequences of bytes don't somehow break it.
      test-char-hex() {
        local hex="$1"; shift
        local src="hex-$hex.dat"
        printf "0x%s '\x$hex'########" "$hex" > "$src"
        < "$src" _cat > "$src".a
        _cat "$src" > "$src".b
        xxd "$src"
        xxd "$src.a"
        xxd "$src.b"
        _compare "$src" "$src".{a,b}

        src="hex-twice-$hex.dat"
        printf "0x%s '\x$hex\x$hex'#######" "$hex" > "$src"
        < "$src" _cat > "$src".a
        _cat "$src" > "$src".b
        xxd "$src"
        xxd "$src.a"
        xxd "$src.b"
        _compare "$src" "$src".{a,b}

        src="hex-thrice-$hex.dat"
        printf "0x%s '\x$hex\x$hex\x$hex'######" "$hex" > "$src"
        < "$src" _cat > "$src".a
        _cat "$src" > "$src".b
        xxd "$src"
        xxd "$src.a"
        xxd "$src.b"
        _compare "$src" "$src".{a,b}

        src="hex-fours-$hex.dat"
        printf "0x%s '\x$hex\x$hex\x$hex\x$hex'#####" "$hex" > "$src"
        < "$src" _cat > "$src".a
        _cat "$src" > "$src".b
        xxd "$src"
        xxd "$src.a"
        xxd "$src.b"
        _compare "$src" "$src".{a,b}
      }
      # This dynamically registers the previous test
      for i in {0..255}; do
        hex="$(printf "%02x" "$i")"
        eval "
          test-char-$hex() {
            test-char-hex "$hex"
          }
        "
        _register_test "test-char-$hex" "Testing for char sequence '0x$hex'"
      done

      declare -a successes
      declare -a failures
      failure_count=0

      for t in "''${tests[@]}"; do
        printf "\n:: %s (%s)\n" "''${test_names["$t"]}" "$t"
        if (
          #set -x
          "$t"
        ); then
          printf "\n... %s was successful\n" "$t"
          successes+=( "$t" )
        else
          printf "\n... %s failed\n" "$t"
          failures+=( "$t" )
          (( failure_count++ ))
        fi || :
      done

      if (( failure_count > 0 )); then
        printf "\nFAILURE: %d tests failed.\n" "$failure_count"
        printf " - %s\n" "''${failures[@]}"
        printf "\n"
        false
      else
        printf "\n\n"
        printf "All tests ran successfully to the end."
      fi

      ) | tee "$out/test-results.log"
    ''
  ) {};
}
