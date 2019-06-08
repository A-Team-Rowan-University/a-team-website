FROM abiosoft/caddy

RUN mkdir /elm-bin
WORKDIR /elm-bin

RUN wget https://github.com/elm/compiler/releases/download/0.19.0/binary-for-linux-64-bit.gz
RUN gunzip binary-for-linux-64-bit.gz
RUN mv binary-for-linux-64-bit /bin/elm
RUN chmod u+x /bin/elm

RUN mkdir /elm-src

WORKDIR /elm-src

COPY ./elm-src/src src
COPY ./elm-src/static static
COPY ./elm-src/elm.json .

RUN ls -l
RUN elm make src/Main.elm --output=static/main.js

RUN cp -r static /srv/static

COPY Caddyfile /etc/Caddyfile

