package WWW::Wordnik::API;

use warnings;
use strict;
use Carp;

use LWP::UserAgent;

use version; our $VERSION = qv('0.0.1');
             our $AUTOLOAD;

use constant {
    API_VERSION  => '3',
    API_BASE_URL => 'http://api.wordnik.com',
    API_KEY      => 'abcdefghijklmnopqrstuvxwyz',
    API_FORMAT   => 'json',
    MODULE_NAME  => 'WWW::Wordnik::API',
    DEBUG        => 0,
    CACHE        => 10,
};

my $fields = {
              server_uri  => API_BASE_URL . q{/api-v} . API_VERSION,
              api_key     => API_KEY,
              version     => API_VERSION,
              format      => API_FORMAT,
              cache       => CACHE,
              _user_agent => LWP::UserAgent->new(
                                                 agent           => 'Perl-' . MODULE_NAME . q{/} . $VERSION,
                                                 default_headers => HTTP::Headers->new(':api_key' => API_KEY),
                                                ),
              _formats    => {json => 1, xml => 1, perl => 1},
              _versions   => {1    => 0, 2   => 0, 3    => 1},
              _debug      => DEBUG,
              _cache      => {count => 0, max => CACHE, last_request => undef, requests => {}},
             };

sub new {
    my ($class, %args) = @_;

    bless $fields, $class;

    while (my ($key, $value) = each %args) {
      croak "Can't access '$key' field in class $class"
        if !exists $fields->{$key} or $key =~ m/^_/;

      $fields->$key($value);
    }

    return $fields;
}

sub server_uri {
    my ($self, $uri) = @_;

    if (defined $uri) {
      return $self->{server_uri} = $uri;
    }
    else {
      return $self->{server_uri};
    }
}

sub api_key {
    my ($self, $key) = @_;

    if (defined $key) {
      return $self->{api_key} = $key;
    }
    else {
      return $self->{api_key};
    }
}

sub version {
    my ($self, $version) = @_;

    if (defined $version) {
      croak "Unsupported version $version"
        unless $self->{_versions}->{$version};
      return $self->{version} = $version;
    }
    else {
      return $self->{version};
    }
}

sub format {
    my ($self, $format) = @_;

    if (defined $format) {
      croak "Unsupported format $format"
        unless $self->{_formats}->{$format};

      if ('perl' eq $format) {
          eval {require JSON; JSON->import()};
          croak qq(Use of 'perl' as an output format requires JSON to be installed:\n$@)
              if $@;
      }

      return $self->{format} = $format;
    }
    else {
      return $self->{format};
    }
}

sub cache {
    my ($self, $cache) = @_;

    if (defined $cache and $cache =~ m/\d+/) {
      return $self->{cache} = $cache;
    }
    else {
      return $self->{cache};
    }
}

sub word {
    my ($self, $word, %args) = @_;

    return unless $word;

    my %parameters = (useSuggest => {true => 0, false => 1},
                      literal    => {true => 1, false => 0},
                     );

    for (keys %args) {
      croak 'Invalid argument key or value' unless exists $parameters{$_}
        and exists $parameters{$_}->{$args{$_}};
    }

    my $request = $word;
    $request   .= "?$_=$args{$_}" for keys %args;

    return
      $self->_get_request ($self->server_uri . '/word.' . ('perl' eq $self->format ? 'json' : $self->format) . "/$request");
}

sub phrases {
    my ($self, $word, %args) = @_;

    return unless $word;

    my %parameters = (count => 10);

    for (keys %args) {
      croak 'Invalid argument key or value' unless exists $parameters{$_}
        and $args{$_} =~ m/\d+/;
    }

    my $request = "$word/phrases";
    $request   .= "?$_=$args{$_}" for keys %args;

    return
      $self->_get_request ($self->server_uri . '/word.' . ('perl' eq $self->format ? 'json' : $self->format) . "/$request");
}

sub definitions {
    my ($self, $word, %args) = @_;

    return unless $word;

    my %parameters = (count        => 5,
                      partOfSpeech => {
                                       noun         => 0,
                                       verb         => 0,
                                       adjective    => 0,
                                       adverb       => 0,
                                       idiom        => 0,
                                       article      => 0,
                                       abbreviation => 0,
                                       preposition  => 0,
                                       prefix       => 0,
                                       interjection => 0,
                                       suffix       => 0,
                                      }
                     );

    my $request = "$word/definitions";

    for (keys %args) {

      if ('count' eq $_) {
        croak 'Invalid argument key or value' unless $args{count} =~ m/\d/;
        $request .= "?count=$args{count}";
      }
      elsif ('ARRAY' eq ref $args{partOfSpeech}) {
        for my $type (@{$args{partOfSpeech}}) {
          croak 'Invalid argument key or value' unless exists $parameters{partOfSpeech}->{$type};
        }
        $request .= "?partOfSpeech=" . join q{,}, @{$args{partOfSpeech}};
      }
      else {
        croak 'Parameter "partOfSpeech" requires a reference to an array';
      }
    }

    return
      $self->_get_request ($self->server_uri . '/word.' . ('perl' eq $self->format ? 'json' : $self->format) . "/$request");
}

sub examples {
    my ($self, $word) = @_;

    return unless $word;

    my $request = "$word/examples";

    return
      $self->_get_request ($self->server_uri . '/word.' . ('perl' eq $self->format ? 'json' : $self->format) . "/$request");
}

sub related {
    my ($self, $word, %args) = @_;

    return unless $word;

    my %parameters = (type => {
                               synonym    => 0,
                               antonym    => 0,
                               form       => 0,
                               equivalent => 0,
                               hypoynm    => 0,
                               variant    => 0,
                              },
                     );

    my $request = "$word/related";

    if ('ARRAY' eq ref $args{type}) {
      for my $type (@{$args{type}}) {
        croak 'Invalid argument key or value' unless exists $parameters{type}->{$type};
      }
      $request .= "?type=" . join q{,}, @{$args{type}};
    }
    else {
      croak 'Parameter "type" requires a reference to an array';
    }
  
    return
      $self->_get_request ($self->server_uri . '/word.' . ('perl' eq $self->format ? 'json' : $self->format) . "/$request");
}

sub frequency {
    my ($self, $word) = @_;

    return unless $word;

    my $request = "$word/frequency";

    return
      $self->_get_request ($self->server_uri . '/word.' . ('perl' eq $self->format ? 'json' : $self->format) . "/$request");
}

sub punctuationFactor {
    my ($self, $word) = @_;

    return unless $word;

    my $request = "$word/punctuationFactor";

    return
      $self->_get_request ($self->server_uri . '/word.' . ('perl' eq $self->format ? 'json' : $self->format) . "/$request");
}

sub suggest {
    my ($self, $word, %args) = @_;

    return unless $word;

    my %parameters = (
                      count   => 10,
                      startAt => 0,
                     );

    for (keys %args) {
      croak 'Invalid argument key or value' unless exists $parameters{$_}
        and $args{$_} =~ m/\d+/;
    }

    my $request = "$word";
    $request   .= "?$_=$args{$_}" for keys %args;

    return
      $self->_get_request ($self->server_uri . '/suggest.' . ('perl' eq $self->format ? 'json' : $self->format) . "/$request");
}

sub wordoftheday {
    my ($self) = @_;

    return
      $self->_get_request ($self->server_uri . '/wordoftheday.' . ('perl' eq $self->format ? 'json' : $self->format));
}

sub randomWord {
    my ($self, %args) = @_;

    my %parameters = (hasDictionaryDef => {true => 0, false => 1},);

    for (keys %args) {
      croak 'Invalid argument key or value' unless exists $parameters{$_}
        and exists $parameters{$_}->{$args{$_}};
    }

    my $request = "randomWord";
    $request   .= "?$_=$args{$_}" for keys %args;

    return
      $self->_get_request ($self->server_uri . '/words.' . ('perl' eq $self->format ? 'json' : $self->format) . "/$request");
}


sub _get_request {
    my ($self, $request) = @_;

    return $request if $self->{_debug};

    if ($self->cache and exists $self->{_cache}->{requests}->{$request}) {
        return $self->{_cache}->{requests}->{$request};
    }
    else {
        my $data = $self->{_user_agent}->get($request)->content;
        $data    = from_json($data) if 'perl' eq $self->format;

        return $self->_cache_data ($request, $data);
    }
}

sub _cache_data {
    my ($self, $request, $data) = @_;

    my $c = $self->{_cache};

    if ($c->{count} and $c->{count} >= $c->{max}) {
        delete $c->{requests}->{$c->{last_request}};
        $c->{count}--;
    }

    $c->{last_request} = $request;
    $c->{count}++;

    return $c->{requests}->{$request} = $data;
}


1; # Magic true value required at end of module
__END__

=head1 NAME

WWW::Wordnik::API - Wordnik API implementation

=head1 VERSION

This document describes WWW::Wordnik::API version 0.0.1


=head1 SYNOPSIS

    use WWW::Wordnik::API;

    my $WN = WWW::Wordnik::API->new();
    $WN->api_key('your api key here');

    ### OR

    my $WN = WWW::Wordnik::API->new(api_key => 'your api key here');

    $WN->word('bollocks');
    $WN->phrases('bollocks');


=head1 DESCRIPTION

Write a full description of the module and its features here.
Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 


=head2 CLASS METHODS

=over

=item new(%args)

    my %args = (
        server_uri => 'http://api.wordnik.com/api-v3',
        api_key    => 'your key',
        version    => '3',
        format     => 'json', # json | xml | perl
    );

    my $WN = WWW::Wordnik::API->new(%args);

=back


=head2 SELECTOR METHODS

All selector methods can be assigned to, or retrieved from, as follows:

    $WN->method($value) # assign
    $WN->method        # retrieve

=over

=item server_uri()

=item server_uri($uri)

Default C<$uri>: L<http://api.wordnik.com/api-v3>


=item api_key()

=item api_key($key)

Required C<$key>: Your API key, which can be requested at L<http://api.wordnik.com/signup/>.


=item version()

=item version($version)

Default C<$version>: I<3>. Only API version 3 (the latest) is currently supported.


=item format()

=item format($format)

Default C<$format>: I<json>. Other accepted formats are I<xml> and I<perl>.


=item cache()

=item cache($cache)

Default C<$cache>: I<10>. Number of requests to cache. Deletes the latest one if cache fills up.

=back


=head2 OBJECT METHODS

=over

=item word($word, %args)

This returns the word you requested, assuming it is found in our corpus.
See L<http://docs.wordnik.com/api/methods#words>.

C<$word> is the word to look up. C<%args> accepts:

Default C<useSuggest>: I<false>. Return an array of suggestions, if available.

Default C<literal>: I<true>. Return non-literal matches.

If the suggester is enabled, you can tell it to return the best match with C<useSuggest=true> and C<literal=false>.


=item phrases($word, %args)

You can fetch interesting bi-gram phrases containing a word.
The “mi” and “wlmi” elements refer to “mutual information” 
and “weighted mutual information” and will be explained in detail via future blog post.
See L<http://docs.wordnik.com/api/methods#phrases>.

C<$word> is the word to look up. C<%args> accepts:

Default C<count>: I<5>. Specify the number of results returned.


=item definitions($word, %args)

Definitions for words are available from Wordnik’s keying of the Century Dictionary and parse of the Webster GCIDE.
The Dictionary Model XSD is available in L<http://github.com/wordnik/api-examples/blob/master/docs/dictionary.xsd> in GitHub.
See L<http://docs.wordnik.com/api/methods#definitions>.

C<$word> is the word to look up. C<%args> accepts:

Default C<count>: I<5>. Specify the number of results returned.

Default C<partOfSpeech>: I<empty>. Specify one or many part-of-speech types for which to return definitions. Pass multiple types as an array reference.

The available partOfSpeech values are:

    [noun, verb, adjective, adverb, idiom, article, abbreviation, preposition, prefix, interjection, suffix]


=item examples($word)

You can retrieve 5 example sentences for a words in Wordnik’s alpha corpus. Each example contains the source document and a source URL, if it exists.
See L<http://docs.wordnik.com/api/methods#examples>.

C<$word> is the word to look up.


=item related($word, %args)

You retrieve related words for a particular word.
See L<http://docs.wordnik.com/api/methods#relateds>.

C<$word> is the word to look up. C<%args> accepts:

Default C<type>: I<empty>. Return one or many relationship types. Pass multiple types as an array reference.

The available type values are:

    [synonym, antonym, form, equivalent, hyponym, variant]


=item frequency($word)

You can see how common particular words occur in Wordnik’s alpha corpus, ordered by year.
See L<http://docs.wordnik.com/api/methods#freq>.

C<$word> is the word to look up.


=item punctuationFactor($word)

You can see how common particular words are used with punctuation.
See L<http://docs.wordnik.com/api/methods#punc>.

C<$word> is the word to look up.


=item suggest($word, %args)

The autocomplete service gives you the opportunity to take a word fragment (start of a word) and show what other words start with the same letters.
The results are based on corpus frequency, not static word lists, so you have access to more dynamic words in the language.
See L<http://docs.wordnik.com/api/methods#auto>.

C<$word> is the word to look up. C<%args> accepts:

Default C<count>: I<5>. Specify the number of results returned.

Default C<startAt>: I<0>. You can also specify the starting index for the results returned. This allows you to paginate through the matching values.


=item wordoftheday

You can fetch Wordnik’s word-of-the day which contains definitions and example sentences.
See L<http://docs.wordnik.com/api/methods#wotd>.


=item randomWord(%args)

You can fetch a random word from the Alpha Corpus.
See L<http://docs.wordnik.com/api/methods#random>.

C<%args> accepts:

Default C<hasDictionaryDef>: I<true>. You can ask the API to return only words where there is a definition available.

=back


=head1 INSTALLATION

To install this module type the following:

   perl Build.PL
   Build
   Build test
   Build install

or

   perl Makefile.PL
   make
   make test
   make install


=head1 DIAGNOSTICS

    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

WWW::Wordnik::API requires no configuration files or environment variables.


=head1 DEPENDENCIES

This module requires the core modules L<Test::More>, L<version> and L<Carp>, and L<LWP::UserAgent> from C<CPAN>.
Additionally, it recommends-requires L<JSON> from C<CPAN> for getting data in Perl data structures.


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-www-wordnik-api@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Pedro Silva  C<< <pedros@berkeley.edu> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2010, Pedro Silva C<< <pedros@berkeley.edu> >>. All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see L<http://www.gnu.org/licenses/>.
