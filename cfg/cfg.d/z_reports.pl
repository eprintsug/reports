#
# EPrints Services - Generic Reporting System
#
# Version: 0.1
#


$c->{plugins}{"Screen::Report"}{params}{disable} = 0;

$c->{plugins}{"Export::Report"}{params}{disable} = 0;
$c->{plugins}{"Export::Report::CSV"}{params}{disable} = 0;


push @{$c->{user_roles}->{admin}}, qw{
        +report
};

