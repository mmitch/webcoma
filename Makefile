DESTPATH=/home/mitch/html/homepage

all:	generate zip dist

generate:
	rm -f out/*.html
	webCOMA.pl
	time tidy -m -e -q -wrap 72 -f tidyerrlog out/*.html || echo "TIDY ERRORS!"
	cp out/*.html $(DESTPATH)

dist:
	shuttleupdate

zip:
	rm -rf $(DESTPATH)/source
	mkdir -p $(DESTPATH)/source
	cp in/*.page $(DESTPATH)/source
	(cd $(DESTPATH)/source; mmv "*.page" "#1.txt")

	mkdir -p webCOMA/in webCOMA/out
	cp webCOMA.pl webCOMA
	chmod 755 webCOMA/webCOMA.pl
	cp in/*.page webCOMA/in
	cp in/TEMPLATE webCOMA/in
	tar -c webCOMA -zvf webCOMA.tar.gz
	rm -rf webCOMA

	cp webCOMA.tar.gz $(DESTPATH)/stuff
