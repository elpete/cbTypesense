/**
 * Generates Typesense scoped search keys without network access.
 */
component singleton {

	public string function generate( required string parentKey, required struct parameters ){
		if ( !len( trim( arguments.parentKey ) ) ) {
			throw( type = "cbTypesense.ValidationException", message = "A parent search key is required." );
		}
		if ( !structKeyExists( arguments.parameters, "filter_by" ) || !len( trim( arguments.parameters.filter_by ) ) ) {
			throw(
				type    = "cbTypesense.ValidationException",
				message = "Scoped search keys require an embedded filter_by parameter."
			);
		}
		if (
			structKeyExists( arguments.parameters, "expires_at" ) &&
			(
				!isNumeric( arguments.parameters.expires_at ) ||
				arguments.parameters.expires_at <= unixTime()
			)
		) {
			throw(
				type    = "cbTypesense.ValidationException",
				message = "Scoped search key expires_at must be in the future."
			);
		}
		var serializedParameters = serializePreservingCase( arguments.parameters );
		var digest               = binaryEncode(
			binaryDecode(
				hmac(
					serializedParameters,
					arguments.parentKey,
					"HmacSHA256",
					"utf-8"
				),
				"hex"
			),
			"base64"
		);
		return toBase64( digest & left( arguments.parentKey, 4 ) & serializedParameters );
	}

	private numeric function unixTime(){
		return dateDiff(
			"s",
			createDateTime( 1970, 1, 1, 0, 0, 0 ),
			dateConvert( "local2Utc", now() )
		);
	}

	private string function serializePreservingCase( required any value, string keyName = "" ){
		if ( isStruct( arguments.value ) ) {
			var pairs = [];
			for ( var key in arguments.value ) {
				arrayAppend(
					pairs,
					serializeJSON( lCase( key ) ) & ":" & serializePreservingCase( arguments.value[ key ], key )
				);
			}
			return "{" & arrayToList( pairs, "," ) & "}";
		}
		if ( isArray( arguments.value ) ) {
			var items = [];
			for ( var item in arguments.value ) {
				arrayAppend( items, serializePreservingCase( item ) );
			}
			return "[" & arrayToList( items, "," ) & "]";
		}
		if ( lCase( arguments.keyName ) == "expires_at" ) {
			return numberFormat( arguments.value, "0" );
		}
		return serializeJSON( arguments.value );
	}

}
