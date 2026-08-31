component extends="coldbox.system.testing.BaseTestCase" appMapping="root" {

	function beforeAll(){
		super.beforeAll();
		setup();
	}

	function run(){
		describe( "Typesense scoped search keys", function(){
			it( "matches the official client algorithm deterministically", function(){
				var parameters        = structNew( "ordered" );
				parameters.filter_by  = "organizationId:=org-1";
				parameters.expires_at = 4102444800;
				var key               = new cbtypesense.models.ScopedKey().generate( "xyz-search-only-key", parameters );
				expect( key ).toBe( "dW8xL3BKYUkya01sVHZkZTVIdEJuTldpSDZ2cUxuR2dzb00vWU9vdUVSaz14eXoteyJmaWx0ZXJfYnkiOiJvcmdhbml6YXRpb25JZDo9b3JnLTEiLCJleHBpcmVzX2F0Ijo0MTAyNDQ0ODAwfQ==" );
			} );

			it( "requires an authorization filter", function(){
				expect( function(){
					new cbtypesense.models.ScopedKey().generate( "search-key", { q : "*" } );
				} ).toThrow( type = "cbTypesense.ValidationException", regex = "filter_by" );
			} );
		} );
	}

}
