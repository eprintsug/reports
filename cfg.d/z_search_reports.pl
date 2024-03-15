
$c->{search}->{report} = 
{
	search_fields => [
		{ meta_fields => [ "title" ] },
		{ meta_fields => [ "creators_name" ] },
		{ meta_fields => [ "date" ] },
		{ meta_fields => [ "subjects" ] },
		{ meta_fields => [ "type" ] },
		{ meta_fields => [ "divisions" ] },
		{ meta_fields => [ "publication" ] },
	],
	order_methods => {
		"byyear" 	 => "-date/creators_name/title",
		"byyearoldest"	 => "date/creators_name/title",
		"byname"  	 => "creators_name/-date/title",
		"bytitle" 	 => "title/creators_name/-date"
	},
	default_order => "byyear",
	show_zero_results => 1,
};

$c->{datasets}->{user}->{search}->{report} =
{
        search_fields => [
                { meta_fields => [ "name", ] },
                { meta_fields => [ "username", ] },
                { meta_fields => [ "userid", ] },
                { meta_fields => [ "dept","org" ] },
                { meta_fields => [ "address","country", ] },
                { meta_fields => [ "usertype", ] },
                { meta_fields => [ "email" ] },
        ],
        citation => "result",
        page_size => 20,
        order_methods => {
                "byname"         =>  "name/joined",
                "byjoin"         =>  "joined/name",
                "byrevjoin"      =>  "-joined/name",
                "bytype"         =>  "usertype/name",
        },
        default_order => "byname",
        show_zero_results => 1,
};

