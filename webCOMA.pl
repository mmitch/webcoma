#!/usr/bin/perl -w
use strict;
use POSIX qw(strftime);
use Digest::MD5 qw(md5_hex);
use XML::RSS;
use Date::Parse;
use File::Basename;

##
## when commandline arguments are given, only those pages are generated
## otherwise all pages are generated

##
##  [ 2do ]
##
#
# - DESCRIPTION-Meta-Tag sinnvoll füllen
# - table summary="" lokalisieren (de/en)
# - mehrere DLINKs auf einer Zeile nicht möglich!
# - LINK-check findet keinen Fehler, wenn nur eine Sprachversion vorhanden ist
# - mit <link>s im Header arbeiten (http://www.w3.org/QA/Tips/use-links)
# - convertDate() ist eklig, außerdem kann man das mal cachen!
#
##
##

my $version = `git describe --tag --always --dirty`;
if (defined $version) {
    chomp $version;
    $version = " $version" if ($version);
} else {
    $version = '';
}
$version   = "webCOMA (git$version)";

my $favicon_ico = '/favicon.ico';  # may also be empty; MUST live in the root directory
my $favicon_svg = '/favicon.svg';  # may also be empty
my $author    = 'Christian Garbs';
my $authormail= 'mitch@cgarbs.de';
my $sitename  = 'Master Mitch';
my $baseurl = 'https://www.cgarbs.de';
## RSS definitions
my $rsstitle = 'Master Mitch on da netz';
my $rssdescription = "Mitch's homepage";
my $rssmax   = 15; # number or articles in file
my $rsspicurl = 'https://www.cgarbs.de/pics/favicon.feed.png'; # may also be empty
my $rsspicwidth = 22;
my $rsspicheight = 18;
my $flattr = ''; # 'https://flattr.com/thing/570000/Master-Mitch-on-da-netz'; # may also be empty
## 
my $amazon_link = 'https://www.amazon.de/exec/obidos/ASIN/%/mastemitchondane';
my @languages = ('de', 'en');
my $srcpath   = 'in';
my $destpath  = 'out';
my @startdocs = qw(index impressum datenschutz);
my $template  = "$srcpath/TEMPLATE";
my $sourcepath= 'source';
my %pagestructure;
my %date;
my $date_cmd  = 'date';
my $copy_cmd  = 'cp';
my $revisit   = '7 days';
my $host      = `hostname -s`;
chomp $host;
my %cache;
my %linkcache;
$linkcache{$_} = "" foreach @startdocs;
my %dlinkcache;
my %news;
my $dotfile = 'homepage.dot';
my $subtitlecount = 0;

# number of entries within a newsbox or rssbox
my $MAXBOXENTRIES = 3;

my %lastedited  = ( 'de' => 'letzte Änderung:', 'en' => 'last edited:' );
my %generatedby = ( 'de' => 'erstellt mit:', 'en' => 'generated by:' );
my %author      = ( 'de' => 'Autor:', 'en' => 'author:' );
my %navtitle    = ( 'de' => 'Navigation', 'en' => 'navigation' );
my %langtitle   = ( 'de' => 'Sprache', 'en' => 'language' );
my %language    = ( 'de' => 'Deutsch', 'en' => 'English' );
my %langsrc     = ( 'de' => 'Quellcode', 'en' => 'source' );
my %feedtitle   = ( 'de' => 'Feed', 'en' => 'feed' );

sub scanStructure($$$);
sub printPage($$);
sub initDates();
sub convertDate($$);
sub readTag($$$);
sub navBar($$$);
sub expand($$);
sub newsBox($$$);
sub includeSiteMap($$);
sub rssfeed($);
sub getLeft($$);
sub getRight($$);
sub rssBox($$$$);


my $pagefilter = undef;
{
    # parse commandline arguments to available pages
    if (@ARGV)
    {
	$pagefilter = {};
	$pagefilter->{$_}++ foreach @ARGV;
    }
    
    print "Initializing dates.\n";
    initDates();
    print "\n";

    open my $dot_fh, '>', $dotfile or die "can't open dotfile <$dotfile>: $!";
    print $dot_fh "digraph \"$sitename\" {\n";
    print $dot_fh "\tsize=\"7,8\";\n";
    print $dot_fh "\tratio=stretch;\n";
    print $dot_fh "\t$_ [shape=box];\n" foreach @startdocs;

    print "Scanning site structure:\n";
    scanStructure($dot_fh, $_, '') foreach @startdocs;
    foreach my $lang (@languages) {
	print "$lang: ";
	print (scalar @{$pagestructure{$lang}});
	print " pages found.\n";
    }

    print $dot_fh "}\n";
    print "\n";
    close $dot_fh or die "can't close dotfile <$dotfile>: $!";

    print "Scanning dlink integrity: ";
    foreach my $dlink (keys %dlinkcache) {
	if (! defined $linkcache{$dlink}) {
	    print "\n";
	    die "DLINK TO $dlink COULD NOT BE RESOLVED\n";
	}
    }
    print "OK\n\n";

    print "Looking for stale files: ";
    open my $files, '-|', "find \"$srcpath\" -maxdepth 1 -name *.page" or die "can't list directory: $!";
    while (my $file = <$files>) {
	chomp $file;
	$file =~ s/^$srcpath\///;
	$file =~ s/\.page$//;
	if (! defined $linkcache{$file}) {
	    print "\n";
	    die "STALE FILE $file.page DETECTED\n";
	}
    }
    close $files or die "can't close directory list: $!";
    print "OK\n\n";

    print "Generating pages:\n";
    foreach my $lang (@languages) {
	for (my $page = 0; $page < @{$pagestructure{$lang}}; $page++) {
	    if (defined $pagefilter)
	    {
		printPage($page,$lang) if (exists $pagefilter->{$pagestructure{$lang}[$page]});
	    }
	    else
	    {
		printPage($page,$lang);
	    }
	}
    }
    print "\n";

    print "Generating RSS feeds:\n";
    foreach my $lang (@languages) {
	    rssfeed($lang);
    }
    print "\n";

    print "Finished.\n\n";
    exit 0;
}


#


sub printDLINK($$$)
{
    my ($dot_fh, $doc, $parm) = @_;
    
    my $link = $parm;
    $link =~ s/\!.*$//;
    $dlinkcache{$link} = "";
    
    my ($from, $to) = ($doc, $parm);
    $from =~ s/-/_/g;
    $to =~ s/-/_/g;
    print $dot_fh "\t$from -> $to [style=dotted];\n";
}


#


sub getGitCommit($)
{
    my ($filename) = @_;

    # this needs to be done inside the directory, because we have two git repositories:
    # in/ - contains the website sources (this is what we want)
    # .   - is the webCOMA repository (contains no pages)
    my $dirname  = dirname($filename);
    my $basename = basename($filename);

    open my $git_log_pipe, '-|', "cd \"$dirname\" && git log -n 1 --pretty=format:%h -- \"$basename\""
	or die "can't get git commit for <$filename> :$1";

    my $git_commit = <$git_log_pipe>;

    close $git_log_pipe or die "can't get git commit for <$filename>: $!";

    chomp $git_commit;
    die "git commit for <$filename> is empty" unless $git_commit;

    return $git_commit;
}


#


sub scanStructure($$$)
{
    my ($dot_fh, $doc, $parent) = @_;

    my @files;

    my $filedate = `$date_cmd -r "$srcpath/$doc.page" +%Y%m%d\\ %H:%M:%S`;

    foreach my $lang (@languages) {

	my $valid = 0;

	my $filename = "$srcpath/$doc.page";
	$cache{"$parent$doc"}{'git-commit'} = getGitCommit($filename);

	open my $page_fh, '<', $filename or die "can't open <$filename>: $!";

	next unless grep { $lang eq $_ } readTag($page_fh, 'LANG', $lang);

	print "$lang:  $parent$doc\n";
	push @{$pagestructure{$lang}}, "$parent$doc";

	my @temp;
	@temp = readTag($page_fh, 'TYPE', $lang);
	
	$cache{"$parent$doc"}{$lang}{'TYPE'}  = $temp[0];
	$cache{"$parent$doc"}{$lang}{'VALID'} = $valid;
	
	{
	    my $olddate;
	    my $text = "";
	    foreach my $news (readTag($page_fh, 'NEWS', $lang)) {
		if ($news =~ /#DATE:(.*)/) {
		    if (defined $olddate) {

		        if ($text =~ /#DLINK:([^#]*)#/) {
			    printDLINK($dot_fh, $doc, $1);
			}
			
			## COPY BEGIN
			$text =~ s/\s+$//;
			$text =~ s/^\s+//;
		        $text = expand( $text, $lang );
			$news{"$parent$doc"}{$olddate}{$lang} = $text unless $text eq "";
			## COPY END
		    }
		    $text = "";
		    $olddate = $1;
		    $olddate =~ s/\s+$//;
		    $olddate =~ s/^\s+//;
		    die "EMPTY NEWS DATE\n" if ($olddate eq "");
		} else {
		    $text .= "$news ";
		}
	    }
	    ## COPY BEGIN
	    $text =~ s/\s+$//;
	    $text =~ s/^\s+//;
	    $text = expand( $text, $lang );
	    $news{"$parent$doc"}{$olddate}{$lang} = $text unless $text eq "";
	    ## COPY END
	}
	    
	@temp = readTag($page_fh, 'TITLE', $lang);
	$cache{"$parent$doc"}{$lang}{'TITLE'} = $temp[0];

	$cache{"$parent$doc"}{$lang}{'DATE'} = convertDate($lang, $filedate);
	
	@temp = readTag($page_fh, 'KEYWORDS', $lang);
	my @keywords = $temp[0];

	my $subtitles = [];

	if ($cache{"$parent$doc"}{$lang}{'TYPE'} eq "oldschool") {
	    @temp = readTag($page_fh, 'OLDSCHOOL', $lang);
	} else {
	    @temp = readTag($page_fh, 'PLAIN', $lang);
	}
	
	foreach my $line (@temp) {

	    if ($line =~ /#LINK:([^#]*)#/) {
		my $link = $1;
		$link =~ s/\!.*$//;
		if ((grep {$link eq $_} @files) == 0 ) {
		    push @files, $link;
		}
	    }

	    if ($line =~ /#DLINK:([^#]*)#/) {
		printDLINK($dot_fh, $doc, $1);
	    }

	    if ($line =~ /#SUBTITLE:(.*):([^:]*):/) {
		my ($show, $title) = ($1, $2);
		if ($title eq "") {
		    $title = $show;
		}
		die "SUBTITLE without title!" if ($title eq "");

		push @{$subtitles}, $title;

	    }

	}
	close $page_fh or die "can't close <$filename>: $!";

	$cache{"$parent$doc"}{$lang}{'SUBTITLES'} = $subtitles;

    }

    foreach my $file (@files) {
	next if $file =~ /^\s*$/;
	if (defined $linkcache{$file}) {
	    die "$srcpath/$file.page HAS MULTIPLE PARENTAGES\n";
	} else {
	    $linkcache{$file} = "";
	    if (! -e "$srcpath/$file.page") {
		system("$copy_cmd $template $srcpath/$file.page") == 0 or die "copy failed: $?";
		warn "CREATING NEW TEMPLATE FOR $srcpath/$file.page\n";
		my $taste=<STDIN>;
	    }

	    {
		my ($from, $to) = ($doc, $file);
		$from =~ s/-/_/g;
		$to =~ s/-/_/g;
		print $dot_fh "\t$from -> $to;\n";
	    }

	    scanStructure($dot_fh, $file, "$parent$doc!");
	}
    }
}


#


sub printPage($$)
{
    my $i       = shift;
    my $lang    = shift;
    my $page    = $pagestructure{$lang}[$i];

 
    my ($file, $path, @elements) = getStuff($i, $lang);
   
    my $date = $cache{$page}{$lang}{'DATE'};
    my $typ = $cache{$page}{$lang}{'TYPE'};
    my $title = $cache{$page}{$lang}{'TITLE'};
    my $gbAlign = 1;
    
    printf "%-34s %-10s %s\n", "$file.$lang.html", $typ, $title;

    open my $in, '<', "$srcpath/$file.page" or die "can't open <$srcpath/$file.page>: $!";
    open my $out, '>', "$destpath/$file.$lang.html" or die "can't open <$destpath/$file.$lang.html>: $!";
    
    my @news = readTag($in, "NEWS", $lang);
    
    my @temp = readTag($in, "KEYWORDS", $lang);
    my @keywords = $temp[0];

    $subtitlecount = 0;

    print $out <<~"EOF";
    <!DOCTYPE html>
    <html lang="$lang">
    <head>
      <meta charset="UTF-8">
      <meta name="author" content="$author ($authormail)">
      <meta name="generating_host" content="$host">
      <meta name="generation_date" content="$date{$lang}">
      <meta name="generator" content="$version">
      <meta name="keywords" content="@keywords">
      <meta name="language" content="$lang">
      <meta name="git_commit" content="$cache{$page}{'git-commit'}">
      <meta name="revisit-after" content="$revisit">
      <meta name="robots" content="index, follow, noai, noimageai">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>$sitename - $title</title>
      <link rel="stylesheet" type="text/css" href="style.css">
      <link rel="alternate" type="application/rss+xml" title="RSS-Feed" href="$baseurl/rssfeed.$lang.xml">
    EOF
    ;

    print $out "  <link rel=\"shortcut icon\" type=\"image/x-icon\" href=\"$favicon_ico\">\n"       if $favicon_ico;
    print $out "  <link rel=\"icon\" type=\"image/svg+xml\" href=\"$favicon_svg\" sizes=\"any\">\n" if $favicon_svg;
    print $out <<~"EOF";
    </head>
    <body lang="$lang">
    EOF
    ;

    # lohnt nicht, weil es den Inhalt nicht beschreibt:
    #  <meta name="description" content="$sitename - $title">
    
    print $out <<~"EOF";
    <header>
      <section>
        <h1>$sitename - $title</h1>
      </section>
      <nav>
        <a href="https://www.cgarbs.de/blog/" rel="me">blog</a>
        <a href="https://github.com/mmitch" rel="me">github</a>
      </nav>
      <div class="clearboth"></div>
    </header>
    EOF
    ;

    print $out "<article>\n";

    if (($typ eq "plain") or ($typ eq "news")) {

	my @lines = readTag($in, 'PLAIN', $lang);
	while (@lines) {
	    my $line = shift @lines;
	    $line = expand($line, $lang);
	    if ($line =~ /#SITEMAP#/) {
		includeSiteMap($out, $lang);
	    } elsif ($line =~ /\#NEWS\#/) {
		if ($typ eq "plain") {
		    newsBox($out, $page, $lang);
		} else {
		    newsBox($out, '', $lang);
		}
	    } elsif ($line =~ /#RSSBOX:([^:]+):([^:]+)#/) {
		rssBox($out, $1, $2, $lang);
	    } elsif ($line =~ /\#SUBTITLES(\/s)?\#/) { # TODO: wrap SUBTITLES in a <nav> element - remove <p> from individual pages
		my $count = 0;
		if (defined $1) {
		    my %sorthash;
		    map {$sorthash{$_} = $count++} @{$cache{"$page"}{$lang}{'SUBTITLES'}};
		    foreach my $key (sort {uc($a) cmp uc($b)} keys %sorthash) {
			print $out "[<a href=\"#$sorthash{$key}\">$key</a>] ";
		    }
		} else {
		    foreach my $subtitle (@{$cache{"$page"}{$lang}{'SUBTITLES'}}) {
			print $out "[<a href=\"#$count\">$subtitle</a>] ";
			$count++;
		    }
		}
	    } else {
		print $out "$line\n";
	    }
	}
	
    } elsif ($typ eq "oldschool") {

	my ($autor_head, $datum_head, $version_head, $size_head, $name_head, $comment_head);
	if ($lang eq "de") {
	    # Deutsch
	    
	    $autor_head =	"Autor";
	    $datum_head =	"Datum";
	    $version_head =	"Version";
	    $size_head =	"Größe";
	    $name_head =	"Datei";
	    $comment_head =	"Hinweise";
	    
	} else {
	    # Englisch
	    
	    $autor_head =	"author";
	    $datum_head =	"date";
	    $version_head =	"version";
	    $size_head =	"size";
	    $name_head =	"file";
	    $comment_head =	"notes";
	    
	};
	
	# Vorlage durchgehen
	my @input = readTag($in, 'OLDSCHOOL', $lang);

	my $zeile= shift @input;
	while ($zeile !~ /^<!--.BEG/) {
	    $zeile= shift @input;
	}
	print $out "$zeile";
	
	# Autor-Spalte ?
	
	my $autor_schalter;
	if ($zeile =~ /\ EXT\ /) {
	    $autor_schalter = "JA";
	} else {
	    $autor_schalter = "NEIN";
	};
	
	# Tabellenkopf
	
	my $fehler = 0;

	my $typ = shift @input;
	if ($typ ne "PROGRAMMNAME") {
	    $fehler++;
	    print "\n\nFEHLER [$fehler]: PROGRAMMNAME fehlt\n\n";
	}
	my $programmname=shift @input;
	
	$typ = shift @input;
	if ($typ ne "SPRUNGMARKE") {
	    $fehler++;
	    print "\n\nFEHLER [$fehler]: SPRUNGMARKE fehlt\n\n";
	}
	my $sprungmarke=shift @input;
	
	print $out "<h2 class=\"centered\">Download</h2>";
	print $out "<h1 class=\"centered\">$programmname</h1>";

	# Der Freitext		
	
	$typ = shift @input;
	if ($typ ne "FREITEXT") {
	    $fehler++;
	    printf "\n\nFEHLER [$fehler]: FREITEXT fehlt\n\n";
	}

	print $out "<p>";
	$zeile = shift @input;
	while ($zeile ne "ZEILE") {
	    $zeile = expand($zeile,$lang);
	    print $out "$zeile\n";
	    $zeile = shift @input;
	}
	print $out "</p>";

	#
	# TODO FIXME: get this table centered again?!
	#
	print $out "<table class=\"dwn\"><tr>";
	if ($autor_schalter eq "JA") {
	    print $out "<th class=\"dwn\">$autor_head</th>";
	};
	print $out "<th class=\"dwn\">$datum_head</th>";
	print $out "<th class=\"dwn\">$version_head</th>";
	print $out "<th class=\"dwn\">$size_head</th>";
	print $out "<th class=\"dwn\">$name_head</th>";
	print $out "<th class=\"dwn\">$comment_head</th>";
	print $out "</tr>";
	
	# Die einzelnen Zeilen
	
	$typ = $zeile;
	while (($typ eq "ZEILE") || ($typ eq "--HLINE--")) {

	    if ($typ eq "--HLINE--") {
		
		print $out "<tr><td colspan=";
		if ($autor_schalter eq "JA") {
		    print $out "6";
		} else {
		    print $out "5";
		}
		print $out "><hr></td></tr>\n";
		
	    } else {
		
		my $autor;
		if ($autor_schalter eq "JA") {
		    $autor = shift @input;
		};
		my $datum = shift @input;
		my $version = shift @input;
		my $size = shift @input;
		my $url = shift @input;
		my $name = shift @input;
		my $comment = shift @input;
		
		print $out "<tr>";
		if ($autor_schalter eq "JA") {
		    print $out "<td class=\"dwnauthor\">$autor</td>";
		};
		print $out "<td class=\"dwndate\">$datum</td>";
		print $out "<td class=\"dwnversion\">$version</td>";
		print $out "<td class=\"dwnsize\">$size</td>";
		print $out "<td class=\"dwnlink\"><a href=\"$url\">$name</a></td>";
		print $out "<td class=\"dwncomment\">$comment</td>";
		print $out "</tr>\n";
		
	    }
	    
	    $typ = shift @input;
	}
	
	# Tabellenfuß
	
	if ($typ !~ /^<!--.END/) {
	    $fehler++;
	    print "\n\nFEHLER [$fehler]: <!--END oder ZEILE fehlt \n\n";
	}
	
	print $out "</table>";
	print $out "$typ\n";
	

	if ($fehler > 0) {
	    
	    die "\n\nOBACHT! ES SIND $fehler FEHLER AUFGETRETEN!\n\n";
	    
	}

	newsBox($out, $page, $lang);

    } else {
	die "UNKNOWN TYPE <$typ>\n";
    }

    print $out "</article>\n";

    #
    # Navigation
    #

    print $out " <nav id='sidebar'>\n";
    navBar($out, $i, $lang);
    print $out " </nav>\n";

    #
    # Seitenfuß
    #

    print $out <<~"EOF";
    <footer>
      <span><a class="h-card" href="$baseurl">$author</a></span>
      :
      <span><a href="webcoma.$lang.html">$version</a></span>
      :
      <span>$date</span>
      :
    EOF
    ;
    my $uri = "$baseurl/$file.$lang.html";
    if ($cache{$page}{$lang}{VALID}) {
	print $out <<~"EOF";
          <span><a href="http://validator.w3.org/check?uri=$uri">valid HTML</a></span>
          :
        EOF
	;
    } else {
	print $out <<~"EOF";
          <span><a href="http://validator.w3.org/check?uri=$uri">HTML not yet validated!</a></span>
          :
        EOF
	;
    }
    print $out <<~"EOF";
      <span><a href="http://jigsaw.w3.org/css-validator/validator?uri=$uri">valid CSS</a></span>
      :
      <span><a href="http://www.feedvalidator.org/check.cgi?url=$baseurl/rssfeed.$lang.xml">valid RSS</a></span>
    EOF
    ;
    if ($flattr) {
	print $out <<~"EOF";
      :
      <span><a href="$flattr" target="_blank" class="flattr">Flattr this!</a></span>
    EOF
    ;
    }
    print $out <<~"EOF";
    </footer>
    </body>
    </html>
    EOF
    ;

    close $in  or die "can't close <$srcpath/$file.page>: $!";
    close $out or die "can't close <$destpath/$file.$lang.html>: $!";
}


#


sub initDates()
{
    foreach my $lang (@languages) {
	$date{$lang} = convertDate($lang, `$date_cmd +%Y%m%d\\ %H:%M:%S`);
	print "$lang: $date{$lang}\n";
	chomp $date{$lang};
    }
}


#

sub convertDate($$)
{
    my $lang = shift;
    chomp(my $date = shift);
    my $ret;
    if ($lang eq "de") {
	$ret = `LANG=de_DE.UTF-8 $date_cmd +%c -d "$date"`;
    } else {
	$ret = `LANG=EN $date_cmd -d "$date"`;
    }
    chomp $ret;
    return $ret;
}


#


sub readTag($$$)
{
    my ($fh, $tag, $lang) = @_;

    my @ret;

    while (<$fh>) {
	last if /#$tag</;
    }
    
    while (my $line = <$fh>) {
	last if $line =~ /#$tag>/;
	chomp $line;

	# Einzel-Language-Tag
	if ($line =~ /^&([^:]*):/) {
	    if ($1 eq $lang) {
		$line =~ s/^&$lang://;
		push @ret, $line;
	    }
	}
	# Language-Block
	elsif ($line =~ /^&(.*)</) {
	    if ($1 eq $lang) {
		while (my $line = <$fh>) {
		    last if $line =~ /^&$lang>/;
		    chomp $line;
		    push @ret, $line;
		}
	    } else {
		while (<$fh>) {
		    last if /^&$1>/;
		}
	    }
	}
	# Freitext
	else {
	    push @ret, $line;
	}
    }

    return @ret;
}


#


sub navBar($$$)
{
    my ($out, $i, $lang) = @_;

    my ($me, $path) = getStuff($i, $lang);
    $me =~ s/^.*!//;
    if ($path ne "") {
	$path .= "!";
    }

    print $out "<h2>$navtitle{$lang}</h2>\n";
    my $depth = $path =~ tr/!/!/;
    my $olddepth = -1;
    my $li = 0;
    foreach my $element ( @{$pagestructure{$lang}} ) {
	my @element = (split /!/, $element);
	my $file = pop @element;
	my $el_path = join '!', @element;
	my $el_depth = $element =~ tr/!/!/;

	if ($el_depth == $depth) {
	    # neighbour nodes: check for own tree
	    next unless $element =~ /^$path/;
	    
	} elsif ($el_depth > $depth) {
	    # subnodes: check for own tree
	    
	    # skip subsubnodes and the like
	    next if $el_depth > $depth + 1;
	    # test if subnodes are direct siblings
	    next unless $element =~ /^$path$me/;
	} else {
	    # super nodes: check for own tree
	    next unless $path =~ /^$el_path/;
	}

	if ($el_depth > $olddepth) {
	    print $out "<ul>\n";
	    $olddepth++;
	} else {
	    while ($el_depth < $olddepth) {
		$olddepth--;
		print $out "</li>\n</ul>\n";
		$li--;
	    }
	    if ($li) {
		print $out "</li>\n";
	    }
	}
	
	# shorten title
	my $title = $cache{$element}{$lang}{TITLE};
	$title =~ s/^.* - //;
	if ($element eq $path.$me) {
	    print $out "<li><a href=\"#\" class=\"selected\">$title</a>";
	} else {
	    print $out "<li><a href=\"$file.$lang.html\">$title</a>";
	}
	$li++;
	
    }
    while ($olddepth > -1) {
	if ($li) {
	    print $out "</li>\n";
	    $li--;
	}
	print $out "</ul>\n";
	$olddepth--;
    }


    print $out "<h2>$langtitle{$lang}</h2>\n";
    print $out "<ul>\n";
    foreach my $l (@languages) {
	# until GDPR is available in English: remove english files
	next if $l eq 'en';
	if ($l ne $lang) {
	    if (grep { $pagestructure{$lang}[$i] eq $_ } @{$pagestructure{$l}}) {
		print $out "<li><a href=\"$me.$l.html\">$language{$l}</a></li>\n";
	    }
	} else {
	    print $out "<li><a href=\"#\" class=\"selected\">$language{$l}</a></li>\n";
	}	    
    }
    print $out "<li><a href=\"$sourcepath/$me.txt\" class=\"navbar\">$langsrc{$lang}</a></li>\n";
    print $out "</ul>\n";

    print $out "<h2>$feedtitle{$lang}</h2>\n";
    print $out "<ul>\n";
    print $out "<li><a href=\"$baseurl/rssfeed.$lang.xml\" class=\"navbar\">$feedtitle{$lang}</a></li>\n";
    print $out "</ul>\n";


}


#


sub expand($$)
{
    my $zeile = shift;
    my $lang = shift;

    if ($zeile =~ /#D?LINK:([^#]*)#/) {
	my ($link, $hash, $class) = split /!/, $1, 3;
	if ($hash) {
	    $hash = "#$hash";
	    if ($class) {
		$class=" class=\"$class\"";
	    } else {
		$class="";
	    }
	} else {
	    $hash  = "";
	    $class = "";
	}
	$zeile =~ s/#D?LINK:[^#]*#/<a href="$link.$lang.html$hash"${class}>/;
    }

    if ($zeile =~ /#SUBTITLE:(.*):[^:]*:/) {
	die '#SUBTITLE, but did not find surrounding container!' unless $zeile =~ />#SUBTITLE:(.*):[^:]*:/;
	$zeile =~ s/>#SUBTITLE:(.*):[^:]*:/ id="$subtitlecount">$1/;
	$subtitlecount++;
    }

    return $zeile;
}


#


sub newsBox($$$)
{
    my ($out, $path, $lang) = @_;

    my %dates;

    foreach my $file (keys %news) {
	if ($file =~ /^$path/) {
	    my $link = $file;
	    $link =~ s/.*!//g;
	    foreach my $date (keys %{$news{$file}}) {
		if (defined $news{$file}{$date}{$lang}) {
		    push @{$dates{$date}},
		    {
			'LINK' => $link,
			'TEXT' => $news{$file}{$date}{$lang},
			'TITLE'=> $cache{$file}{$lang}{'TITLE'}
		    };
		}
	    }
	}
    }

    if (keys %dates) {
	
	print $out "<div class=\"newsbox\"><p><b>&nbsp;&nbsp;News</b></p>\n";

	my $count = 1;
	foreach my $date (reverse sort keys %dates) {
	    last if $count > $MAXBOXENTRIES;
	    
	    # Language-Datum!
	    
	    my $datum = $date;
	    
	    if ($lang eq "de") {
		$datum =~ /(....)-(..)-(..)/;
		$datum = "$3.$2.$1";
	    }
	    
	    foreach my $elem (@{$dates{$date}}) {
		print $out "<p><a href=\"$elem->{'LINK'}.$lang.html\">$datum: $elem->{'TITLE'}</a><br>\n";
		print $out "$elem->{'TEXT'}</p>\n";
		$count++ unless $path eq "";
	    }
	}

	print $out "</div>\n";

    }
    
}


#


sub rssfeed($)
{
    my ($lang) = @_;

    my $feedfile = "rssfeed.$lang.xml";

    my %dates;

    foreach my $file (keys %news) {
	my $link = $file;
	$link =~ s/.*!//g;
	foreach my $date (keys %{$news{$file}}) {
	    if ($date =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
		if (defined $news{$file}{$date}{$lang}) {

		    # remove &shy; from title, only relevant for page tree on webpage
		    my $stripped_title = $cache{$file}{$lang}{'TITLE'};
		    $stripped_title =~ s/&shy;//g;

		    push @{$dates{$date}},
		    {
			'LINK' => $link,
			'TEXT' => $news{$file}{$date}{$lang},
			'TITLE'=> $stripped_title,
		    };
		}
	    } else {
		warn "skipped wrong date `$date' in `$file'";
	    }
	}
    }

    open my $feed, '>', "$destpath/$feedfile" or die "can't open <$destpath/$feedfile>: $!";

    print $feed <<~"EOF";
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0"
     xmlns:dc="http://purl.org/dc/elements/1.1/"
     xmlns:content="http://purl.org/rss/1.0/modules/content/"
     xmlns:atom="http://www.w3.org/2005/Atom">
      <channel>
        <atom:link href="$baseurl/$feedfile" rel="self" type="application/rss+xml" />
        <title>$rsstitle</title>
        <link>$baseurl/index.$lang.html</link>
        <description>$rssdescription</description>
        <language>$lang</language>
        <generator>$version</generator>
    EOF
    ;
    if ($rsspicurl) {
	print $feed <<~"EOF";
            <image>
              <url>$rsspicurl</url>
              <title>$rsstitle</title>
              <link>$baseurl/index.$lang.html</link>
              <width>$rsspicwidth</width>
              <height>$rsspicheight</height>
            </image>
        EOF
	;
    }

    if (keys %dates) {
	
	my $count = 1;
	foreach my $date (reverse sort keys %dates) {
	    last if $count > $rssmax;

	    my $datum = strftime("%a, %d %b %Y %H:%M:%S +0000", 0, 0, 12, substr($date,8,2), substr($date,5,2)-1, substr($date,0,4)-1900);

	    foreach my $elem (@{$dates{$date}}) {

		my $guid = md5_hex( $elem->{TEXT} . $elem->{TITLE} . $datum );

		print $feed "    <item>\n";
		print $feed "      <title><![CDATA[$sitename - $elem->{'TITLE'}]]></title>\n";
		print $feed "      <description>\n<![CDATA[$elem->{'TEXT'}]]></description>\n";
#		print $feed "      <content:encoded>\n<![CDATA[$elem->{'TEXT'}]]></content:encoded>\n";
		print $feed "      <pubDate>$datum</pubDate>\n";
		print $feed "      <dc:creator>$author (mailto:$authormail)</dc:creator>\n";
#		print $feed "      <category domain=\"URL\">category</category>\n"; ## TODO
		print $feed "      <guid isPermaLink=\"false\">$guid</guid>\n"; ## TODO
		print $feed "      <link>$baseurl/$elem->{'LINK'}.$lang.html</link>\n";
#		print $feed "      <comments>URL</comments>\n";
		print $feed "    </item>\n";
		$count++;
		last if $count > $rssmax;
	    }
	}

    }

    print $feed "  </channel>\n";
    print $feed "</rss>\n";

    close $feed or die "can't close <$destpath/$feedfile>: $!";

    print "  $feedfile\n";
    
}


#


sub includeSiteMap($$)
{
    my ($out, $lang) = @_;

    my @oldpath = ("");
    my @list = @{$pagestructure{$lang}};
    print $out "<ul>\n";
    while (my $page = shift @list) {

	my ($path, $file);

	if ($page =~ /^(.*)!([^!]*)$/) {
	    $path = $1;
	    $file = $2;
	} else {
	    $path = "";
	    $file = $page;
	}
	
	if ($path ne $oldpath[0]) {
	    if ($path !~ /^$oldpath[0]/) {
		while ($path ne $oldpath[0]) {
		    print $out "</li></ul></li>\n";
		    shift @oldpath;
		}
	    } else {
		print $out "<ul>\n";
		unshift @oldpath, $path;
	    }
	} else {
	    print $out "</li>\n" unless @oldpath == 1;
	}

	print $out "<li><a href=\"$file.$lang.html\">$cache{$page}{$lang}{'TITLE'}</a>";
	if ($cache{$page}{$lang}{VALID}) {
	    print $out " (V)";
	}
	print $out "\n";

    }
    
    foreach (@oldpath) {
	print $out "</li></ul>\n";
    }

}


#


sub getLeft($$)
{
    my ($i, $lang) = @_;
    my ($file, $path, @elements) = getStuff($i, $lang);
    my $left="";
    for (my $j = $i-1; $j >= 0; $j--) {
	my @elements = split /!/, $pagestructure{$lang}[$j];
	my $file = pop @elements;
	if ((join '!', @elements) eq $path) {
	    $left = $file;
	    $j = -1;
	}
    }
    return $left;
}


#

    
sub getRight($$)
{
    my ($i, $lang) = @_;
    my ($file, $path, @elements) = getStuff($i, $lang);
    my $right="";
    for (my $j = $i + 1; defined $pagestructure{$lang}[$j]; $j++) {
	my @elements = split /!/, $pagestructure{$lang}[$j];
	my $file = pop @elements;
	if ((join '!', @elements) eq $path) {
	    $right = $file;
	    $j = @{$pagestructure{$lang}} + 1;
	}
    }
    return $right;
}


#


sub getStuff($$)
{
    my ($i, $lang) = @_;
    my @elements = split /!/, $pagestructure{$lang}[$i];
    my $file = pop @elements;
    my $path = join '!', @elements;
    return ($file, $path, @elements);
}


#


sub rssBox($$$$)
{
    my ($out, $file, $title, $lang) = @_;

    $file = "rsscache/$file";

    my $rss = XML::RSS->new;
    open my $rssfile, '<', $file or die "can't open rssfile <$file>: $!";
    binmode $rssfile, ':encoding(latin-1)'; # WTF! die Files sind utf8-kodiert, aber nur so bleiben die Umlaute heile?!
    {
	local $/ = undef;
	my $filecontent = <$rssfile>;
	$rss->parse($filecontent);
    }
    close $rssfile or die "can't open rssfile <$file>: $!";

    if (@{$rss->{items}})
    {
	my $count = 0;
	print $out "<div class=\"newsbox\"><p><b>&nbsp;&nbsp;$title</b></p>\n";
	foreach my $item (@{$rss->{items}})
	{
	    last if ++$count > $MAXBOXENTRIES;
	    # Twitter style or real RSS?
	    if (exists $item->{description})
	    {
		my $text = $item->{description};
		# remove HTML validator warning (we're only HTML 4.x, not XHTML)
		$text =~ s,/>,>,g;
		$text =~ s,style='float:left;margin: 0 6px 6px 0;',class="twitterfloatleft",g;
		$text =~ s/border=0 target/target/g;
		$text =~ s/img src='http:/img alt='twitter avatar icon' src='https:/g;
		$text =~ s/img src="http:/img alt='image from twitter' src="https:/g;
		print $out "$text<p></p>\n";
	    }
	    else
	    {
		my $date = str2time($item->{pubDate});
		if ($lang eq 'de')
		{
		    $date = strftime('%d.%m.%Y', localtime($date));
		}
		else
		{
		    $date = strftime('%Y-%m-%d', localtime($date));
		}
		print $out "<ul><li><a href=\"$item->{link}\">$date: $item->{title}</a></li></ul>\n";
	    }
	}
	print $out "</div>\n";
    }
}
