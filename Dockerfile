FROM swift:5.1.1 as builder

RUN apt-get -qq update && apt-get -q -y install \
  libssl-dev zlib1g-dev tzdata \
  && rm -r /var/lib/apt/lists/*

# Set the working directory to /app
WORKDIR /app

# Copy everything from the current project directory to the image
COPY . .

# Create a temporary "build" directory and copy the Swift static libraries into it
RUN mkdir -p /build/lib && cp -R /usr/lib/swift/linux/*.so /build/lib

# Create a release build of the app and copy it into the build directory
RUN swift build -c release && mv `swift build -c release --show-bin-path` /build/bin

#
# Second stage - production image
#

# Start with the official Ubuntu image
FROM ubuntu:latest

RUN apt-get -qq update && apt-get install -y \
  libicu60 libxml2 libbsd0 libcurl4 libatomic1 libz-dev \
  tzdata \
  && rm -r /var/lib/apt/lists/*

# Set the working directory to /app
WORKDIR /app

# Copy the app binary into the production image
COPY --from=builder /build/bin/Run .

# Copy the Swift static libraries into the production image
COPY --from=builder /build/lib/* /usr/lib/

# Uncomment the next line if you need to load resources from the `Public` directory
COPY --from=builder /app/Public ./Public

# Uncomment the next line if you are using Leaf
COPY --from=builder /app/Resources ./Resources

EXPOSE 8080
ENTRYPOINT ./bin/release/Run serve -e prod -b 0.0.0.0