component extends="coldbox.system.testing.BaseTestCase" appMapping="root" {

	function beforeAll(){
		super.beforeAll();
		setup();
	}

	function run(){
		describe( "Typesense import results", function(){
			it( "counts every response line and removes failed documents", function(){
				var body   = "{""success"":true}" & chr( 10 ) & "{""success"":false,""code"":400,""error"":""Bad field"",""document"":{""secret"":""value""}}";
				var result = new cbtypesense.models.TypesenseImportResult( body = body );

				expect( result.getSucceededCount() ).toBe( 1 );
				expect( result.getFailedCount() ).toBe( 1 );
				expect( result.getResults()[ 2 ] ).notToHaveKey( "document" );
				expect( result.isSuccess() ).toBeFalse();
			} );

			it( "can fail the import when any line fails", function(){
				expect( function(){
					new cbtypesense.models.TypesenseImportResult(
						body           = "{""success"":false,""error"":""Nope""}",
						throwOnFailure = true
					);
				} ).toThrow( type = "cbTypesense.ImportException" );
			} );
		} );
	}

}
