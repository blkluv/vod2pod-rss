FROM rust:1.68 as builder

RUN cd /tmp && USER=root cargo new --bin vod2pod
WORKDIR /tmp/vod2pod
COPY Cargo.toml ./
RUN sed '/\[dev-dependencies\]/,/^$/d' Cargo.toml > Cargo.toml.tmp && mv Cargo.toml.tmp Cargo.toml

RUN cargo fetch
RUN cargo install cargo-build-deps

RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg clang libavformat-dev libavfilter-dev libavcodec-dev libavdevice-dev libavutil-dev libpostproc-dev libswresample-dev libswscale-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN cargo build-deps --release
COPY src /tmp/vod2pod/src

#trick to use github action cache, check the action folder for more info
COPY set_version.sh version.txt* ./
RUN sh set_version.sh

RUN cargo build --release

#----------
FROM debian:bullseye-slim

#install ffmpeg and yt-dlp
ARG TARGETPLATFORM
RUN apt-get update && \
    apt-get install -y --no-install-recommends xz-utils python3 curl ca-certificates && \
    case ${TARGETPLATFORM} in \
      linux/arm64) \
        curl -o ffmpeg-release-static.tar.xz -O https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz \
        ;; \
      linux/arm/v7) \
        curl -o ffmpeg-release-static.tar.xz -O https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-armhf-static.tar.xz \
        ;; \
      linux/amd64) \
        curl -o ffmpeg-release-static.tar.xz -O https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz \
        ;; \
      linux/386) \
        curl -o ffmpeg-release-static.tar.xz -O https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-i686-static.tar.xz \
        ;; \
      *) \
        echo "Unsupported architecture: ${TARGETPLATFORM}" >&2 && exit 1 \
        ;; \
    esac && \
    ls ffmpeg-release-static.tar.xz -lah && \
    tar xf ffmpeg-release-static.tar.xz && \
    cd ffmpeg-*-static && \
    mv ffmpeg /usr/local/bin/ && \
    cd .. && \
    rm -rf ffmpeg-release-static.tar.xz ffmpeg-*-static && \
    curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp && \
    chmod a+rx /usr/local/bin/yt-dlp && \
    apt-get -y purge curl xz-utils && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/vod2pod/target/release/app /usr/local/bin/vod2pod

COPY templates/ ./templates/

EXPOSE 8080

CMD ["vod2pod"]
