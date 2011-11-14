use inc::Module::Install;

# Define metadata
name 'Net-Stripe';
perl_version '5.10.1';
all_from 'lib/Net/Stripe.pm';

# Specific dependencies
requires 'perl'                  => v5.10.1;
requires 'Moose'                 => 0;
requires 'methods'               => 0;
requires 'LWP::UserAgent'        => 0;
requires 'LWP::Protocol::https'  => 0;
requires 'HTTP::Request::Common' => 0;
requires 'MIME::Base64'          => 0;
requires 'URI::Escape'           => 0;
requires 'JSON'                  => 0;
requires 'Throwable'             => 0;

WriteAll;
