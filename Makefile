DESTPATH=/home/mitch/html/homepage

all:
	rm -f out/*.html
	webCOMA.pl
	cp out/*.html $(DESTPATH)
	shuttleupdate
