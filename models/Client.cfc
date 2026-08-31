/**
 * Stateless facade for the configured default Typesense connection.
 */
component singleton {

	property name="factory" inject="ClientFactory@cbtypesense";

	public any function collections(){
		return client().collections();
	}

	public any function documents( required string collectionName ){
		return client().documents( arguments.collectionName );
	}

	public any function aliases(){
		return client().aliases();
	}

	public any function keys(){
		return client().keys();
	}

	public any function operations(){
		return client().operations();
	}

	public any function search( required string collectionName, required struct parameters ){
		return client().search( arguments.collectionName, arguments.parameters );
	}

	public any function multiSearch( required array searches, struct parameters = {} ){
		return client().multiSearch( arguments.searches, arguments.parameters );
	}

	public any function request(
		required string method,
		required string path,
		struct queryParams = {},
		any body,
		struct headers      = {},
		boolean retryUnsafe = false
	){
		return client().request( argumentCollection = arguments );
	}

	private any function client(){
		return variables.factory.get();
	}

}
