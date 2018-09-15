package Net::Imgix;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

# IMPORTS

use URI             ();
use URI::QueryParam ();
use Compress::Zlib  ();
use Digest::MD5     ();


# VERSION

our $VERSION = '0.01';


# CONSTANTS

use constant SHARD_STRATEGY_CRC   => 'crc';
use constant SHARD_STRATEGY_CYCLE => 'cycle';


=head1 NAME

Net::Imgix - client library for generating Imgix URLs

=head1 SYNOPSIS

FIXME:

=head1 DESCRIPTION

# FIXME

=head1 ATTRIBUTES

=over

=item domains

=item use_https

=item sign_key

=item shard_strategy

=item sign_with_library_version

=back

=cut

has 'domains' => (
    is       => 'ro',
    isa      => 'ArrayRef[Str]',
    required => 1,
);

has 'use_https' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

has 'sign_key' => (
    is  => 'ro',
    isa => 'Str',
);

has 'shard_strategy' => (
    is      => 'ro',
    default => +SHARD_STRATEGY_CRC,
    isa     => subtype(
        as 'Str',
        where {
            m{^(crc|cycle)$};
        }
    ),
);

has 'sign_with_library_version' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

# PRIVATE ATTRIBUTES

has '_cycle_index' => (
    is       => 'rw',
    isa      => 'Int',
    default  => 0,
    init_arg => undef,
);

=head1 METHODS

=head2 create_url

=cut

sub create_url {
    my ( $self, $path, %args ) = @_;

    my $domain;
    my $domains     = $self->domains;
    my $domain_size = scalar @{$domains};

    # choose domain based on crc shard strategy
    if ( $self->shard_strategy eq +SHARD_STRATEGY_CRC ) {
        my $crc = Compress::Zlib::crc32($path);
        $domain = $domains->[ $crc % $domain_size ];
    }

    # choose domain based on cycle shard strategy
    elsif ( $self->shard_strategy eq +SHARD_STRATEGY_CYCLE ) {
        $domain = $self->domains->[ $self->_cycle_index ];
        $self->_cycle_index( ( $self->_cycle_index + 1 ) % $domain_size );
    }

    my $uri = URI->new("https://$domain");
    $uri->path($path);
    $uri->scheme('http') unless $self->use_https;
    $uri->query_param( $_ => $args{$_} ) for sort keys %args;

    # add the library and version to ixlib query parameter
    if ( $self->sign_with_library_version ) {
        $uri->query_param(
            ixlib => sprintf 'perl-%s-%s',
            __PACKAGE__, $VERSION
        );
    }

    # sign the URL if required
    if ( my $sign_key = $self->sign_key ) {
        my $signature = Digest::MD5::md5_hex( $sign_key . $uri->path_query );
        $uri->query_param( s => $signature );
    }

    return $uri->as_string;
}

=head1 AUTHOR

Edward Francis, C<edwardafrancis@gmail.com>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-imgix at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Imgix>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Imgix


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-Imgix>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-Imgix>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Net-Imgix>

=item * Search CPAN

L<https://metacpan.org/release/Net-Imgix>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2018 Edward Francis.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1;
