/**
 * Typesense document, import, export, and search endpoints for one collection.
 */
component {

	public Documents function init( required any client, required string collectionName ){
		variables.client         = arguments.client;
		variables.collectionName = arguments.collectionName;
		variables.basePath       = "/collections/#variables.client.encodePathSegment( arguments.collectionName )#/documents";
		return this;
	}

	public any function retrieve( required string documentId ){
		return variables.client.request(
			method = "GET",
			path   = "#variables.basePath#/#variables.client.encodePathSegment( arguments.documentId )#"
		);
	}

	public any function upsert( required struct document, boolean retry = false ){
		return variables.client.request(
			method      = "POST",
			path        = variables.basePath,
			queryParams = { action : "upsert" },
			body        = arguments.document,
			retryUnsafe = arguments.retry
		);
	}

	public any function update( required string documentId, required struct changes ){
		return variables.client.request(
			method = "PATCH",
			path   = "#variables.basePath#/#variables.client.encodePathSegment( arguments.documentId )#",
			body   = arguments.changes
		);
	}

	public any function delete( required string documentId ){
		return variables.client.request(
			method = "DELETE",
			path   = "#variables.basePath#/#variables.client.encodePathSegment( arguments.documentId )#"
		);
	}

	public any function deleteByFilter( required string filterBy, numeric batchSize = 40 ){
		if ( !len( trim( arguments.filterBy ) ) ) {
			throw(
				type    = "cbTypesense.ValidationException",
				message = "A filter_by expression is required when deleting documents by query."
			);
		}
		if (
			!isNumeric( arguments.batchSize ) ||
			val( arguments.batchSize ) != int( val( arguments.batchSize ) ) ||
			val( arguments.batchSize ) < 1 ||
			val( arguments.batchSize ) > 1000
		) {
			throw(
				type    = "cbTypesense.ValidationException",
				message = "Document delete batchSize must be a whole number from 1 through 1000."
			);
		}
		return variables.client.request(
			method      = "DELETE",
			path        = variables.basePath,
			queryParams = {
				filter_by  : trim( arguments.filterBy ),
				batch_size : int( val( arguments.batchSize ) )
			}
		);
	}

	public any function search( required struct parameters ){
		return variables.client.request(
			method      = "GET",
			path        = "#variables.basePath#/search",
			queryParams = arguments.parameters
		);
	}

	public any function importDocuments(
		required any documents,
		string action          = "create",
		boolean throwOnFailure = false,
		boolean retry          = false,
		numeric batchSize      = 1000
	){
		if ( !listFindNoCase( "create,upsert,update,emplace", arguments.action ) ) {
			throw(
				type    = "cbTypesense.ValidationException",
				message = "Unsupported Typesense import action [#arguments.action#]."
			);
		}
		if ( arguments.batchSize < 1 ) {
			throw(
				type    = "cbTypesense.ValidationException",
				message = "Typesense import batchSize must be at least 1."
			);
		}
		if ( isClosure( arguments.documents ) ) {
			return importGenerator( argumentCollection = arguments );
		}
		if (
			isObject( arguments.documents ) &&
			structKeyExists( arguments.documents, "hasNext" ) &&
			structKeyExists( arguments.documents, "next" )
		) {
			return importIterator( argumentCollection = arguments );
		}
		if ( isObject( arguments.documents ) && structKeyExists( arguments.documents, "readLine" ) ) {
			return importLineReader( argumentCollection = arguments );
		}
		var ndjson = prepareNdjson( arguments.documents );
		return importResult(
			body           = sendImport( ndjson, arguments.action, arguments.retry ),
			throwOnFailure = arguments.throwOnFailure
		);
	}

	private string function sendImport(
		required string ndjson,
		required string action,
		required boolean retry
	){
		var response = variables.client.request(
			method      = "POST",
			path        = "#variables.basePath#/import",
			queryParams = { action : lCase( arguments.action ) },
			body        = arguments.ndjson,
			headers     = { "Content-Type" : "text/plain" },
			retryUnsafe = arguments.retry
		);
		return response.getRawBody();
	}

	private any function importResult( required string body, required boolean throwOnFailure ){
		return new cbtypesense.models.TypesenseImportResult(
			body           = arguments.body,
			throwOnFailure = arguments.throwOnFailure
		);
	}

	private any function importGenerator(
		required any documents,
		required string action,
		required boolean throwOnFailure,
		required boolean retry,
		required numeric batchSize
	){
		var bodies = [];
		var batch  = [];
		while ( true ) {
			var document = arguments.documents();
			if ( isNull( document ) ) {
				if ( batch.len() ) {
					arrayAppend(
						bodies,
						sendImport(
							serializeDocuments( batch ),
							arguments.action,
							arguments.retry
						)
					);
				}
				break;
			}
			arrayAppend( batch, document );
			if ( batch.len() >= arguments.batchSize ) {
				arrayAppend(
					bodies,
					sendImport(
						serializeDocuments( batch ),
						arguments.action,
						arguments.retry
					)
				);
				batch = [];
			}
		}
		return importResult( arrayToList( bodies, chr( 10 ) ), arguments.throwOnFailure );
	}

	private any function importIterator(
		required any documents,
		required string action,
		required boolean throwOnFailure,
		required boolean retry,
		required numeric batchSize
	){
		var bodies = [];
		var batch  = [];
		while ( arguments.documents.hasNext() ) {
			arrayAppend( batch, arguments.documents.next() );
			if ( batch.len() >= arguments.batchSize ) {
				arrayAppend(
					bodies,
					sendImport(
						serializeDocuments( batch ),
						arguments.action,
						arguments.retry
					)
				);
				batch = [];
			}
		}
		if ( batch.len() ) {
			arrayAppend(
				bodies,
				sendImport(
					serializeDocuments( batch ),
					arguments.action,
					arguments.retry
				)
			);
		}
		return importResult( arrayToList( bodies, chr( 10 ) ), arguments.throwOnFailure );
	}

	private any function importLineReader(
		required any documents,
		required string action,
		required boolean throwOnFailure,
		required boolean retry,
		required numeric batchSize
	){
		var bodies = [];
		var lines  = [];
		while ( true ) {
			var line = arguments.documents.readLine();
			if ( isNull( line ) ) {
				if ( lines.len() ) {
					arrayAppend(
						bodies,
						sendImport(
							arrayToList( lines, chr( 10 ) ),
							arguments.action,
							arguments.retry
						)
					);
				}
				break;
			}
			arrayAppend( lines, line );
			if ( lines.len() >= arguments.batchSize ) {
				arrayAppend(
					bodies,
					sendImport(
						arrayToList( lines, chr( 10 ) ),
						arguments.action,
						arguments.retry
					)
				);
				lines = [];
			}
		}
		return importResult( arrayToList( bodies, chr( 10 ) ), arguments.throwOnFailure );
	}

	public any function exportDocuments( struct parameters = {} ){
		return variables.client.request(
			method      = "GET",
			path        = "#variables.basePath#/export",
			queryParams = arguments.parameters
		);
	}

	private string function prepareNdjson( required any documents ){
		if ( isSimpleValue( arguments.documents ) ) {
			return trim( arguments.documents );
		}
		if ( isArray( arguments.documents ) ) {
			return serializeDocuments( arguments.documents );
		}
		throw(
			type    = "cbTypesense.ValidationException",
			message = "Import documents must be an array or prepared NDJSON string."
		);
	}

	private string function serializeDocuments( required array documents ){
		var lines = [];
		for ( var document in arguments.documents ) {
			if ( !isStruct( document ) ) {
				throw(
					type    = "cbTypesense.ValidationException",
					message = "Every imported document must be a struct."
				);
			}
			arrayAppend( lines, variables.client.encodeJson( document ) );
		}
		return arrayToList( lines, chr( 10 ) );
	}

}
