DESTPATH=/home/mitch/html/homepage

all:
	rm -f out/*.html
	site.pl
	cp out/*.html $(DESTPATH)
	shuttleupdate
