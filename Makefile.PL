use inc::Module::Install;

# Define metadata
name 'Net-Stripe';
perl_version '5.10.1';
all_from 'lib/Net/Stripe.pm';

# Specific dependencies
requires 'DateTime'              => 0;
requires 'perl'                  => v5.10.1;
requires 'Moose'                 => '2.0602';
requires 'methods'               => 0;
requires 'LWP::UserAgent'        => 0;
requires 'LWP::Protocol::https'  => 0;
requires 'HTTP::Request::Common' => 0;
requires 'MIME::Base64'          => 0;
requires 'URI::Escape'           => 0;
requires 'JSON'                  => 0;
requires 'Test::Exception'       => 0;
requires 'Throwable'             => 0;
requires 'namespace::clean'      => 0;
requires 'MooseX::Clone'         => 0;

WriteAll;
