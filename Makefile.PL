use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'         => 'Net::SCP::Expect',
    'VERSION_FROM' => 'Net/SCP/Expect.pm',
    'PREREQ_PM'    => {'Expect' => '1.14'},
    'AUTHOR'       => 'Daniel J. Berger <djberg96@yahoo.com>',
);
