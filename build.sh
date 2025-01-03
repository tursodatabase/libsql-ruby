#!/usr/bin/env sh

set -xe

cd libsql-c

./build.sh

rm -rf \
  ../lib/lib/aarch64-unknown-linux-gnu \
  ../lib/lib/x86_64-unknown-linux-gnu \
  ../lib/lib/aarch64-apple-darwin \
  ../lib/lib/x86_64-apple-darwin

mkdir -p \
  ../lib/lib/aarch64-unknown-linux-gnu \
  ../lib/lib/x86_64-unknown-linux-gnu \
  ../lib/lib/aarch64-apple-darwin \
  ../lib/lib/x86_64-apple-darwin

cp ./target/x86_64-unknown-linux-gnu/release/liblibsql.so ../lib/lib/x86_64-unknown-linux-gnu/
cp ./target/aarch64-unknown-linux-gnu/release/liblibsql.so ../lib/lib/aarch64-unknown-linux-gnu/
cp ./target/aarch64-apple-darwin/release/liblibsql.dylib ../lib/lib/aarch64-apple-darwin/
cp ./target/x86_64-apple-darwin/release/liblibsql.dylib ../lib/lib/x86_64-apple-darwin/

exit
