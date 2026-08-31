/**
 * Thread-safe client for one immutable named Typesense connection.
 */
component {

	property name="connectionName";
	property name="connection";

	public string function getConnectionName(){
		return variables.connectionName;
	}

	public ConnectionClient function init(
		required string connectionName,
		required struct connection,
		required any hyper
	){
		variables.connectionName = arguments.connectionName;
		variables.connection     = duplicate( arguments.connection );
		variables.hyper          = arguments.hyper;
		variables.json           = new cbtypesense.models.Json();
		variables.nextNodeIndex  = 1;
		variables.unhealthyUntil = {};
		return this;
	}

	public any function collections(){
		return new cbtypesense.models.endpoints.Collections( client = this );
	}

	public any function documents( required string collectionName ){
		return new cbtypesense.models.endpoints.Documents(
			client         = this,
			collectionName = arguments.collectionName
		);
	}

	public any function aliases(){
		return new cbtypesense.models.endpoints.Aliases( client = this );
	}

	public any function keys(){
		return new cbtypesense.models.endpoints.Keys( client = this );
	}

	public any function operations(){
		return new cbtypesense.models.endpoints.Operations( client = this );
	}

	public any function search( required string collectionName, required struct parameters ){
		return documents( arguments.collectionName ).search( arguments.parameters );
	}

	public any function multiSearch( required array searches, struct parameters = {} ){
		var body           = structNew( "ordered" );
		body[ "searches" ] = arguments.searches;
		return this.request(
			method      = "POST",
			path        = "/multi_search",
			queryParams = arguments.parameters,
			body        = body
		);
	}

	public any function request(
		required string method,
		required string path,
		struct queryParams = {},
		any body,
		struct headers      = {},
		boolean retryUnsafe = false
	){
		validateRelativePath( arguments.path );
		var normalizedMethod = uCase( trim( arguments.method ) );
		if ( !listFindNoCase( "GET,HEAD,POST,PUT,PATCH,DELETE", normalizedMethod ) ) {
			throw(
				type    = "cbTypesense.ValidationException",
				message = "Unsupported HTTP method [#normalizedMethod#]."
			);
		}
		var safeToRetry   = listFindNoCase( "GET,HEAD", normalizedMethod ) || arguments.retryUnsafe;
		var attemptLimit  = safeToRetry ? variables.connection.retries + 1 : 1;
		var lastException = javacast( "null", "" );
		for ( var attempt = 1; attempt <= attemptLimit; attempt++ ) {
			var node = nextNode();
			try {
				var hyperRequest = variables.hyper
					.new()
					.setUrl( nodeUrl( node ) & arguments.path )
					.setMethod( normalizedMethod )
					.setTimeout( max( 1, ceiling( variables.connection.readTimeoutMs / 1000 ) ) )
					.withHeaders( {
						"Accept"              : "application/json",
						"X-TYPESENSE-API-KEY" : variables.connection.apiKey
					} )
					.withHeaders( arguments.headers )
					.withQueryParams( normalizeQueryParams( arguments.queryParams ) )
					.allowErrors();
				if ( !isNull( arguments.body ) ) {
					hyperRequest.setBody(
						isStruct( arguments.body ) || isArray( arguments.body )
						 ? variables.json.encode( arguments.body )
						 : arguments.body
					);
					if ( !structKeyExists( arguments.headers, "Content-Type" ) ) {
						hyperRequest.asJson();
					}
				}
				var hyperResponse = hyperRequest.send();
				if ( hyperResponse.isSuccess() ) {
					return normalizeResponse( hyperResponse );
				}
				if ( safeToRetry && attempt < attemptLimit && isRetryableStatus( hyperResponse.getStatusCode() ) ) {
					markUnhealthy( node );
					backoff( attempt );
					continue;
				}
				throwResponseError( hyperResponse );
			} catch ( any exception ) {
				if ( left( exception.type ?: "", 12 ) == "cbTypesense." ) {
					rethrow;
				}
				lastException = exception;
				markUnhealthy( node );
				if ( !safeToRetry || attempt == attemptLimit ) {
					throw(
						type    = "cbTypesense.ConnectionException",
						message = "Unable to connect to Typesense connection [#variables.connectionName#].",
						detail  = safeMessage( exception.message ?: "Connection failed." )
					);
				}
				backoff( attempt );
			}
		}
		throw(
			type    = "cbTypesense.ConnectionException",
			message = "Unable to connect to Typesense connection [#variables.connectionName#].",
			detail  = isNull( lastException ) ? "Connection failed." : safeMessage(
				lastException.message ?: "Connection failed."
			)
		);
	}

	public string function encodePathSegment( required any value ){
		return replace(
			urlEncodedFormat( toString( arguments.value ) ),
			"+",
			"%20",
			"all"
		);
	}

	public string function encodeJson( required any value ){
		return variables.json.encode( arguments.value );
	}

	private any function normalizeResponse( required any response ){
		var body = toString( arguments.response.getData() ?: "" );
		var data = len( body ) && isJSON( body ) ? deserializeJSON( body ) : body;
		return new cbtypesense.models.TypesenseResponse(
			statusCode = arguments.response.getStatusCode(),
			data       = data,
			headers    = arguments.response.getHeaders(),
			requestId  = arguments.response.getHeader( "x-typesense-request-id", arguments.response.getRequestID() ),
			rawBody    = body
		);
	}

	private void function throwResponseError( required any response ){
		var statusCode    = val( arguments.response.getStatusCode() );
		var body          = left( toString( arguments.response.getData() ?: "" ), 2000 );
		var parsed        = len( body ) && isJSON( body ) ? deserializeJSON( body ) : {};
		var message       = safeMessage( parsed.message ?: body ?: "Typesense request failed." );
		var exceptionType = "cbTypesense.ServerException";
		if ( statusCode == 401 ) {
			exceptionType = "cbTypesense.AuthenticationException";
		} else if ( statusCode == 403 ) {
			exceptionType = "cbTypesense.PermissionException";
		} else if ( statusCode == 404 ) {
			exceptionType = "cbTypesense.NotFoundException";
		} else if ( statusCode == 408 || statusCode == 422 || statusCode == 400 ) {
			exceptionType = "cbTypesense.ValidationException";
		} else if ( statusCode == 429 ) {
			exceptionType = "cbTypesense.RateLimitException";
		}
		throw(
			type      = exceptionType,
			message   = message,
			detail    = "Typesense returned HTTP #statusCode# for connection [#variables.connectionName#].",
			errorCode = statusCode
		);
	}

	private string function safeMessage( required string value ){
		var result = arguments.value;
		result     = replaceNoCase(
			result,
			variables.connection.apiKey,
			"[REDACTED]",
			"all"
		);
		result = reReplaceNoCase(
			result,
			"(x-typesense-api-key|authorization)(\\s*[:=]\\s*)[^,;[:space:]]+",
			"\\1\\2[REDACTED]",
			"all"
		);
		return left( result, 1000 );
	}

	private void function validateRelativePath( required string path ){
		if (
			left( arguments.path, 1 ) != "/" || left( arguments.path, 2 ) == "//" || find( "://", arguments.path ) || reFind(
				"(^|/)\\.\\.(/|$)",
				arguments.path
			)
		) {
			throw(
				type    = "cbTypesense.ValidationException",
				message = "Typesense request paths must be safe relative paths."
			);
		}
	}

	private struct function nextNode(){
		var selected= {};
		lock name   ="cbTypesense.#variables.connectionName#.nodes" type="exclusive" timeout="5" {
			var nowTick = getTickCount();
			for ( var offset = 0; offset < arrayLen( variables.connection.nodes ); offset++ ) {
				var index = ( ( variables.nextNodeIndex + offset - 1 ) mod arrayLen( variables.connection.nodes ) ) + 1;
				var key   = nodeUrl( variables.connection.nodes[ index ] );
				if ( !structKeyExists( variables.unhealthyUntil, key ) || variables.unhealthyUntil[ key ] <= nowTick ) {
					selected                = variables.connection.nodes[ index ];
					variables.nextNodeIndex = ( index mod arrayLen( variables.connection.nodes ) ) + 1;
					break;
				}
			}
			if ( !structCount( selected ) ) {
				selected                = variables.connection.nodes[ variables.nextNodeIndex ];
				variables.nextNodeIndex = ( variables.nextNodeIndex mod arrayLen( variables.connection.nodes ) ) + 1;
			}
		}
		return selected;
	}

	private void function markUnhealthy( required struct node ){
		lock name="cbTypesense.#variables.connectionName#.nodes" type="exclusive" timeout="5" {
			variables.unhealthyUntil[ nodeUrl( arguments.node ) ] = getTickCount() + variables.connection.unhealthyNodeTtlMs;
		}
	}

	private string function nodeUrl( required struct node ){
		return "#arguments.node.protocol#://#arguments.node.host#:#arguments.node.port#";
	}

	private boolean function isRetryableStatus( required numeric statusCode ){
		return listFind( "408,429,500,502,503,504", arguments.statusCode ) > 0;
	}

	private struct function normalizeQueryParams( required struct queryParams ){
		var normalized = {};
		for ( var key in arguments.queryParams ) {
			normalized[ lCase( key ) ] = arguments.queryParams[ key ];
		}
		return normalized;
	}

	private void function backoff( required numeric attempt ){
		var delay = variables.connection.retryBackoffMs * arguments.attempt;
		if ( delay > 0 ) {
			sleep( delay );
		}
	}

}
