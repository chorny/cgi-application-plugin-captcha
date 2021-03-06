package CGI::Application::Plugin::CAPTCHA;

use strict;

use GD::SecurityImage;
use vars qw($VERSION @EXPORT);

require Exporter;

@EXPORT = qw(
    captcha_config
    captcha_create
    captcha_verify
);

sub import { goto &Exporter::import }

=head1 NAME

CGI::Application::Plugin::CAPTCHA - Easily create, use, and verify CAPTCHAs in
CGI::Application-based web applications.

=head1 VERSION

Version 0.01

=cut

$VERSION = '0.01';

=head1 SYNOPSIS

    # In your CGI::Application-based web application module. . .
    use CGI::Application::Plugin::CAPTCHA;

    sub setup
    {
        my $self = shift;

        $self->run_modes([ qw/
            create
            # Your other run modes go here
        /]);

        $self->captcha_config(
            IMAGE_OPTIONS    => {
                width    => 150,
                height   => 40,
                lines    => 10,
                font     => "/Library/Fonts/Arial",
                ptsize   => 18,
                bgcolor  => "#FFFF00",
            },
            CREATE_OPTIONS   => [ 'ttf', 'rect' ],
            PARTICLE_OPTIONS => [ 300 ],
        );
    }

    # Create a run mode that calls the CAPTCHA creation method...
    sub create 
    {
        my $self = shift;
        return $self->captcha_create;
    }
    
    # In a template far, far away. . . 
    <img src="/delight/Ident/create"> (to generate a CAPTCHA image)

    # Back in your application, to verify the CAPTCHA...
    sub some_other_runmode
    {
        my $self    = shift;
        my $request = $self->query;
        
        return unless $self->captcha_verify($request->cookie("hash"), $request->param("verify"));
    }

=head1 DESCRIPTION

C<CGI::Application::Plugin::CAPTCHA> allows programmers to easily add and 
verify CAPTCHAs in their CGI::Application-derived web applications.

A CAPTCHA (or Completely Automated Public Turing Test to Tell Computers 
and Humans Apart) is an image with a random string of characters.  A user must 
successfully enter the random string in order to submit a form.  This is a 
simple (yet annoying) procedure for humans to complete, but one that is 
significantly more difficult for a form-stuffing script to complete without 
having to integrate some sort of OCR.

CAPTCHAs are not a perfect solution.  Any skilled, diligent cracker will 
eventually be able to bypass a CAPTCHA, but it should be able to shut down
your average script-kiddie.

C<CGI::Application::Plugin::CAPTCHA> is a wrapper for L<GD::SecurityImage>.  It
makes it more convenient to access L<GD::SecurityImage> functionality, and 
gives a more L<CGI::Application>-like way of doing it.

When a CAPTCHA is created with this module, raw image data is transmitted from
your web application to the client browser.  A cookie containing an encrypted 
hash is also transmitted with the image.  When the client submits their form 
for processing (along with their verification of the random string), 
C<captcha_verify()> encrypts the verification string with the same salt used
to encrypt the hash sent in the cookie.  If the newly encrypted string matches
the original encrypted hash, we trust that the CAPTCHA has been successfully
entered, and we allow the user to continue processing their form.

The author recognizes that the transmission of a cookie with the CAPTCHA image
may not be a popular decision, and welcomes any patches from those who can
provide an equally easy-to-implement solution.

=head1 FUNCTIONS

=head2 captcha_config()

This method is used to customize how new CAPTCHA images will be created.  
Values specified here are passed along to the appropriate functions in 
L<GD::SecurityImage> when a new CAPTCHA is created.

It is recommended that you call C<captcha_config()> in the C<cgiapp_init()>
method of your CGI::Application base class, and in the C<setup()> method of
any derived applications.

The following parameters are currently accepted:

=head3 IMAGE_OPTIONS

This specifies what options will be passed to the constructor of 
L<GD::SecurityImage>.  Please see the documentation for L<GD::SecurityImage>
for more information.

=head3 CREATE_OPTIONS

This specifies what options will be passed to the C<create()> method of 
L<GD::SecurityImage>.  Please see the documentation for L<GD::SecurityImage>
for more information.

=head3 PARTICLE_OPTIONS

This specifies what options will be passed to the C<particle()> method of
L<GD::SecurityImage>.  Please see the documentation for L<GD::SecurityImage>
for more information.

=cut

sub captcha_config
{
    my $self = shift;

    if (@_) 
    {
        my $props;
        if (ref($_[0]) eq 'HASH') 
        {
            my $rthash = %{$_[0]};
            $props = $self->_cap_hash($_[0]);
        } 
        else 
        {
            $props = $self->_cap_hash({ @_ });
        }

        # Check for IMAGE_OPTIONS
        if ($props->{IMAGE_OPTIONS}) 
        {
            die "captcha_config() error:  parameter IMAGE_OPTIONS is not a hash reference" if ref $props->{IMAGE_OPTIONS} ne 'HASH';
            $self->{__CAP__CAPTCHA_CONFIG}->{IMAGE_OPTIONS} = delete $props->{IMAGE_OPTIONS};
        }

        # Check for CREATE_OPTIONS
        if ($props->{CREATE_OPTIONS}) 
        {
            die "captcha_config() error:  parameter CREATE_OPTIONS is not an array reference" if ref $props->{CREATE_OPTIONS} ne 'ARRAY';
            $self->{__CAP__CAPTCHA_CONFIG}->{CREATE_OPTIONS} = delete $props->{CREATE_OPTIONS};
        }

        # Check for PARTICLE_OPTIONS
        if ($props->{PARTICLE_OPTIONS}) 
        {
            die "captcha_config() error:  parameter PARTICLE_OPTIONS is not an array reference" if ref $props->{PARTICLE_OPTIONS} ne 'ARRAY';
            $self->{__CAP__CAPTCHA_CONFIG}->{PARTICLE_OPTIONS} = delete $props->{PARTICLE_OPTIONS};
        }

        # Check for DEBUG
        if ($props->{DEBUG}) 
        {
            $self->{__CAP__CAPTCHA_CONFIG}->{DEBUG} = delete $props->{DEBUG};
        }

        # If there are still entries left in $props then they are invalid
        die "Invalid option(s) (".join(', ', keys %$props).") passed to captcha_config" if %$props;
    }

    $self->{__CAP__CAPTCHA_CONFIG};
}

=head2 captcha_create()

Creates the CAPTCHA image, and return a cookie with the encrypted hash of the
random string.  Takes no arguments.  

The cookie created in this method is named C<hash>, and contains only the 
encrypted hash.  Future versions of this module will allow you to specify
cookie options in greater detail.

=cut

sub captcha_create
{
    my $self             = shift;
    my %image_options    = %{ $self->{__CAP__CAPTCHA_CONFIG}->{ IMAGE_OPTIONS    } }; 
    my @create_options   = @{ $self->{__CAP__CAPTCHA_CONFIG}->{ CREATE_OPTIONS   } }; 
    my @particle_options = @{ $self->{__CAP__CAPTCHA_CONFIG}->{ PARTICLE_OPTIONS } }; 
    my $debug            = $self->{__CAP__CAPTCHA_CONFIG}->{ DEBUG } ;

    # Create the CAPTCHA image
    my $image = GD::SecurityImage->new( %image_options );
    $debug == 1 ? $image->random("ABC123") : $image->random;
    $image->create  ( @create_options   );
    $image->particle( @particle_options );
    my ( $image_data, $mime_type, $random_string ) = $image->out;

    # Create the verification hash
    use Data::Random qw(:all);
    my $salt = rand_chars( set => 'alphanumeric', size => 6);
    my $hash = crypt($random_string, $salt);
    
    # Stuff the verification hash in a cookie and push it out to the 
    # client.
    my $cookie = $self->query->cookie("hash" => $hash);
    $self->header_type ( 'header' );
    $self->header_props( -type => $mime_type, -cookie => [ $cookie ] );
    return $image_data;
}

=head2 captcha_verify()

Verifies that the value entered by the user matches what was in the CAPTCHA
image.  Argument 1 is the encrypted hash from the cookie sent by 
C<captcha_create()>, and argument 2 is the value the user entered to verify
the CAPTCHA image.  Returns true if the CAPTCHA was successfully verified, else
returns false.

=cut

sub captcha_verify
{
    my ($self, $hash, $verify) = @_;

    my $salt = substr($hash, 0, 2);
    return 1 if crypt($verify, $salt) eq $hash;
    return 0;
}

=head1 AUTHOR

Jason A. Crome, C<< <cromedome@cpan.org> >>

=head1 TODO

=over 4

=item *

Allow C<captcha_config()> to take cookie configuration arguments.

=item *

Allow the plugin to actually create a run mode in your CGI::Application-based
webapp without the developer having to manually create one.

=back

=head1 BUGS

Please report any bugs or feature requests to
C<bug-cgi-application-plugin-captcha@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CGI-Application-Plugin-CAPTCHA>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 CONTRIBUTING

Patches, questions, and feedback are welcome.

=head1 ACKNOWLEDGEMENTS

A big thanks to Cees Hek for providing a great module for me to borrow code 
from (L<CGI::Application::Plugin::Session>), to Michael Peters and Tony Fraser
for all of their valuable input, and to the rest who contributed ideas and
criticisms on the CGI::Application mailing list.

=head1 SEE ALSO

L<CGI::Application>
L<GD::SecurityImage>
Wikipedia entry for CAPTCHA - L<http://en.wikipedia.org/wiki/Captcha>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Jason A. Crome, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of CGI::Application::Plugin::CAPTCHA

