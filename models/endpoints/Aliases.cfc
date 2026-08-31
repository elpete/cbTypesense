/**
 * Typesense collection alias endpoints.
 */
component {

	public Aliases function init( required any client ){
		variables.client = arguments.client;
		return this;
	}

	public any function list(){
		return variables.client.request( method = "GET", path = "/aliases" );
	}

	public any function retrieve( required string aliasName ){
		return variables.client.request( method = "GET", path = aliasPath( arguments.aliasName ) );
	}

	public any function upsert( required string aliasName, required string collectionName ){
		var body                  = structNew( "ordered" );
		body[ "collection_name" ] = arguments.collectionName;
		return variables.client.request(
			method      = "PUT",
			path        = aliasPath( arguments.aliasName ),
			body        = body,
			retryUnsafe = true
		);
	}

	public any function delete( required string aliasName ){
		return variables.client.request( method = "DELETE", path = aliasPath( arguments.aliasName ) );
	}

	private string function aliasPath( required string aliasName ){
		return "/aliases/#variables.client.encodePathSegment( arguments.aliasName )#";
	}

}
