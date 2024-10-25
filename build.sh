#!/usr/bin/env sh

set -xe

cd libsql-c

./build.sh

rm -rf \
  ../lib/lib/aarch64-unknown-linux-gnu \
  ../lib/lib/x86_64-unknown-linux-gnu \
  ../lib/lib/universal2-apple-darwin \

mkdir -p \
  ../lib/lib/aarch64-unknown-linux-gnu \
  ../lib/lib/x86_64-unknown-linux-gnu \
  ../lib/lib/universal2-apple-darwin \

cp ./target/x86_64-unknown-linux-gnu/release/liblibsql.so ../lib/lib/x86_64-unknown-linux-gnu/
cp ./target/aarch64-unknown-linux-gnu/release/liblibsql.so ../lib/lib/aarch64-unknown-linux-gnu/
cp ./target/universal2-apple-darwin/release/liblibsql.dylib ../lib/lib/universal2-apple-darwin/
