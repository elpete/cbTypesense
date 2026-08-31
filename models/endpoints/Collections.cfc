/**
 * Typesense collection and schema endpoints.
 */
component {

	public Collections function init( required any client ){
		variables.client = arguments.client;
		return this;
	}

	public any function list(){
		return variables.client.request( method = "GET", path = "/collections" );
	}

	public any function retrieve( required string collectionName ){
		return variables.client.request( method = "GET", path = collectionPath( arguments.collectionName ) );
	}

	public any function create( required struct schema ){
		return variables.client.request(
			method = "POST",
			path   = "/collections",
			body   = arguments.schema
		);
	}

	public any function update( required string collectionName, required struct changes ){
		return variables.client.request(
			method = "PATCH",
			path   = collectionPath( arguments.collectionName ),
			body   = arguments.changes
		);
	}

	public any function delete( required string collectionName ){
		return variables.client.request( method = "DELETE", path = collectionPath( arguments.collectionName ) );
	}

	private string function collectionPath( required string collectionName ){
		return "/collections/#variables.client.encodePathSegment( arguments.collectionName )#";
	}

}
