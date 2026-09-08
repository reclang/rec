# make             build reclang
# make check       run test/run.sh
# make install     install binary and man page under PREFIX
#
# DFLAGS is dmd/ldc2 syntax, gdc is not tested

DC      ?= ldc2
DFLAGS  ?= -O -release
PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin
MANDIR  ?= $(PREFIX)/share/man
SRC     := $(wildcard src/*.d)

all: reclang

reclang: $(SRC) VERSION
	$(DC) $(DFLAGS) -J. -of=$@ $(SRC)

check: reclang
	sh test/run.sh ./reclang

install: reclang
	mkdir -p $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/man1
	install -m 755 reclang $(DESTDIR)$(BINDIR)/reclang
	install -m 644 doc/reclang.1 $(DESTDIR)$(MANDIR)/man1/reclang.1

clean:
	rm -f reclang *.o

.PHONY: all check install clean
