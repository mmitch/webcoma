#!/usr/bin/perl -w
use strict;

# $Id: webCOMA.pl,v 1.3 2000-11-16 15:08:54 mitch Exp $

#
# $Log: webCOMA.pl,v $
# Revision 1.3  2000-11-16 15:08:54  mitch
# Removed a warning
#
#

my $version   = ' webCOMA $Revision: 1.3 $ ';
my $author    = "Christian Garbs";
my $authormail= 'mitch@uni.de';
my $sitename  = "Master Mitch on da netz";
my @languages = ('de', 'en');
my $srcpath   = "in";
my $destpath  = "out";
my $startdoc  = "index";
my $template  = "$srcpath/TEMPLATE";
my @pagestructure;
my %date;
my $date_cmd  = "date";
my $copy_cmd  = "cp";
my $host      = `hostname -f`;
my %cache;
my %linkcache;
$linkcache{$startdoc} = "";
my %dlinkcache;
my %news;

sub scanStructure($$);
sub printPage($);
sub initDates();
sub readTag($$);
sub navBar($$$$$);
sub expand($$);
sub newsBox($$);
sub includeSiteMap($);

my $themename;
my $boxoutercolor;
my $boxinnercolor;
my $boxtitlecolor;
my $backgroundcolor;
my $textonbgcolor;
my $linkonbgcolor;
my $newsonbgcolor;
my $newslinkcolor;
my $linkcolor;
my $alinkcolor;
my $vlinkcolor;
my $textcolor;
my $tableheadercolor;

my $theme = 1;

# Theme: Black'n'White
if ($theme == 0) {
    $themename="Black'n'White";
    $boxoutercolor="#000000";
    $boxinnercolor="#A0A0A0";
    $boxtitlecolor="#FFFFFF";
    $backgroundcolor="#444444";
    $textonbgcolor="#FFFFFF";
    $linkonbgcolor="#FFFFFF";
    $newsonbgcolor="#999999";
    $newslinkcolor="#FFFFFF";
    $linkcolor="#FFFFFF";
    $alinkcolor="#000000";
    $vlinkcolor="#E0E0E0";
    $textcolor="#000000";
    $tableheadercolor="#222222";
}

# Theme: Light Blue
elsif ($theme == 1) {
    $themename="Light Blue";
    $boxoutercolor="#3399FF";
    $boxinnercolor="#FFFFFF";
    $boxtitlecolor="#000000";
    $backgroundcolor="#121280";
#    $textonbgcolor="#FFFFFF";
#    $linkonbgcolor="#FFFFFF";
    $textonbgcolor="#CCCCCC";
    $linkonbgcolor="#DDDDFF";
    $newsonbgcolor="#2077E0";
    $newslinkcolor="#2077E0";
    $linkcolor="#0057C0";
    $alinkcolor="#4099FF";
    $vlinkcolor="#2077E0";
    $textcolor="#000000";
    $tableheadercolor="#000050";
}

# Theme: Monochrome
elsif ($theme == 2) {
    $themename="Monochrome";
    $boxoutercolor="#000000";
    $boxinnercolor="#FFFFFF";
    $boxtitlecolor="#FFFFFF";
    $backgroundcolor="#FFFFFF";
    $textonbgcolor="#000000";
    $linkonbgcolor="#000000";
    $newsonbgcolor="#000000";
    $newslinkcolor="#000000";
    $linkcolor="#000000";
    $alinkcolor="#FFFFFF";
    $vlinkcolor="#000000";
    $textcolor="#000000";
    $tableheadercolor="#000000";
}

# Theme: Inverted
elsif ($theme == 3) {
    $themename="Inverted";
    $boxoutercolor="#FFFFFF";
    $boxinnercolor="#000000";
    $boxtitlecolor="#000000";
    $backgroundcolor="#000000";
    $textonbgcolor="#FFFFFF";
    $linkonbgcolor="#FFFFFF";
    $newsonbgcolor="#FFFFFF";
    $newslinkcolor="#FFFFFF";
    $linkcolor="#FFFFFF";
    $alinkcolor="#000000";
    $vlinkcolor="#FFFFFF";
    $textcolor="#FFFFFF";
    $tableheadercolor="#FFFFFF";
}

# Theme: Neon
elsif ($theme == 4) {
    $themename="Neon";
    $boxoutercolor="#FF0000";
    $boxinnercolor="#000000";
    $boxtitlecolor="#FFFF00";
    $backgroundcolor="#000000";
    $textonbgcolor="#69D213";
    $linkonbgcolor="#FFFF00";
    $newsonbgcolor="#FFFF00";
    $newslinkcolor="#FFFF00";
    $linkcolor="#8080FF";
    $alinkcolor="#800080";
    $vlinkcolor="#8080FF";
    $textcolor="#69D213";
    $tableheadercolor="#FFFF00";
}

#


{
    print "Initializing dates.\n";
    initDates();
    print "\n";

    print "Scanning site structure:\n";
    scanStructure($startdoc,"");
    print (scalar @pagestructure);
    print " pages found.\n";
    print "\n";

    print "Scanning dlink integrity: ";
    foreach my $dlink (keys %dlinkcache) {
	if (! defined $linkcache{$dlink}) {
	    print "\n";
	    die "DLINK TO $dlink COULD NOT BE RESOLVED\n";
	}
    }
    print "OK\n\n";

    print "Looking for stale files: ";
    open FILES, "find $srcpath -maxdepth 1 -name *.page |" or die "can't list directory: $!";
    while (my $file = <FILES>) {
	chomp $file;
	$file =~ s/^$srcpath\///;
	$file =~ s/\.page$//;
	if (! defined $linkcache{$file}) {
	    print "\n";
	    die "STALE FILE $file.page DETECTED\n";
	}
    }
    close FILES or die "can't close directory list: $!";
    print "OK\n\n";

    print "Generating pages:\n";
    for (my $page = 0; $page < @pagestructure; $page++) {
	printPage($page);
    }
    print "\n";

    print "Finished.\n\n";
    exit 0;
}


#

		  
sub scanStructure($$)
{
    my $doc    = shift;
    my $parent = shift;

    print "  $parent$doc\n";
    push @pagestructure, "$parent$doc";

    my @files;

    foreach my $lang (@languages) {
	
	open IN, "<$srcpath/$doc.page" or die "can't open <$srcpath/$doc.page>: $!";
	
	my @temp;
	@temp = readTag("TYPE", $lang);
	
	$cache{"$parent$doc"}{$lang}{'TYPE'} = $temp[0];
	
	{
	    my $olddate;
	    my $text = "";
	    foreach my $news (readTag("NEWS", $lang)) {
		if ($news =~ /#DATE:(.*)/) {
		    if (defined $olddate) {
			## COPY BEGIN
			$text =~ s/\s+$//;
			$text =~ s/^\s+//;
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
	    $news{"$parent$doc"}{$olddate}{$lang} = $text unless $text eq "";
	    ## COPY END
	}
	    
	
	@temp = readTag("TITLE", $lang);
	$cache{"$parent$doc"}{$lang}{'TITLE'} = $temp[0];
	
	@temp = readTag("KEYWORDS", $lang);
	my @keywords = $temp[0];

	while (my $line = <IN>) {

	    if ($line =~ /#LINK:(.*)#/) {
		if ((grep /$1/, @files) == 0 ) {
		    push @files, $1;
		}
	    }
	    if ($line =~ /#DLINK:(.*)#/) {
		$dlinkcache{$1} = "";
	    }
	}
	close IN or die "can't close <$srcpath/$doc.page>: $!";
	
    }

    foreach my $file (@files) {
	next if $file =~ /^\s*$/;
	if (defined $linkcache{$file}) {
	    die "$srcpath/$file.page HAS MULTIPLE PARENTAGES\n";
	} else {
	    $linkcache{$file} = "";
	    if (! -e "$srcpath/$file.page") {
		system("$copy_cmd $template $srcpath/$file.page") == 0 or die "copy failed: $?";
		print "CREATING NEW TEMPLATE FOR $srcpath/$file.page\n";
	    }
	    scanStructure($file, "$parent$doc!");
	}
    }
}


#


sub printPage($)
{
    my $i       = shift;
    my $page    = $pagestructure[$i];

    my @elements = split /!/, $pagestructure[$i];
    my $file = pop @elements;
    my $parent  = "";
    if (@elements) {
	$parent = $elements[-1];
    }
    my $path = join '!', @elements;

    my $left="";
    for (my $j = $i-1; $j >= 0; $j--) {
	my @elements = split /!/, $pagestructure[$j];
	my $file = pop @elements;
	if ((join '!', @elements) eq $path) {
	    $left = $file;
	    $j = -1;
	}
    }
    
    my $right="";
    for (my $j = $i + 1; defined $pagestructure[$j]; $j++) {
	my @elements = split /!/, $pagestructure[$j];
	my $file = pop @elements;
	if ((join '!', @elements) eq $path) {
	    $right = $file;
	    $j = @pagestructure + 1;
	}
    }

    foreach my $lang (@languages) {
	my $typ = $cache{$pagestructure[$i]}{$lang}{'TYPE'};
	my $title = $cache{$pagestructure[$i]}{$lang}{'TITLE'};
	
	print "$file.$lang.html\t<$title>\t[$typ]\n";

	open IN, "<$srcpath/$file.page" or die "can't open <$srcpath/$file.page>: $!";
	open OUT, ">$destpath/$file.$lang.html" or die "can't open <$destpath/$file.$lang.html>: $!";
	
	my @news = readTag("NEWS", $lang);
	
	my @temp = readTag("KEYWORDS", $lang);
	my @keywords = $temp[0];
	
	print OUT <<"EOF";
<html><head><title>$sitename - $title</title>
<meta name="generator" content="$version">
<meta name="generating host" content="$host">
<meta name="ROBOTS" content="FOLLOW">
<meta name="DESCRIPTION" content="$sitename - $title">
<meta name="KEYWORDS" content="keywords">
<meta name="author" content="$author ($authormail)">
<meta http-equiv="revisit-after" content="15 days">
<meta http-equiv="content-language" content="$lang">
</head>
<body bgcolor="$backgroundcolor" text="$textcolor" link="$linkcolor" alink="$alinkcolor" vlink="$vlinkcolor">
<p><br></p>
EOF
    ;
	
	navBar($left, $parent, $right, $path, $lang);

	print OUT << "EOF";
<center><table border=0 cellpadding=2 cellspacing=0 bgcolor="$boxoutercolor" width="95%">
<tr><td>
&nbsp;&nbsp;&nbsp;<font color="$boxtitlecolor"><b><big>$title</big></b></font>
</td><td align="right">
EOF
    ;

	foreach my $l (@languages) {
	    if ($l ne $lang) {
		print OUT "<a href=\"$file.$l.html\"><font color=\"$boxtitlecolor\">[$l]</font></a> ";
	    } else {
		print OUT "<font color=\"$linkcolor\">[$l]</font> ";
	    }
	}

	print OUT << "EOF";
</td></tr><tr><td colspan=2>
<table border=0 cellpadding=10 cellspacing=0 width="100%" bgcolor="$boxinnercolor">
<tr><td>
EOF
    ;

	if (($typ eq "plain") or ($typ eq "news")) {

	    foreach my $line (readTag("PLAIN", $lang)) {
		$line = expand($line, $lang);

		if ($line =~ /#SITEMAP#/) {
		    includeSiteMap($lang);
		} elsif ($line =~ /#NEWS#/) {
		    if ($typ eq "plain") {
			newsBox($pagestructure[$i], $lang);
		    } else {
			newsBox("", $lang);
		    }
		} else {
		    print OUT "$line\n";
		}
	    }

	} elsif ($typ eq "oldschool") {

	    my ($autor_head, $datum_head, $version_head, $size_head, $name_head, $comment_head);
	    if ($lang eq "de") {
		# Deutsch
		
		$autor_head =	"Autor";
		$datum_head =	"Datum";
		$version_head =	"Version";
		$size_head =	"Gr&ouml;&szlig;e";
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
	    my @input = readTag("OLDSCHOOL", $lang);

	    my $zeile= shift @input;
	    while ($zeile !~ /^<!--.BEG/) {
		$zeile= shift @input;
	    }
	    print OUT "$zeile";
	
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
	    
	    print OUT "<P><BR><A NAME=\"$sprungmarke\"></A></P>";
	    print OUT "<CENTER><TABLE ALIGN=CENTER WIDTH=\"90%\" BORDER=0 CELLPADDING=12><TR><TD>";
	    print OUT "<H2 ALIGN=CENTER>Download</H2>";
	    print OUT "<H1 ALIGN=CENTER>$programmname</H1>";

#	    newsBox($pagestructure[$i], $lang);

	    # Der Freitext		
	    
	    $typ = shift @input;
	    if ($typ ne "FREITEXT") {
		$fehler++;
		printf "\n\nFEHLER [$fehler]: FREITEXT fehlt\n\n";
	    }

	    print OUT "<P>";
	    $zeile = shift @input;
	    while ($zeile ne "ZEILE") {
		$zeile = expand($zeile,$lang);
		print OUT "$zeile\n";	
		$zeile = shift @input;
	    }
	    print OUT "</P>";

	    print OUT "<P><BR></P><TABLE BORDER=0 CELLPADDING=2><TR>";
	    if ($autor_schalter eq "JA") {
		print OUT "<TH VALIGN=TOP ALIGN=LEFT><SMALL>$autor_head</SMALL></TH>";
	    };
	    print OUT "<TH VALIGN=TOP ALIGN=LEFT><SMALL>$datum_head</SMALL></TH>";
	    print OUT "<TH VALIGN=TOP ALIGN=LEFT><SMALL>$version_head</SMALL></TH>";
	    print OUT "<TH VALIGN=TOP ALIGN=LEFT><SMALL>$size_head</SMALL></TH>";
	    print OUT "<TH VALIGN=TOP ALIGN=LEFT><SMALL>$name_head</SMALL></TH>";
	    print OUT "<TH VALIGN=TOP ALIGN=LEFT><SMALL>$comment_head</SMALL></TH>";
	    print OUT "</TR>";
	
	    # Die einzelnen Zeilen
	
	    $typ = $zeile;
	    while (($typ eq "ZEILE") || ($typ eq "--HLINE--")) {

		if ($typ eq "--HLINE--") {
		    
		    print OUT "<TR><TD COLSPAN=";
		    if ($autor_schalter eq "JA") {
			print OUT "6";
		    } else {
			print OUT "5";
		    }
		    print OUT "><HR></TD></TR>\n";
		    
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
		    
		    print OUT "<TR>";
		    if ($autor_schalter eq "JA") {
			print OUT "<TD VALIGN=TOP ALIGN=LEFT>$autor</TD>";
		    };
		    print OUT "<TD VALIGN=TOP ALIGN=LEFT>$datum</TD>";
		    print OUT "<TD VALIGN=TOP ALIGN=RIGHT>$version</TD>";
		    print OUT "<TD VALIGN=TOP ALIGN=RIGHT>$size</TD>";
		    print OUT "<TD VALIGN=TOP ALIGN=LEFT><A TARGET=\"_top\" HREF=\"$url\">$name</A></TD>";
		    print OUT "<TD VALIGN=TOP ALIGN=LEFT>$comment</TD>";
		    print OUT "</TR>\n";
		    
		}
	    
		$typ = shift @input;
	    }
	
	    # Tabellenfuﬂ
	    
	    if ($typ !~ /^<!--.END/) {
		$fehler++;
		print "\n\nFEHLER [$fehler]: <!--END oder ZEILE fehlt \n\n";
	    }
	    
	    print OUT "</TABLE><P>";
	    print OUT "</P></TD></TR></TABLE></CENTER>\n";
	    print OUT "$typ\n";
	    

	    if ($fehler > 0) {
		
		die "\n\nOBACHT! ES SIND $fehler FEHLER AUFGETRETEN!\n\n";
		
	    }

	} else {
	    print STDERR "unknown type <$typ>\n";
	    print OUT "unknown type <$typ>\n";
	}


	print OUT "</td></tr></table></td></tr></table></center>\n";
	print OUT "<p><br></p>\n";

	navBar($left, $parent, $right, $path, $lang);

	#
	# Seitenfuﬂ
	#

        print OUT <<"EOF";
<table width="100%"><tr>
<td width="33%" align="left"><font color="$textonbgcolor">$date{$lang}</font></td>
<td width="34%" align="center"><font color="$textonbgcolor">$version</font></td>
<td width="33%" align="right"><a href="mailto:$authormail"><font color="$linkonbgcolor">$author</font></a></td>
</tr></table>
</body></html>
EOF
    ;
	close IN or die "can't close <$srcpath/$file.page>: $!";
	close OUT or die "can't close <$destpath/$file.$lang.html>: $!";
    }
}


#


sub initDates()
{
    foreach my $lang (@languages) {
	if ($lang eq "de") {
	    $date{$lang} = `$date_cmd +%c`;
	} else {
	    $date{$lang} = `LANG=EN $date_cmd`;
	}
	print "$lang: $date{$lang}";
	chomp $date{$lang};
    }
}


#


sub readTag($$)
{
    my $tag = shift;
    my $lang = shift;

    my @ret;

    while (<IN>) {
	last if /#$tag</;
    }
    
    while (my $line = <IN>) {
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
		while (my $line = <IN>) {
		    last if $line =~ /^&$lang>/;
		    chomp $line;
		    push @ret, $line;
		}
	    } else {
		while (<IN>) {
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


sub navBar($$$$$)
{
    my $left = shift;
    my $up = shift;
    my $right = shift;
    my $path = shift;
    my $lang = shift;
    
    if ($path ne "") {
	$path .= "!";
    }

    print OUT << "EOF";
<center><table border=0 width="100%"><tr>
EOF
    print OUT '<td width="33%" align="right">';
    if ($left ne "") {
	my $leftkey = "$path$left";
	print OUT "<br><a href=\"$left.$lang.html\"><font color=\"$boxoutercolor\">$cache{$leftkey}{$lang}{'TITLE'}<font></a>";
    } else {
	print OUT "&nbsp;";
    }
    print OUT "</td>";

    print OUT '<td width="34%" align="center">';
    if ($up ne "") {
	my $upkey = $path;
#	$upkey =~ s/([^!]*)!//;
	$upkey =~ s/!$//;
	print OUT "<a href=\"$up.$lang.html\"><font color=\"$boxoutercolor\">$cache{$upkey}{$lang}{'TITLE'}<font></a>";
    } else {
	print OUT "&nbsp;";
    }
    print OUT "</td>";

    print OUT '<td width="33%" align="left">';
    if ($right ne "") {
	my $rightkey = "$path$right";
	print OUT "<br><a href=\"$right.$lang.html\"><font color=\"$boxoutercolor\">$cache{$rightkey}{$lang}{'TITLE'}<font></a>";
    } else {
	print OUT "&nbsp;";
    }
    print OUT "</td>";

    print OUT "</tr></table></center>\n";

    print OUT "<p><br></p>";
}


#


sub expand($$)
{
    my $zeile = shift;
    my $lang = shift;

    $zeile =~ s/#LINK:(.*)#/<a href="$1.$lang.html">/g;
    $zeile =~ s/#DLINK:(.*)#/<a href="$1.$lang.html">/g;

    return $zeile;
}


#

sub newsBox($$)
{
    my $path = shift;
    my $lang = shift;

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
	
	print OUT "<p><br></p>\n";
	print OUT <<"EOF";
<center>
<table border=0 cellpadding=2 cellspacing=0 bgcolor="$boxoutercolor" width="95%">
<tr><td><b>&nbsp;&nbsp;News:</b></td><tr><td>
<table border=0 cellpadding=10 cellspacing=0 width="100%" bgcolor="$boxinnercolor">
<tr><td>
EOF
    ;

	my $count = 1;
	my $max   = 3;
	foreach my $date (reverse sort keys %dates) {
	    last if $count > $max;
	    
	    # Language-Datum!
	    
	    my $datum = $date;
	    
	    if ($lang eq "de") {
		$datum =~ /(....)-(..)-(..)/;
		$datum = "$3.$2.$1";
	    }
	    
	    foreach my $elem (@{$dates{$date}}) {
		print OUT "<p><a href=\"$elem->{'LINK'}.$lang.html\">$datum: $elem->{'TITLE'}</a><br>\n";
		print OUT "$elem->{'TEXT'}</p>\n";
		$count++ unless $path eq "";
	    }
	}

	print OUT "</td></tr></table></td></tr></table></center>\n";
	print OUT "<p><br></p>\n";

    }
    
}


#


sub includeSiteMap($)
{
    my $lang = shift;
    my @oldpath = ("");
    my @list = @pagestructure;
    print OUT "<ul>\n";
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
		    print OUT "</ul>\n";
		    shift @oldpath;
		}
	    } else {
		print OUT "<ul>\n";
		unshift @oldpath, $path;
	    }
	}

	print OUT "<li><a href=\"$file.$lang.html\">$cache{$page}{$lang}{'TITLE'}</a></li>\n";

    }
    print OUT "</ul>\n";
}
