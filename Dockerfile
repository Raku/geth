FROM tyil/perl6:debian-dev-latest AS install

WORKDIR /app

RUN apt update && apt install -y libssl-dev

COPY META6.json META6.json

RUN zef install --deps-only .

FROM tyil/perl6:debian-latest

WORKDIR /app

RUN apt update && apt install -y libssl-dev

COPY --from=install /app /app
COPY --from=install /usr/local /usr/local
COPY bin bin
COPY lib lib
COPY commit-filters commit-filters

CMD [ "perl6", "bin/geth.p6" ]
