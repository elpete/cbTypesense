component extends="coldbox.system.testing.BaseTestCase" appMapping="root" {

	function beforeAll(){
		super.beforeAll();
		setup();
	}

	function run(){
		describe( "cbTypesense WireBox contract", function(){
			it( "registers the documented public models", function(){
				var typesenseClient = getInstance( "Client@cbtypesense" );
				var factory         = getInstance( "ClientFactory@cbtypesense" );
				var first           = factory.get( "search" );
				var second          = factory.get( "search" );

				expect( isObject( typesenseClient ) ).toBeTrue();
				expect( first.getConnectionName() ).toBe( "search" );
				expect( createObject( "java", "java.lang.System" ).identityHashCode( first ) ).toBe(
					createObject( "java", "java.lang.System" ).identityHashCode( second )
				);
			} );

			it( "loads the public client from the configured module artifact", function(){
				var clientPath = getMetadata( getInstance( "Client@cbtypesense" ) ).path;
				expect( canonicalPath( clientPath ) ).toStartWith( canonicalPath( expandPath( "/cbtypesense" ) ) );
			} );
		} );
	}

	private string function canonicalPath( required string path ){
		return createObject( "java", "java.io.File" ).init( arguments.path ).getCanonicalPath();
	}

}
