/**
 * Typesense API key endpoints and local scoped key generation.
 */
component {

	public Keys function init( required any client ){
		variables.client = arguments.client;
		return this;
	}

	public any function list(){
		return variables.client.request( method = "GET", path = "/keys" );
	}

	public any function retrieve( required numeric keyId ){
		return variables.client.request(
			method = "GET",
			path   = "/keys/#variables.client.encodePathSegment( arguments.keyId )#"
		);
	}

	public any function create( required struct keyDefinition ){
		return variables.client.request(
			method = "POST",
			path   = "/keys",
			body   = arguments.keyDefinition
		);
	}

	public any function delete( required numeric keyId ){
		return variables.client.request(
			method = "DELETE",
			path   = "/keys/#variables.client.encodePathSegment( arguments.keyId )#"
		);
	}

	public string function generateScopedSearchKey( required string parentKey, required struct parameters ){
		return new cbtypesense.models.ScopedKey().generate( arguments.parentKey, arguments.parameters );
	}

}
