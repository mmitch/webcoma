DESTPATH=/home/mitch/html/homepage

all:	generate zip dist

generate:
	rm -f out/*.html
	LANG=C ./webCOMA.pl
#	time tidy -m -e -q -wrap 72 -f tidyerrlog out/*.html || echo "TIDY ERRORS!"
	install -m 644 out/*.html $(DESTPATH)
	install -m 644 out/*.xml $(DESTPATH)
	install -m 644 in/*.css $(DESTPATH)

dist:
	shuttleupdate

zip:
	rm -rf $(DESTPATH)/source
	mkdir -p $(DESTPATH)/source
	cp in/*.page $(DESTPATH)/source
	(cd $(DESTPATH)/source; mmv "*.page" "#1.txt")

	mkdir -p webCOMA/in webCOMA/out
	install -m 755 webCOMA.pl webCOMA
	chmod 755 webCOMA/webCOMA.pl
	install -m 644 in/*.page webCOMA/in
	install -m 644 in/*.css webCOMA/in
	install -m 644 in/TEMPLATE webCOMA/in
	tar -czvf webCOMA.tar.gz webCOMA
	rm -rf webCOMA

	install webCOMA.tar.gz $(DESTPATH)/stuff
