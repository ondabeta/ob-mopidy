FROM debian:buster-slim

RUN set -ex \
    # Official Mopidy install for Debian/Ubuntu along with some extensions
    # (see https://docs.mopidy.com/en/latest/installation/debian/ )
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        dumb-init \
        gnupg \
        gstreamer1.0-alsa \
        gstreamer1.0-plugins-bad \
        python3-crypto \
        python3-distutils \
 && curl -L https://bootstrap.pypa.io/get-pip.py | python3 - \
 && pip install pipenv \
    # Clean-up
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

RUN set -ex \
 && curl -L https://apt.mopidy.com/mopidy.gpg | apt-key add - \
 && mkdir -p /usr/local/share/keyrings \
 && curl https://apt.mopidy.com/mopidy.gpg -o /usr/local/share/keyrings/mopidy-archive-keyring.gpg \
 && curl -L https://apt.mopidy.com/mopidy.list -o /etc/apt/sources.list.d/mopidy.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mopidy \
        mopidy-soundcloud \
        mopidy-local \
        mopidy-mpd \
        git \
    # Clean-up
 && apt-get purge --auto-remove -y \
        gcc \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

COPY Pipfile /


RUN set -ex \
 && pipenv lock 

RUN set -ex \ 
 && pipenv install --system --deploy

RUN set -ex \ 
 && pip install git+https://github.com/BlackLight/python-tidal.git@pagination-support#egg=tidalapi 

RUN set -ex \
 && mkdir -p /var/lib/mopidy/.config \
 && ln -s /config /var/lib/mopidy/.config/mopidy

# Start helper script.
COPY entrypoint.sh /entrypoint.sh

COPY mopidy.conf /config/mopidy.conf.base

# Copy the pulse-client configuratrion.
COPY pulse-client.conf /etc/pulse/client.conf

RUN groupadd -g 1000 pulse
# Allows any user to run mopidy, but runs by default as a randomly generated UID/GID.
ENV HOME=/var/lib/mopidy
RUN set -ex \
 && usermod -g pulse -G audio,pulse,sudo mopidy \
 && chown mopidy:pulse -R $HOME /entrypoint.sh /config \
 && chmod go+rwx -R $HOME /entrypoint.sh

COPY --from=hairyhenderson/gomplate:v3.8.0-slim /gomplate /bin/gomplate

# Runs as mopidy user by default.
USER mopidy

# Basic check,
# RUN /usr/bin/dumb-init /entrypoint.sh /usr/bin/mopidy --version

VOLUME ["/var/lib/mopidy/local", "/var/lib/mopidy/media"]

EXPOSE 6680

ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint.sh"]
CMD ["/usr/bin/mopidy"]

HEALTHCHECK --interval=5s --timeout=2s --retries=20 \
    CMD curl --connect-timeout 5 --silent --show-error --fail http://localhost:6680/ || exit 1
