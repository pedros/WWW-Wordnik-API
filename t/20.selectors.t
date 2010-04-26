#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 4;

BEGIN { use_ok( 'WWW::Wordnik::API' ); }
require_ok( 'WWW::Wordnik::API' );

my $Wn = WWW::Wordnik::API->new();

isa_ok($Wn, 'WWW::Wordnik::API');

{
  my $VAR1;
  eval join q{}, <DATA>;
  # need to delete code refs, since is_deeply only checks referents
  delete $VAR1->{_user_agent};
  delete $Wn->{_user_agent};

  is_deeply($Wn, $VAR1, 'Object creation');
}


__DATA__
$VAR1 = bless( {
        '_formats' => {
                       'perl' => 1,
                       'xml' => 1,
                       'json' => 1
                      },
        '_cache' => {
                     'count' => 0,
                     'requests' => {},
                     'last_request' => undef,
                     'max' => 10
                    },
        'server_uri' => 'http://api.wordnik.com/api-v3',
        'version' => '3',
        '_versions' => {
                        '1' => 0,
                        '3' => 1,
                        '2' => 0
                       },
        'api_key' => 'abcdefghijklmnopqrstuvxwyz',
        '_debug' => 0,
        '_user_agent' => bless( {
                                 'max_redirect' => 7,
                                 'protocols_forbidden' => undef,
                                 'show_progress' => undef,
                                 'handlers' => {
                                                'response_header' => bless( [
                                                                             {
                                                                              'owner' => 'LWP::UserAgent::parse_head',
                                                                              'callback' => sub { "DUMMY" },
                                                                              'm_media_type' => 'html',
                                                                              'line' => '/usr/share/perl5/LWP/UserAgent.pm:612'
                                                                             }
                                                                            ], 'HTTP::Config' )
                                               },
                                 'no_proxy' => [],
                                 'protocols_allowed' => undef,
                                 'local_address' => undef,
                                 'use_eval' => 1,
                                 'requests_redirectable' => [
                                                             'GET',
                                                             'HEAD'
                                                            ],
                                 'timeout' => 180,
                                 'def_headers' => bless( {
                                                          'user-agent' => 'Perl-WWW::Wordnik::API/0.0.1',
                                                          ':api_key' => 'abcdefghijklmnopqrstuvxwyz'
                                                         }, 'HTTP::Headers' ),
                                 'proxy' => {},
                                 'max_size' => undef
                                }, 'LWP::UserAgent' ),
        'format' => 'json',
        'cache' => 10
       }, 'WWW::Wordnik::API' );
