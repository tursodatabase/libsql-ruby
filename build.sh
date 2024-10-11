#!/usr/bin/env sh

set -xe

cd libsql-c

cargo zigbuild --target universal2-apple-darwin --release
RUSTFLAGS="-C target-feature=-crt-static" cargo zigbuild --target aarch64-unknown-linux-musl --release
RUSTFLAGS="-C target-feature=-crt-static" cargo zigbuild --target x86_64-unknown-linux-musl --release

rm -rf \
  ../lib/lib/aarch64-unknown-linux-musl \
  ../lib/lib/x86_64-unknown-linux-musl \
  ../lib/lib/universal2-apple-darwin \

mkdir -p \
  ../lib/lib/aarch64-unknown-linux-musl \
  ../lib/lib/x86_64-unknown-linux-musl \
  ../lib/lib/universal2-apple-darwin \

cp ./target/x86_64-unknown-linux-musl/release/liblibsql.so ../lib/lib/x86_64-unknown-linux-musl/
cp ./target/aarch64-unknown-linux-musl/release/liblibsql.so ../lib/lib/aarch64-unknown-linux-musl/
cp ./target/universal2-apple-darwin/release/liblibsql.dylib ../lib/lib/universal2-apple-darwin/
