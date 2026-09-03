component extends="coldbox.system.testing.BaseTestCase" appMapping="root" {

	function beforeAll(){
		super.beforeAll();
		setup();
	}

	function run(){
		describe( "Typesense 29.0 live contract", function(){
			it( "completes the health, schema, index, search, key, operations, and cleanup journey", function(){
				var typesenseClient = liveClient( "cbtypesense-live-test-key" );
				try {
					expect(
						typesenseClient
							.operations()
							.health()
							.getData()
							.ok
					).toBeTrue();
				} catch ( any unavailable ) {
					if ( createObject( "java", "java.lang.System" ).getenv( "TYPESENSE_LIVE_REQUIRED" ) == "true" ) {
						rethrow;
					}
					return skip( "Typesense live service is not running on port 18108." );
				}

				var suffix         = lCase( replace( createUUID(), "-", "", "all" ) );
				var collectionName = "cbtypesense_#suffix#";
				var aliasName      = "cbtypesense_alias_#suffix#";
				var createdKeyId   = 0;
				try {
					var schema = deserializeJSON(
						"{""name"":""#collectionName#"",""fields"":[{""name"":""name"",""type"":""string""},{""name"":""organizationId"",""type"":""string"",""facet"":true}]}"
					);
					expect(
						typesenseClient
							.collections()
							.create( schema )
							.getData()
							.name
					).toBe( collectionName );

					var firstDocument  = deserializeJSON( "{""id"":""1"",""name"":""Blue Costume"",""organizationId"":""org-1""}" );
					var secondDocument = deserializeJSON( "{""id"":""2"",""name"":""Red Prop"",""organizationId"":""org-2""}" );
					typesenseClient.documents( collectionName ).upsert( firstDocument );
					expect(
						typesenseClient
							.documents( collectionName )
							.retrieve( "1" )
							.getData()
							.name
					).toBe( "Blue Costume" );

					var importResult = typesenseClient
						.documents( collectionName )
						.importDocuments(
							documents = [
								secondDocument,
								deserializeJSON( "{""id"":""invalid"",""organizationId"":""org-1""}" )
							],
							action = "upsert"
						);
					expect( importResult.getSucceededCount() ).toBe( 1 );
					expect( importResult.getFailedCount() ).toBe( 1 );

					var search = typesenseClient.search(
						collectionName,
						deserializeJSON( "{""q"":""costume"",""query_by"":""name"",""facet_by"":""organizationId"",""filter_by"":""organizationId:=org-1""}" )
					);
					expect( search.found() ).toBe( 1 );
					expect( search.facetCounts() ).toHaveLength( 1 );

					var multiSearch = typesenseClient.multiSearch( [
						deserializeJSON( "{""collection"":""#collectionName#"",""q"":""blue"",""query_by"":""name""}" ),
						deserializeJSON( "{""collection"":""#collectionName#"",""q"":""red"",""query_by"":""name""}" )
					] );
					expect( multiSearch.getData().results ).toHaveLength( 2 );

					typesenseClient.aliases().upsert( aliasName, collectionName );
					expect(
						typesenseClient
							.aliases()
							.retrieve( aliasName )
							.getData()
							.collection_name
					).toBe( collectionName );

					var keyDefinition = deserializeJSON(
						"{""description"":""cbTypesense live scoped search"",""actions"":[""documents:search""],""collections"":[""#collectionName#""]}"
					);
					var createdKey = typesenseClient
						.keys()
						.create( keyDefinition )
						.getData();
					createdKeyId         = createdKey.id;
					var scopedParameters = deserializeJSON( "{""filter_by"":""organizationId:=org-1""}" );
					var scopedKey        = typesenseClient
						.keys()
						.generateScopedSearchKey( createdKey.value, scopedParameters );
					var scopedSearch = liveClient( scopedKey ).search(
						collectionName,
						deserializeJSON( "{""q"":""*"",""query_by"":""name""}" )
					);
					expect( scopedSearch.found() ).toBe( 1 );
					var deletedByFilter = typesenseClient
						.documents( collectionName )
						.deleteByFilter( "organizationId:=org-1", 25 )
						.getData();
					expect( val( deletedByFilter.num_deleted ) ).toBe( 1 );
					expect( function(){
						typesenseClient.documents( collectionName ).retrieve( "1" );
					} ).toThrow( type = "cbTypesense.NotFoundException" );
					expect(
						typesenseClient
							.documents( collectionName )
							.retrieve( "2" )
							.getData()
							.name
					).toBe( "Red Prop" );

					expect(
						typesenseClient
							.operations()
							.debug()
							.getData()
					).toHaveKey( "version" );
					expect(
						typesenseClient
							.operations()
							.stats()
							.getData()
					).toBeStruct();
					expect(
						typesenseClient
							.operations()
							.metrics()
							.getData()
					).toBeStruct();
					expect(
						typesenseClient
							.operations()
							.snapshot()
							.isSuccess()
					).toBeTrue();

					typesenseClient.documents( collectionName ).delete( "2" );
				} finally {
					if ( createdKeyId ) {
						try {
							typesenseClient.keys().delete( createdKeyId );
						} catch ( any ignored ) {
						}
					}
					try {
						typesenseClient.aliases().delete( aliasName );
					} catch ( any ignored ) {
					}
					try {
						typesenseClient.collections().delete( collectionName );
					} catch ( any ignored ) {
					}
				}
			} );
		} );
	}

	private any function liveClient( required string apiKey ){
		return new cbtypesense.models.ConnectionClient(
			connectionName = "live",
			connection     = {
				nodes              : [ { protocol : "http", host : "127.0.0.1", port : 18108 } ],
				apiKey             : arguments.apiKey,
				connectTimeoutMs   : 500,
				readTimeoutMs      : 3000,
				retries            : 1,
				retryBackoffMs     : 10,
				unhealthyNodeTtlMs : 1000
			},
			hyper = new hyper.models.HyperBuilder()
		);
	}

}
