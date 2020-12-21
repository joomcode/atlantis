# building atlantis binary
FROM circleci/golang:1.14 AS build
WORKDIR /src
USER root
ENV XC_ARCH=amd64 XC_OS=linux
COPY . .
RUN scripts/binary-release.sh

FROM vault:1.4.2 as vault

# The runatlantis/atlantis-base is created by docker-base/Dockerfile.
FROM runatlantis/atlantis-base:v3.5
LABEL authors="Anubhav Mishra, Luke Kysow"

# install terraform binaries
ENV DEFAULT_TERRAFORM_VERSION=0.13.4

# In the official Atlantis image we only have the latest of each Terraform version.
RUN AVAILABLE_TERRAFORM_VERSIONS="0.8.8 0.9.11 0.10.8 0.11.14 0.12.29 ${DEFAULT_TERRAFORM_VERSION}" && \
    for VERSION in ${AVAILABLE_TERRAFORM_VERSIONS}; do \
        curl -LOs https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_linux_amd64.zip && \
        curl -LOs https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_SHA256SUMS && \
        sed -n "/terraform_${VERSION}_linux_amd64.zip/p" terraform_${VERSION}_SHA256SUMS | sha256sum -c && \
        mkdir -p /usr/local/bin/tf/versions/${VERSION} && \
        unzip terraform_${VERSION}_linux_amd64.zip -d /usr/local/bin/tf/versions/${VERSION} && \
        ln -s /usr/local/bin/tf/versions/${VERSION}/terraform /usr/local/bin/terraform${VERSION} && \
        rm terraform_${VERSION}_linux_amd64.zip && \
        rm terraform_${VERSION}_SHA256SUMS; \
    done && \
    ln -s /usr/local/bin/tf/versions/${DEFAULT_TERRAFORM_VERSION}/terraform /usr/local/bin/terraform

COPY --from=vault /bin/vault /bin/vault
RUN apk add --no-cache jq

# copy binary
COPY --from=build /src/output/linux_amd64 /usr/local/bin/atlantis

# copy docker entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]

# Store images 90 days after last pull
LABEL com.joom.retention.pullProtectDays=90
# Store images 90 days by default
LABEL com.joom.retention.maxDays=90
