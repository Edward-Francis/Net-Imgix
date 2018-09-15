use strict;
use warnings;

use Test::Most;
use Net::Imgix ();
use URI;

# TEST DATA

my $domain1 = 'domain1.imgix.net';
my $domain2 = 'domain2.imgix.net';
my $domain3 = 'domain3.imgix.net';

# TEST HELPERS

sub _imgix_object {
    Net::Imgix->new(
        domains                   => [$domain1],
        sign_with_library_version => 0,
    );
}

sub _uri {
    URI->new( $_[0] );
}

sub _imgix_object_with_signature {
    Net::Imgix->new(
        domains                   => [$domain1],
        sign_with_library_version => 0,
        sign_key                  => 'secret',
    );
}

# TESTS

subtest 'instantiating a basic Net::Imgix object' => sub {

    my $imgix = Net::Imgix->new( domains => [$domain1] );
    isa_ok $imgix, 'Net::Imgix';

    cmp_deeply $imgix->domains, [$domain1],
        'set `domains` attribute correctly';

    is $imgix->shard_strategy, $imgix->SHARD_STRATEGY_CRC,
        'set attribute `shard_strategy`  to crc';

    ok $imgix->sign_with_library_version,
        'set attribute `sign_with_library_version` to true';

    ok $imgix->use_https, 'set attribute `use_https` to true';

    ok !$imgix->sign_key, 'set attribute `sign_key` to false';
};

subtest 'test url with path' => sub {
    my $imgix = _imgix_object;
    my $url   = $imgix->create_url('/image.png');
    is $url, "https://${domain1}/image.png", 'url created';
};

subtest 'create url with path and parameters' => sub {
    my $imgix = _imgix_object;
    my $url = $imgix->create_url( '/image.png', w => 400, h => 300 );
    is $url, "https://${domain1}/image.png?h=300&w=400", 'url created';
};

subtest 'test falsy query parameter' => sub {
    my $imgix = _imgix_object;
    my $url = $imgix->create_url( '/image.png', or => 0 );
    is $url, "https://${domain1}/image.png?or=0", 'url created';
};

subtest 'test signed url without parameters' => sub {
    my $imgix = _imgix_object_with_signature;
    my $url   = $imgix->create_url('/image.png');
    is $url,
        "https://${domain1}/image.png?s=db6e30d1a77a5a643396c4b57050e84a",
        'url created';
};

subtest 'test signed url with parameters' => sub {
    my $imgix = _imgix_object_with_signature;
    my $url = $imgix->create_url( 'image.png', w => 400, h => 300 );
    is $url,
        "https://${domain1}/image.png?h=300&w=400&s=fcef23c64daa62e31d3876ffc5e03b75",
        'url created';
};

subtest 'test UTF-8 characters in path' => sub {
    my $imgix = _imgix_object;
    my $url   = $imgix->create_url('/米.png');
    is $url, "https://${domain1}/%E7%B1%B3.png", 'url created';
};

subtest 'test https scheme' => sub {
    my $imgix = _imgix_object;
    my $url   = $imgix->create_url('/image.png');
    is _uri($url)->scheme, 'https', 'https scheme set';
};

subtest 'test http scheme' => sub {
    my $imgix = Net::Imgix->new( domains => [$domain1], use_https => 0 );
    my $url = $imgix->create_url('/image.png');
    is _uri($url)->scheme, 'http', 'http scheme set';
};

subtest 'test ixlib parameter added to query string' => sub {
    my $imgix    = Net::Imgix->new( domains => [$domain1] );
    my $url      = $imgix->create_url('/image.png');
    my $expected = 'ixlib=perl-Net%3A%3AImgix-' . $Net::Imgix::VERSION;
    is _uri($url)->query, $expected, 'ixlib parameter added to query string';
};

subtest 'test shard strategy - crc' => sub {
    my $i = Net::Imgix->new( domains => [ $domain1, $domain2 ], );
    is $i->domains->[0], _uri( $i->create_url('/a.png') )->host, 'crc host';
    is $i->domains->[0], _uri( $i->create_url('/a.png') )->host, 'crc host';
    is $i->domains->[0], _uri( $i->create_url('/b.png') )->host, 'crc host';
    is $i->domains->[0], _uri( $i->create_url('/b.png') )->host, 'crc host';
    is $i->domains->[1], _uri( $i->create_url('/1.png') )->host, 'crc host';
    is $i->domains->[1], _uri( $i->create_url('/1.png') )->host, 'crc host';
    is $i->domains->[1], _uri( $i->create_url('/2.png') )->host, 'crc host';
    is $i->domains->[1], _uri( $i->create_url('/2.png') )->host, 'crc host';
};

subtest 'test shard strategy - crc single domain' => sub {
    my $i = Net::Imgix->new( domains => [$domain1] );
    is $i->domains->[0], _uri( $i->create_url('/1.png') )->host, 'crc host';
    is $i->domains->[0], _uri( $i->create_url('/1.png') )->host, 'crc host';
    is $i->domains->[0], _uri( $i->create_url('/2.png') )->host, 'crc host';
    is $i->domains->[0], _uri( $i->create_url('/2.png') )->host, 'crc host';
};

subtest 'test shard strategy - cycle' => sub {
    my $domains = [ $domain1, $domain2, $domain3 ];
    my $i = Net::Imgix->new( domains => $domains, shard_strategy => 'cycle' );
    is $i->domains->[0], _uri( $i->create_url('/1.png') )->host, 'cycle host';
    is $i->domains->[1], _uri( $i->create_url('/1.png') )->host, 'cycle host';
    is $i->domains->[2], _uri( $i->create_url('/1.png') )->host, 'cycle host';
    is $i->domains->[0], _uri( $i->create_url('/a.png') )->host, 'cycle host';
    is $i->domains->[1], _uri( $i->create_url('/b.png') )->host, 'cycle host';
    is $i->domains->[2], _uri( $i->create_url('/c.png') )->host, 'cycle host';
};

subtest 'test shard strategy - cycle single domain' => sub {
    my $domains = [$domain1];
    my $i = Net::Imgix->new( domains => $domains, shard_strategy => 'cycle' );
    is $i->domains->[0], _uri( $i->create_url('/1.png') )->host, 'cycle host';
    is $i->domains->[0], _uri( $i->create_url('/1.png') )->host, 'cycle host';
    is $i->domains->[0], _uri( $i->create_url('/1.png') )->host, 'cycle host';
    is $i->domains->[0], _uri( $i->create_url('/a.png') )->host, 'cycle host';
    is $i->domains->[0], _uri( $i->create_url('/b.png') )->host, 'cycle host';
    is $i->domains->[0], _uri( $i->create_url('/c.png') )->host, 'cycle host';
};

subtest 'test invalid strategy' => sub {
    throws_ok {
        Net::Imgix->new(
            domains        => [$domain1],
            shard_strategy => 'invalid'
            )
    }
    qr!Attribute \(shard_strategy\) does not pass!,
        'invalid shard_strategy thrown';
};

done_testing;
