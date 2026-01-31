# syntax=docker/dockerfile:1
FROM docker.io/library/node:24-trixie AS runtime

ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

COPY --from=mikefarah/yq /usr/bin/yq /usr/local/bin/
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

RUN <<EOT
    set -o errexit
    apt-get update
    apt-get install --yes --no-install-recommends \
        bash-completion \
        bc \
        build-essential \
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
ARG APP_USER="openclaw"

RUN \
    groupadd \
      --gid "${APP_GID}" "${APP_USER}" && \
    useradd \
      --gid "${APP_GID}" \
      --uid "${APP_UID}" \
      --comment "" \
      --shell /bin/bash \
      --create-home \
      "${APP_USER}"

RUN \
    mkdir --parents /etc/sudoers.d/ && \
    echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${APP_USER}" && \
    chmod 0440 "/etc/sudoers.d/${APP_USER}"

USER "${APP_USER}"
WORKDIR "/home/${APP_USER}"

ENV HOME="/home/${APP_USER}"
ENV NPM_CONFIG_PREFIX="${HOME}/.npm-global"
ENV PATH="${HOME}/.local/bin:${HOME}/.npm-global/bin:${PATH}"
ENV EDITOR="vim"
ENV TERM="xterm-256color"
ENV NODE_ENV="production"
ENV HOMEBREW_NO_ANALYTICS="1"

RUN mkdir --parents "${HOME}/.local/share"
RUN mkdir --parents "${HOME}/.local/bin"
RUN echo 'export PS1="\e[34m\u@\h\e[35m \w\e[0m\n$ "' >> "${HOME}/.bashrc"

RUN npm install --global @sourcemeta/jsonschema
RUN npm install --global openclaw@latest

RUN <<EOT
    set -o errexit -o pipefail
    export NONINTERACTIVE=1
    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" | \
    bash
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"' >> ~/.bashrc
EOT

ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

RUN <<EOT
    {
        echo ":set number"
        echo ":set et"
        echo ":set sw=2 ts=2 sts=2"
    } > "${HOME}/.vimrc"
EOT

ENTRYPOINT ["openclaw"]
