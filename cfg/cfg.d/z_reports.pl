#
# EPrints Services - Generic Reporting System
#
# Version: 3.0
#


$c->{plugins}{"Screen::Report"}{params}{disable} = 0;

$c->{plugins}{"Export::Report"}{params}{disable} = 0;
$c->{plugins}{"Export::Report::CSV"}{params}{disable} = 0;
$c->{plugins}{"Export::Report::JSON"}{params}{disable} = 0;
$c->{plugins}{"Export::Report::HTML"}{params}{disable} = 0;

$c->{plugins}{"Screen::Report::EPrint"}{params}{disable} = 0;
$c->{plugins}{"Screen::Report::EPrint"}{params}{custom} = 1;
$c->{plugins}{"Screen::Report::User"}{params}{disable} = 0;
$c->{plugins}{"Screen::Report::User"}{params}{custom} = 1;

#set config for default eprint report
$c->{search}->{eprint_report} = $c->{search}->{advanced}; #use the advanced search form as the default eprint report search

#group by options
$c->{eprint_report}->{groupfields} = [ qw(
	divisions
	subjects
        type
	date;res=year;reverse_order=1
)];

#sort options for sorting within each group
$c->{eprint_report}->{sortfields} = {
        "byname" => "creators_name/-date/title",
        "byyear" => "-date/creators_name/title",
        "bytitle" => "title/creators_name/-date",
        "bydivision" => "divisions/creators_name/-date",
};

#export field options
$c->{eprint_report}->{exportfields} = {
        eprint_report_core => [ qw(
		eprintid
                title
                creators_name
                abstract
                date
                keywords
                divisions
                subjects
                type
                editors_name
                ispublished
                refereed
                publication
                documents.format
                datestamp
        )],
};
$c->{eprint_report}->{exportfield_defaults} = [ qw(
	eprintid
	title
        creators_name
        abstract
        date
        keywords
        divisions
        subjects
        type
        editors_name
        ispublished
        refereed
        publication
	documents.format
	datestamp
)];

#set order of export plugins
$c->{eprint_report}->{export_plugins} = [ qw( Export::Report::CSV Export::Report::HTML Export::Report::JSON )];

#set config for default user report
$c->{datasets}->{user}->{search}->{user_report} = $c->{search}->{user}; #use the default user search form

#sort options for sorting within each group
$c->{user_report}->{sortfields} = {
        "byname" => "name",
};

#export field options
$c->{user_report}->{exportfields} = {
        user_report_core => [ qw(
        	name
		username
		userid
		dept
		org
		address
		usertype
		email
	)],
};

$c->{user_report}->{exportfield_defaults} = [ qw(
        name
	username
	userid
	dept
	org
	address
	usertype
	email
)];

#set order of export plugins
$c->{user_report}->{export_plugins} = [ qw( Export::Report::CSV Export::Report::HTML Export::Report::JSON )];

push @{$c->{user_roles}->{admin}}, qw{
        +report
};
