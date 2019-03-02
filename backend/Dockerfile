# Use rust image
FROM rust:1.33

# Set working directory of rust app
WORKDIR /usr/src/webdev

# Copy current directory, into docker
COPY . /usr/src/webdev

# Build the app
RUN cargo build --release

# Make port 8080 available
EXPOSE 8000:8000

# Run the app
CMD ["target/release/web_dev"]
