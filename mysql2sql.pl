#!/usr/bin/perl

&pre;
my $ignore = <STDIN>; # ignore first line
while (<STDIN>) {
    chomp;
    my @val = split /\t/;
    print 'INSERT INTO thread VALUES (' . $val[0] . ', ' . $val[1] . ', ' .
        $val[2] . ', ' . $val[3] . ', ' . $val[4] . ", '" .
        &esc($val[5]) . "', " . $val[6] . ", '" . $val[7] . "', '" .
        $val[8] . "', '" . $val[9] . "', " . $val[10] . ', ' .
        $val[11] . ", '" . $val[12] . "', " . $val[13] . ', ' .
        $val[14] . ", '" . $val[15] . "', " . $val[16] . ");\n";
}

sub esc {
    my $s = shift;
    $s =~ s/\'/\\\'/g;
    return $s;
}

sub pre {
    print <<EOM
DROP TABLE IF EXISTS `thread`;
CREATE TABLE `thread` (
  `thread_id` int(8) unsigned NOT NULL auto_increment,
  `thread_root` int(8) unsigned NOT NULL default '0',
  `thread_ancestor` int(8) unsigned NOT NULL default '0',
  `thread_parent` int(8) unsigned default NULL,
  `thread_summary_page` int(8) unsigned default NULL,
  `thread_subject` varchar(255) default NULL,
  `thread_author_id` int(10) unsigned default NULL,
  `thread_author_name` varchar(255) default NULL,
  `thread_modified` varchar(14) binary NOT NULL default '',
  `thread_created` varchar(14) binary NOT NULL default '',
  `thread_editedness` int(1) NOT NULL default '0',
  `thread_article_namespace` int(11) NOT NULL default '0',
  `thread_article_title` varchar(255) binary NOT NULL default '',
  `thread_article_id` int(8) unsigned NOT NULL default '0',
  `thread_type` int(4) unsigned NOT NULL default '0',
  `thread_sortkey` varchar(255) NOT NULL default '',
  `thread_replies` int(8) default '-1',
  PRIMARY KEY  (`thread_id`),
  UNIQUE KEY `thread_root` (`thread_root`),
  UNIQUE KEY `thread_root_page` (`thread_root`),
  KEY `thread_ancestor` (`thread_ancestor`,`thread_parent`),
  KEY `thread_article_title` (`thread_article_namespace`,`thread_article_title`,
`thread_sortkey`),
  KEY `thread_article` (`thread_article_id`,`thread_sortkey`),
  KEY `thread_modified` (`thread_modified`),
  KEY `thread_created` (`thread_created`),
  KEY `thread_summary_page` (`thread_summary_page`),
  KEY `thread_author_id` (`thread_author_id`,`thread_author_name`),
  KEY `thread_sortkey` (`thread_sortkey`)
) TYPE=InnoDB;
EOM
}
