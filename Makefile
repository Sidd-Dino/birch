PREFIX ?= /usr
MANDIR ?= $(PREFIX)/share/man
DOCDIR ?= $(PREFIX)/share/doc/birch

all:
	@echo Run \'make install\' to install birch.

install:
	@mkdir -p $(DESTDIR)$(PREFIX)/bin
	@mkdir -p $(DESTDIR)$(MANDIR)/man1
	@mkdir -p $(DESTDIR)$(DOCDIR)
	@cp -p birch $(DESTDIR)$(PREFIX)/bin/birch
	@cp -p birch.1 $(DESTDIR)$(MANDIR)/man1
	@cp -p README.md $(DESTDIR)$(DOCDIR)
	@chmod 755 $(DESTDIR)$(PREFIX)/bin/birch

uninstall:
	@rm -rf $(DESTDIR)$(PREFIX)/bin/birch
	@rm -rf $(DESTDIR)$(MANDIR)/man1/birch.1
	@rm -rf $(DESTDIR)$(DOCDIR)