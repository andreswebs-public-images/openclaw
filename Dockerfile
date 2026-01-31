# syntax=docker/dockerfile:1
FROM docker.io/library/node:24-trixie AS build

ARG OPENCLAW_GIT_REPO="https://github.com/openclaw/openclaw.git"
ARG OPENCLAW_VERSION="v2026.1.30"

WORKDIR /src

ENV NPM_CONFIG_PREFIX="/root/.npm-global"
ENV PATH="/root/.npm-global/.npm-global/bin:${PATH}"

RUN <<EOT
    set -o errexit
    apt-get update
    apt-get install --yes --no-install-recommends \
        ca-certificates \
        git
    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOT

RUN npm install --global corepack

RUN <<EOT
    set -o errexit -o pipefail
    git clone "${OPENCLAW_GIT_REPO}"
    cd openclaw
    git checkout "${OPENCLAW_VERSION}"
    corepack enable
    pnpm install --frozen-lockfile
    pnpm build
    pnpm ui:install
    pnpm ui:build
    mkdir /build
    mv node_modules dist /build
    cd .. || exit 1
    rm -rf /src/openclaw
EOT

WORKDIR /build

FROM docker.io/library/node:24-trixie AS runtime

ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

COPY --from=mikefarah/yq /usr/bin/yq /usr/local/bin/
COPY --from=denoland/deno:bin-2.6.4 /deno /usr/local/bin/
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
COPY --from=oven/bun:1 /usr/local/bin/bun /usr/local/bin/bunx /usr/local/bin/

RUN <<EOT
    set -o errexit
    apt-get update
    apt-get install --yes --no-install-recommends \
        bash-completion \
        bc \
        bzip2 \
        ca-certificates \
        curl \
        direnv \
        dnsutils \
        file \
        gh \
        git \
        gnupg \
        htop \
        jq \
        less \
        lsof \
        man-db \
        netcat-openbsd \
        openssh-client \
        procps \
        psmisc \
        ripgrep \
        rsync \
        socat \
        sudo \
        tree \
        tmux \
        unzip \
        vim \
        zip
    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOT

ARG APP_UID="2000"
ARG APP_GID="2000"

RUN \
    usermod --uid "${APP_UID}" node && \
    groupmod --gid "${APP_GID}" node && \
    chown --recursive node:node /home/node

RUN mkdir /app

COPY --from=build /build/node_modules /app/node_modules
COPY --from=build /build/dist/ /app/

RUN chown --recursive node:node /app

USER node
WORKDIR /home/node

ENV HOME="/home/node"
ENV NPM_CONFIG_PREFIX="${HOME}/.npm-global"
ENV PATH="${HOME}/.local/bin:${HOME}/.npm-global/bin:${HOME}/.bun/bin:${PATH}"
ENV EDITOR="vim"
ENV NODE_ENV="production"

RUN mkdir --parents "${HOME}/.local/share"
RUN mkdir --parents "${HOME}/.local/bin"
RUN echo 'export PS1="\e[34m\u@\h\e[35m \w\e[0m\n$ "' >> "${HOME}/.bashrc"

RUN npm install --global @sourcemeta/jsonschema

RUN <<EOT
    {
        echo ":set number"
        echo ":set et"
        echo ":set sw=2 ts=2 sts=2"
    } > "${HOME}/.vimrc"
EOT

ENTRYPOINT ["node", "/app/index.js"]
