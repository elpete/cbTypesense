component extends="coldbox.system.testing.BaseTestCase" appMapping="root" {

	function beforeAll(){
		super.beforeAll();
		setup();
	}

	function run(){
		describe( "cbTypesense client", function(){
			beforeEach( function(){
				variables.hyper = new hyper.models.HyperBuilder();
				variables.hyper
					.fake( {
						"*" : function( createFakeResponse, req ){
							if ( find( "/documents/import", req.getUrl() ) ) {
								return createFakeResponse(
									statusCode = 200,
									data       = "{""success"":true}" & chr( 10 ) & "{""success"":false,""code"":400,""error"":""invalid""}"
								);
							}
							return createFakeResponse(
								statusCode = 200,
								data       = "{""found"":1,""page"":1,""hits"":[],""facet_counts"":[]}"
							);
						}
					} )
					.preventStrayRequests();
				variables.client = new cbtypesense.models.ConnectionClient(
					connectionName = "test",
					connection     = {
						nodes              : [ { protocol : "http", host : "127.0.0.1", port : 8108 } ],
						apiKey             : "super-secret-key",
						readTimeoutMs      : 1000,
						connectTimeoutMs   : 500,
						retries            : 0,
						retryBackoffMs     : 0,
						unhealthyNodeTtlMs : 1000
					},
					hyper = variables.hyper
				);
			} );

			it( "encodes paths, query values, and credentials on a fresh request", function(){
				var response = variables.client.search(
					"Costume Storage",
					{ q : "blue dress", query_by : "name" }
				);
				expect( response.found() ).toBe( 1 );
				expect(
					variables.hyper.wasRequestSent( function( req ){
						return find( "/collections/Costume%20Storage/documents/search", req.getUrl() ) &&
						req.getHeader( "X-TYPESENSE-API-KEY" ) == "super-secret-key" &&
						req.getQueryParamByName( "q" ) == "blue dress";
					} )
				).toBeTrue();
			} );

			it( "parses partial bulk import failures", function(){
				var result = variables.client
					.documents( "items" )
					.importDocuments( documents = [ { id : "1" }, { id : "2" } ], action = "upsert" );
				expect( result.getSucceededCount() ).toBe( 1 );
				expect( result.getFailedCount() ).toBe( 1 );
			} );

			it( "accepts generator closures for bulk imports", function(){
				var documents = [ { id : "1" }, { id : "2" } ];
				var index     = 0;
				var result    = variables.client
					.documents( "items" )
					.importDocuments( function(){
						index++;
						return index <= documents.len() ? documents[ index ] : javacast( "null", "" );
					} );

				expect( result.getSucceededCount() ).toBe( 1 );
				expect( result.getFailedCount() ).toBe( 1 );
			} );

			it( "bounds generator imports to the requested batch size", function(){
				var documents = [ { id : "1" }, { id : "2" }, { id : "3" } ];
				var index     = 0;
				var result    = variables.client
					.documents( "items" )
					.importDocuments(
						documents = function(){
							index++;
							return index <= documents.len() ? documents[ index ] : javacast( "null", "" );
						},
						batchSize = 2
					);

				expect( variables.hyper.getFakeRequestCount() ).toBe( 2 );
				expect( result.getSucceededCount() ).toBe( 2 );
				expect( result.getFailedCount() ).toBe( 2 );
			} );

			it( "does not expose normalized connection credentials", function(){
				expect( variables.client.getConnectionName() ).toBe( "test" );
				expect( structKeyExists( variables.client, "getConnection" ) ).toBeFalse();
			} );

			it( "rejects absolute request escape hatches", function(){
				expect( function(){
					variables.client.request( method = "GET", path = "https://attacker.example/keys" );
				} ).toThrow( type = "cbTypesense.ValidationException" );
			} );

			it( "rotates nodes and retries eligible reads", function(){
				var hyper = new hyper.models.HyperBuilder();
				hyper
					.fake( {
						"*" : function( createFakeResponse, req ){
							return find( "node-a", req.getUrl() )
							 ? createFakeResponse( statusCode = 503, data = "{""message"":""Unavailable""}" )
							 : createFakeResponse( statusCode = 200, data = "{""ok"":true}" );
						}
					} )
					.preventStrayRequests();
				var typesenseClient = newClient(
					hyper,
					[
						{ protocol : "http", host : "node-a", port : 8108 },
						{ protocol : "http", host : "node-b", port : 8108 }
					],
					1
				);

				expect( typesenseClient.request( method = "GET", path = "/health" ).getData().ok ).toBeTrue();
				expect( hyper.getFakeRequestCount() ).toBe( 2 );
				expect(
					hyper.wasRequestSent( function( req ){
						return find( "node-b", req.getUrl() ) > 0;
					} )
				).toBeTrue();
			} );

			it( "does not retry unsafe writes", function(){
				var hyper = new hyper.models.HyperBuilder();
				hyper
					.fake( {
						"*" : function( createFakeResponse ){
							return createFakeResponse( statusCode = 503, data = "{""message"":""Unavailable""}" );
						}
					} )
					.preventStrayRequests();
				var typesenseClient = newClient(
					hyper,
					[ { protocol : "http", host : "node-a", port : 8108 } ],
					2
				);

				expect( function(){
					typesenseClient.request(
						method = "POST",
						path   = "/collections",
						body   = { name : "items" }
					);
				} ).toThrow( type = "cbTypesense.ServerException" );
				expect( hyper.getFakeRequestCount() ).toBe( 1 );
			} );

			it( "maps response errors without leaking credentials", function(){
				var hyper = new hyper.models.HyperBuilder();
				hyper
					.fake( {
						"*" : function( createFakeResponse ){
							return createFakeResponse(
								statusCode = 401,
								data       = "{""message"":""Rejected super-secret-key in X-TYPESENSE-API-KEY""}"
							);
						}
					} )
					.preventStrayRequests();
				var typesenseClient = newClient( hyper, [ { protocol : "http", host : "node-a", port : 8108 } ] );
				var caught          = {};
				try {
					typesenseClient.request( method = "GET", path = "/health" );
				} catch ( any exception ) {
					caught = exception;
				}

				expect( caught.type ).toBe( "cbTypesense.AuthenticationException" );
				expect( caught.message ).notToInclude( "super-secret-key" );
				expect( caught.message ).toInclude( "[REDACTED]" );
			} );
		} );
	}

	private any function newClient(
		required any hyper,
		required array nodes,
		numeric retries = 0
	){
		return new cbtypesense.models.ConnectionClient(
			connectionName = "test",
			connection     = {
				nodes              : arguments.nodes,
				apiKey             : "super-secret-key",
				readTimeoutMs      : 1000,
				connectTimeoutMs   : 500,
				retries            : arguments.retries,
				retryBackoffMs     : 0,
				unhealthyNodeTtlMs : 1000
			},
			hyper = arguments.hyper
		);
	}

}
