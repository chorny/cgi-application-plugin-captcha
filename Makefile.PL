# Note: this file was auto-generated by Module::Build::Compat version 0.03
use ExtUtils::MakeMaker;
WriteMakefile
(
          'PL_FILES' => {},
          'INSTALLDIRS' => 'site',
          'NAME' => 'CGI::Application::Plugin::CAPTCHA',
          'VERSION_FROM' => 'lib/CGI/Application/Plugin/CAPTCHA.pm',
          'PREREQ_PM' => {
                           'Test::More' => 0,
                           'CGI::Application' => '>= 4.00',
                           'GD::SecurityImage' => 0,
                           'Module::Build' => 0
                         }
        )
;
