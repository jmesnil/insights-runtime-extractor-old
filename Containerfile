FROM fedora:latest AS rust-builder
ARG TARGETARCH

RUN echo BUILDPLATFORM=$BUILDPLATFORM TARGETPLATFORM=$TARGETPLATFORM BUILDARCH=$BUILDARCH TARGETARCH=$TARGETARCH
RUN dnf update -y && dnf -y install \
    gcc make wget

# Download crictl in the builder image (to copy it later in the extractor image)
ENV CRICTL_VERSION="v1.30.0"
ENV CRICTL_CHECKSUM_SHA256_arm64="9e53d46c8f07c4bee1396f4627d3a65f0b81ca1d80e34852757887f5c8485df7"
ENV CRICTL_CHECKSUM_SHA256_amd64="417312332d14184f03a85d163c57f48d99483f903b20b422d3089e8c09975a77"

RUN wget https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${TARGETARCH}.tar.gz -P / && \
    sha256sum /crictl-${CRICTL_VERSION}-linux-${TARGETARCH}.tar.gz | grep $CRICTL_CHECKSUM_SHA256_${TARGETARCH} && \
    tar zxvf /crictl-${CRICTL_VERSION}-linux-${TARGETARCH}.tar.gz  && \
    rm -f /crictl-$CRICTL_VERSION-linux-${TARGETARCH}.tar.gz

RUN bash -c 'if [ "$TARGETARCH" == "arm64" ]; then dnf -y install gcc-aarch64-linux-gnu ; else dnf -y install gcc-x86_64-linux-gnu; fi'
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN bash -c 'if [ "$TARGETARCH" == "arm64" ]; then rustup target install aarch64-unknown-linux-musl ; else rustup target install x86_64-unknown-linux-musl; fi'

WORKDIR /workspace/extractor
COPY extractor .
RUN make TARGETARCH=${TARGETARCH}

FROM registry.ci.openshift.org/ocp/builder:rhel-9-golang-1.22-openshift-4.18 AS go-builder

WORKDIR /workspace/fingerprints
COPY fingerprints .
ARG GO_LDFLAGS=""
RUN CGO_ENABLED=0 GOOS=linux GO111MODULE=on make build

WORKDIR /workspace/exporter
COPY exporter .
ARG GO_LDFLAGS=""
RUN CGO_ENABLED=0 GOOS=linux GO111MODULE=on make build

# Target image for the extractor component
FROM registry.ci.openshift.org/ocp/4.18:base-rhel9 as extractor

COPY --from=rust-builder /crictl /crictl
COPY --from=rust-builder /workspace/extractor/config/ /
COPY --from=rust-builder /workspace/extractor/target/*/release/extractor_server /extractor_server
COPY --from=rust-builder /workspace/extractor/target/*/release/coordinator /coordinator
# Copy fingerprints written in Go
COPY --from=go-builder --chmod=755 /workspace/fingerprints/bin/fpr_* /
ENTRYPOINT [ "/extractor_server" ]

# Target image for the exporter component

FROM registry.ci.openshift.org/ocp/4.18:base-rhel9 as exporter

COPY --from=go-builder /workspace/exporter/bin/exporter /
ENTRYPOINT [ "/exporter" ]