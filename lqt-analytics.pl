#!/usr/bin/perl
#
# lqt-analytics.pl
#
# TO DO:
# - proper CSV support
# - timeline of thread activity
# - author reports

use strict;
use DBI;
use Getopt::Std;
use Text::CSV;

# config
my $DB = 'liquidthreads';
my $DB_USER = 'root';
my $DB_PW = '';

# global data structures
my @threads;
my %posts;
my %authors;
my %date;
my %time;

# command-line parameters
our $opt_d;
our $opt_t;

getopts('dt');

# parse database
my $dbh = DBI->connect("DBI:mysql:database=$DB", $DB_USER, $DB_PW);

my @t = @{$dbh->selectall_arrayref('SELECT * FROM thread')};
foreach my $r (@t) {
    # update date and time indices
    my ($year, $month, $day, $hour, $minutes) = &parse_date($r->[9]);
    $date{"$year-$month-$day"}++;
    $time{$hour}++;

    # update author index
    if ($authors{$r->[7]}) {
        push @{$authors{$r->[7]}}, "$year-$month-$day";
    }
    else {
        $authors{$r->[7]} = [];
    }

    # build threads and posts
    $posts{$r->[0]} = &update_post($posts{$r->[0]}, $r->[9], $r->[8], $r->[7], $r->[13]);
    if ($r->[2] eq '0') { # root!
        push @threads, { root_id => $r->[0] };
    }
    else {
        $posts{$r->[3]} = &update_post($posts{$r->[3]});
        push @{$posts{$r->[3]}->{children}}, $r->[0];
    }
}

# process thread stats
my $total_size = 0;
my $total_depth = 0;
my $total_unique_authors = 0;
my $total_modified = 0;
my $biggest_size = 0;
my $biggest_depth = 0;
my $most_authors = 0;
my $most_modified = 0;

foreach my $t (@threads) {
    my $root = $posts{$t->{root_id}};
    ($t->{size}, $t->{depth}, $t->{modified}, $t->{authors}) =
      &traverse_thread($posts{$t->{root_id}}, 0, 1, 0, [ ]);

    $total_size += $t->{size};
    $total_depth += $t->{depth};
    $total_unique_authors += @{$t->{authors}};
    $total_modified += $t->{modified};

    $biggest_size = $t->{size} if ($t->{size} > $biggest_size);
    $biggest_depth = $t->{depth} if ($t->{depth} > $biggest_depth);
    $most_authors = @{$t->{authors}} if (@{$t->{authors}} > $most_authors);
    $most_modified = $t->{modified} if ($t->{modified} > $most_modified);
}

# print stats
my $num_threads = @threads;
my $num_authors = scalar keys %authors;

if ($opt_d) {
    print join(',', sort keys %date) . "\n";
    foreach my $d (sort keys %date) {
        print $date{$d} . ',';
    }
    print "\n";
}
elsif ($opt_t) {
    print join(',', sort keys %time) . "\n";
    foreach my $t (sort keys %time) {
        print $time{$t} . ',';
    }
    print "\n";
}
else {
    print "$num_threads threads\n";
    print "$total_size total posts\n";
    print "$total_modified modified posts\n";
    printf("%.2f posts/thread (biggest is %d)\n", $total_size / $num_threads, $biggest_size);
    printf("%.2f depth/thread (deepest is %d)\n", $total_depth / $num_threads, $biggest_depth);
    printf("%.2f unique authors/thread (most is %d)\n", $total_unique_authors / $num_threads, $most_authors);
    printf("%.2f modified posts/thread (most is %d)\n", $total_modified / $num_threads, $most_modified);
    print "$num_authors authors\n";
    printf("%.2f posts/author\n", $total_size / $num_authors);
}
# fini

sub parse_date {
    my $ts = shift;

    $ts =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
    return ($1, $2, $3, $4, $5);
}

sub update_post {
    my ($post, $created, $modified, $author, $article_id) = @_;
    $post = {} if (!$post);
    $post->{created} = $created if ($created);
    $post->{modified} = $modified if ($modified);
    $post->{author} = $author if ($author);
    $post->{article_id} = $article_id if ($article_id);
    $post->{children} = [] if (!$post->{children});
    return $post;
}

sub traverse_thread {
    my ($p, $size, $depth, $num_modified, $authors) = @_;

    $size++;
    $num_modified++ if ($p->{created} ne $p->{modified});

    push(@{$authors}, $p->{author}) if (!grep(/^$p->{author}$/, @{$authors}));
    if (@{$p->{children}}) {
        $depth++;
        foreach my $c (@{$p->{children}}) {
            ($size, $depth, $num_modified, $authors) =
              &traverse_thread($posts{$c}, $size, $depth, $num_modified, $authors)
          }
    }
    return ($size, $depth, $num_modified, $authors);
}

__END__

=head1 NAME

lqt-analytics.pl -- Analytics tool for MediaWiki's LiquidThreads extension

=head1 VERSION

Version 1.0.0

=head1 USAGE

  lqt-analytics.pl [-dt]

=head1 DATA STRUCTURES

This script parses the LiquidThreads MediaWiki database and builds
five data structures for gathering statistical information:

=head2 %posts

  ( id => {
            created => TIMESTAMP,
            modified => TIMESTAMP,
            author => STRING,
            article_id => INT,
            children => [ CHILDREN_IDs ]
          } )

=head2 @threads

  ( {
      root => POST,
      size => INT,
      depth => INT,
      modified => INT,
      authors => [ STRING ]
    } )

=head2 %authors

=head2 %date

=head2 %time

=head1 AUTHOR

Eugene Eric Kim, E<lt>eekim@blueoxen.comE<gt>

=head1 COPYRIGHT & LICENSE

(C) Copyright 2009 Blue Oxen Associates.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
