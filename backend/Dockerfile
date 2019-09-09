# select build image
FROM rust:1.34 as build

# install system dependencies
RUN apt-get -y update
RUN apt-get -y install libfontconfig1-dev libgraphite2-dev libharfbuzz-dev libicu-dev libssl-dev zlib1g-dev

# create a new empty shell project
RUN USER=root cargo new --bin webdev_server
WORKDIR /webdev_server

# copy over your manifests
COPY ./Cargo.toml ./Cargo.toml

# crate an empty project for webdev_lib so its dependencies can be compiled seperatly
RUN USER=root cargo new --lib webdev_lib

# Copy over the manifest
COPY ./webdev_lib/Cargo.toml ./webdev_lib/Cargo.toml

# Build dependencies for webdev_server and webdev_lib
RUN cargo build --release
RUN rm webdev_lib/src/*.rs

# copy in sources for webdev_lib
COPY ./webdev_lib/src ./webdev_lib/src
COPY ./webdev_lib/migrations ./webdev_lib/migrations

# build webdev_lib
RUN rm ./target/release/deps/webdev_lib*
RUN rm ./target/release/deps/libwebdev_lib*
RUN cargo build --release

# copy your source tree
COPY ./src ./src

# build for release
RUN rm ./target/release/deps/webdev_server*
RUN cargo build --release

# our final base
FROM rust:1.34

# copy the build artifact from the build stage
COPY --from=build /webdev_server/target/release/webdev_server /

# set the startup command to run your binary
CMD ["/webdev_server"]
