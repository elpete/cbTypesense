/**
 * Parses the per-document NDJSON result returned by Typesense imports.
 */
component accessors="true" {

	property name="results";
	property name="succeededCount";
	property name="failedCount";

	public TypesenseImportResult function init( required string body, boolean throwOnFailure = false ){
		variables.results        = [];
		variables.succeededCount = 0;
		variables.failedCount    = 0;
		for ( var line in listToArray( arguments.body, chr( 10 ) ) ) {
			line = trim( line );
			if ( !len( line ) ) {
				continue;
			}
			var parsed = isJSON( line ) ? deserializeJSON( line ) : {
				success : false,
				error   : "Invalid import response line."
			};
			var safeResult = { success : parsed.success ?: false };
			if ( safeResult.success ) {
				variables.succeededCount++;
			} else {
				variables.failedCount++;
				safeResult.error = left( toString( parsed.error ?: "Import failed." ), 500 );
				safeResult.code  = parsed.code ?: 0;
			}
			arrayAppend( variables.results, safeResult );
		}
		if ( arguments.throwOnFailure && variables.failedCount ) {
			throw(
				type    = "cbTypesense.ImportException",
				message = "Typesense rejected #variables.failedCount# imported document(s).",
				detail  = serializeJSON( variables.results )
			);
		}
		return this;
	}

	public boolean function isSuccess(){
		return variables.failedCount == 0;
	}

}
