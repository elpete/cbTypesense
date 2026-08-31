/**
 * JSON encoding that retains the exact struct keys supplied by the application.
 */
component singleton {

	public string function encode( required any value ){
		if ( isStruct( arguments.value ) ) {
			var pairs = [];
			for ( var key in arguments.value ) {
				arrayAppend( pairs, serializeJSON( key ) & ":" & encode( arguments.value[ key ] ) );
			}
			return "{" & arrayToList( pairs, "," ) & "}";
		}
		if ( isArray( arguments.value ) ) {
			var items = [];
			for ( var item in arguments.value ) {
				arrayAppend( items, encode( item ) );
			}
			return "[" & arrayToList( items, "," ) & "]";
		}
		return serializeJSON( arguments.value );
	}

}
