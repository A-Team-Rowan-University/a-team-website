# select build image
FROM rust:1.33 as build

# create a new empty shell project
RUN USER=root cargo new --bin web_dev
WORKDIR /web_dev

# copy over your manifests
COPY ./Cargo.lock ./Cargo.lock
COPY ./Cargo.toml ./Cargo.toml

RUN mkdir src/bin
RUN cp src/main.rs src/bin/csv_user_import.rs

# this build step will cache your dependencies
RUN cargo build --release
RUN rm src/*.rs

# copy your source tree
COPY ./migrations ./migrations
COPY ./src ./src

# build for release
RUN rm ./target/release/deps/web_dev*
RUN cargo build --release

# our final base
FROM rust:1.33

# copy the build artifact from the build stage
COPY --from=build /web_dev/target/release/web_dev /

# set the startup command to run your binary
CMD ["/web_dev"]
