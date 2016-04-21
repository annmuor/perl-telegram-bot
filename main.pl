#!/usr/bin/perl
# (C) kreon 2016
use strict;
use warnings;
use threads;
use threads::shared;
use lib 'perl5';
use utf8;
use Thread::Queue;
use WWW::Telegram::BotAPI;
use JSON;

our %CONFIG;
our %state;
our ($api, $inbound, $outbound);

main();

# INTERNAL SUBS #
sub main {
  require './config.pm';
  $main::api = WWW::Telegram::BotAPI->new ( token => $CONFIG{TOKEN}, force_lwp => 1 );
  $main::inbound = Thread::Queue->new();
  $main::outbound = Thread::Queue->new();
  # remove webhook
  #$main::api->setWebhook();
  print STDERR "@".$main::api->getMe()->{result}->{username}." is ready!\n";

  threads->create( \&recv_loop )->detach();
  threads->create( \&send_loop )->detach();
  # main loop
  while(defined ( my $message = $main::inbound->dequeue() )) {
    next unless grep { $message->{text} =~ /$_/l } @{ $main::CONFIG{KEYWORDS} };
    $main::outbound->enqueue({
        from_chat_id => $message->{chat}->{id},
        message_id   => $message->{message_id},
        chat_id      => $main::CONFIG{CHAT_ID},
        method       => 'forwardMessage'
      });
  }
}

sub recv_loop {
    my $offset = 0;
    while(1) {
        eval {
            my $updates = $main::api->getUpdates( { offset => $offset } );
            foreach my $update (@{$updates->{result}}) {
                $offset = $update->{update_id} + 1 unless $offset > $update->{update_id};
                next unless defined $update->{message};
                $main::inbound->enqueue( $update->{message} );
            }
        };
    }
}

sub send_loop {
    while (defined( my $message = $main::outbound->dequeue() )) {
        eval {
            my %m = (%$message);
            $m{method} ||= 'sendMessage';
            $main::api->api_request($m{method}, \%m );
        };
    }
}

sub clean_loop {
    # remove old ( > 24h ) data
    while(1) {
        eval {

        };
        sleep 10;
    }
}

