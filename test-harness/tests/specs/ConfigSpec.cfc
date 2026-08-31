component extends="coldbox.system.testing.BaseTestCase" appMapping="root" {

	function beforeAll(){
		super.beforeAll();
		setup();
	}

	function run(){
		describe( "cbTypesense configuration", function(){
			it( "normalizes isolated named connections", function(){
				var config = new cbtypesense.models.Config().init( {
					defaultConnection : "search",
					connections       : {
						search : {
							nodes   : [ { protocol : "https", host : "search.internal", port : 443 } ],
							apiKey  : "search-key",
							retries : 1
						},
						indexer : {
							nodes   : [ { protocol : "http", host : "index.internal", port : 8108 } ],
							apiKey  : "index-key",
							retries : 0
						}
					}
				} );

				expect( config.getDefaultConnectionName() ).toBe( "search" );
				expect( config.getConnection( "search" ).apiKey ).toBe( "search-key" );
				expect( config.getConnection( "indexer" ).nodes[ 1 ].host ).toBe( "index.internal" );
			} );

			it( "rejects missing credentials without printing another key", function(){
				expect( function(){
					new cbtypesense.models.Config().init( {
						connections : {
							default : {
								nodes  : [ { protocol : "http", host : "127.0.0.1", port : 8108 } ],
								apiKey : ""
							}
						}
					} );
				} ).toThrow( type = "cbTypesense.ConfigurationException", regex = "requires an API key" );
			} );
		} );
	}

}
