#!/usr/bin/perl
#
# lqt-analytics.pl
#
# TO DO:
# - timeline of thread activity
# - author reports
# - mean and median response times
# - social network graphs
#   - thread buddies
#   - response buddies
# - when certain people post, are people more likely to respond?

use strict;
use DBI;
use Getopt::Std;
use Statistics::Basic qw(:all);
use Time::Local;

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
our $opt_a;
our $opt_d;
our $opt_t;

getopts('adt');

# parse database
my $dbh = DBI->connect("DBI:mysql:database=$DB", $DB_USER, $DB_PW);

my @t = @{$dbh->selectall_arrayref('SELECT * FROM thread')};
foreach my $r (@t) {
    # update date and time indices
    my ($year, $month, $day, $hour, $minutes) = &parse_date($r->[9]);
    if (!$date{"$year-$month-$day"}) {
        $date{"$year-$month-$day"}->{posts} = 0;
        $date{"$year-$month-$day"}->{authors} = {};
    }
    $date{"$year-$month-$day"}->{posts}++;
    $date{"$year-$month-$day"}->{authors}->{$r->[7]}++;
    $time{$hour}++;

    # update author index
    $authors{$r->[7]} = {} if (!$authors{$r->[7]});
    $authors{$r->[7]}->{posts} = [] if (!$authors{$r->[7]}->{posts});
    push @{$authors{$r->[7]}->{posts}}, "$year-$month-$day";

    # build threads and posts
    $posts{$r->[0]} = &update_post($posts{$r->[0]}, $r->[9], $r->[7], $r->[13]);
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
my $total_response_time = 0;
my $total_responses = 0;
my $biggest_size = 0;
my $biggest_depth = 0;
my $most_authors = 0;

foreach my $t (@threads) {
    my $root = $posts{$t->{root_id}};
    ($t->{size}, $t->{depth}, $t->{authors}) = &traverse_thread($posts{$t->{root_id}}, 0, 1, [ ]);

    $total_size += $t->{size};
    $total_depth += $t->{depth};
    $total_unique_authors += @{$t->{authors}};

    $biggest_size = $t->{size} if ($t->{size} > $biggest_size);
    $biggest_depth = $t->{depth} if ($t->{depth} > $biggest_depth);
    $most_authors = @{$t->{authors}} if (@{$t->{authors}} > $most_authors);
}

# print stats
my $num_threads = @threads;
my $num_authors = scalar keys %authors;

if ($opt_d) {
    my $i = 1;
    my $posts_subtotal = 0;
    my $authors_subtotal = 0;
    print "Date,Posts,Mean Posts,Contributors,Mean Contributors\n";
    foreach my $d (sort keys %date) {
        $posts_subtotal += $date{$d}->{posts};
        $authors_subtotal += scalar keys %{$date{$d}->{authors}};
        printf("%s,%d,%.2f,%d,%2.f\n", $d, $date{$d}->{posts},
               $posts_subtotal / $i,
               scalar keys %{$date{$d}->{authors}},
               $authors_subtotal / $i);
        $i++;
    }
}
elsif ($opt_t) {
    print "Time,Posts\n";
    foreach my $t (sort keys %time) {
        printf("%s, %d\n", $t, $time{$t});
    }
}
elsif ($opt_a) {
    print "Author,Posts,Days Posted,Posts/Day,Mean Response Time\n";
    foreach my $a (sort keys %authors) {
        my ($t, $days, $mean_response_time) = &author_stats($a);
        printf("%s,%d,%d,%.2f,%d\n", $a, $t, $days, $t / $days,
               $mean_response_time);
    }
}
else {
    print "$num_threads threads\n";
    print "$total_size total posts\n";
    printf("%.2f posts/thread (biggest is %d)\n", $total_size / $num_threads, $biggest_size);
    printf("%.2f depth/thread (deepest is %d)\n", $total_depth / $num_threads, $biggest_depth);
    printf("%.2f unique authors/thread (most is %d)\n", $total_unique_authors / $num_threads, $most_authors);
    print "$num_authors authors\n";
    printf("%.2f posts/author\n", $total_size / $num_authors);
    printf("Average time to respond is %s\n", &ts2diff(int($total_response_time / $total_responses)));
}
# fini

sub parse_date {
    my $ts = shift;

    $ts =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
    return ($1, $2, $3, $4, $5, $6);
}

sub diff_ts {
    my ($tm1, $tm2) = @_;

    my ($year, $month, $mday, $hour, $minutes, $seconds) = &parse_date($tm1);
    my $ts1 = timelocal($seconds, $minutes, $hour, $mday, $month - 1, $year);
    my ($year, $month, $mday, $hour, $minutes, $seconds) = &parse_date($tm2);
    my $ts2 = timelocal($seconds, $minutes, $hour, $mday, $month - 1, $year);
    return abs($ts2 - $ts1);
}

sub ts2diff {
    my $ts = shift;

    my $seconds = $ts % 60;
    $ts = ($ts - $seconds) / 60;
    my $minutes = $ts % 60;
    $ts = ($ts - $minutes) / 60;
    my $hours = $ts % 24;
    $ts = ($ts - $hours) / 24;
    my $days = $ts % 7;
    my $weeks = ($ts - $days) / 7;

    return sprintf("%d weeks, %d days, %02d:%02d:%02d",
                   $weeks, $days, $hours, $minutes, $seconds);
}

sub update_post {
    my ($post, $created, $author, $article_id) = @_;
    $post = {} if (!$post);
    $post->{created} = $created if ($created);
    $post->{author} = $author if ($author);
    $post->{article_id} = $article_id if ($article_id);
    $post->{children} = [] if (!$post->{children});
    return $post;
}

sub traverse_thread {
    my ($p, $size, $depth, $authors) = @_;

    $size++;

    push(@{$authors}, $p->{author}) if (!grep(/^$p->{author}$/, @{$authors}));
    if (@{$p->{children}}) {
        $depth++;
        foreach my $c (@{$p->{children}}) {
            my $response_time = &diff_ts($posts{$c}->{created}, $p->{created});
            $authors{$p->{author}}->{response_times} = [] if (!$authors{$p->{author}}->{response_times});
            push @{$authors{$p->{author}}->{response_times}}, $response_time;
            $total_response_time += $response_time;
            $total_responses++;
            ($size, $depth, $authors) =
              &traverse_thread($posts{$c}, $size, $depth, $authors)
          }
    }
    return ($size, $depth, $authors);
}

sub author_stats {
    my $a = shift;
    my @author_dates = @{$authors{$a}->{posts}};

    my $total = 0;
    my %dates;
    foreach my $d (@author_dates) {
        $total++;
        $dates{$d} = $dates{$d} ? $dates{$d} + 1 : 0;
    }
    my $days = keys %dates;
    my $mean_response_time = mean(@{$authors{$a}->{response_times}});
    return ($total, $days, $mean_response_time);
}

__END__

=head1 NAME

lqt-analytics.pl -- Analytics tool for MediaWiki's LiquidThreads extension

=head1 VERSION

Version 1.0.0

=head1 USAGE

  lqt-analytics.pl [-adt]

=head1 DATA STRUCTURES

This script parses the LiquidThreads MediaWiki database and builds
five data structures for gathering statistical information:

=head2 %posts

  ( id => {
            created => TIMESTAMP,
            author => STRING,
            article_id => INT,
            children => [ CHILDREN_IDs ]
          } )

=head2 @threads

  ( {
      root => POST,
      size => INT,
      depth => INT,
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
