DESTPATH=/home/mitch/html/homepage

all:	generate zip dist

fast:	generate dist-fast

generate:
	rm -f out/*.html
	LANG=C ./webCOMA.pl
#	time tidy -m -e -q -wrap 72 -f tidyerrlog out/*.html || echo "TIDY ERRORS!"

# until GDPR is available in English: remove english files
	(cd out; for EN in *en.html; do DE=$${EN%%en.html}de.html ; cp $$DE $$EN ; done)

	install -m 644 out/*.html $(DESTPATH)
	install -m 644 out/*.xml $(DESTPATH)
	install -m 644 in/*.css $(DESTPATH)

update-rss:
	-GET 'http://www.cgarbs.de/blog/feeds/index.rss2' > rsscache/tmp && mv rsscache/tmp rsscache/blog.rss
	-GET 'http://10.117.97.129/twitter/userrss.php?xrt=1&xrp=1&user=mmitch_github' > rsscache/tmp && mv rsscache/tmp rsscache/github.rss
	-GET 'http://10.117.97.129/twitter/userrss.php?xrt=1&xrp=1&user=master_mitch' > rsscache/tmp && mv rsscache/tmp rsscache/mitch.rss

generate-startpage: update-rss
	LANG=C ./webCOMA.pl index
	install -m 644 out/*.html $(DESTPATH)
	install -m 644 out/*.html /home/mitch/pub/www
	install -m 644 in/*.css /home/mitch/pub/www

dist:
	shuttleupdate

dist-fast:
	shuttleupdate -dontask

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
