/**
 * Validates and exposes immutable cbTypesense connection configuration.
 */
component singleton {

	property name="moduleSettings" inject="box:modulesettings:cbtypesense";

	public Config function init( struct settings = {} ){
		if ( structCount( arguments.settings ) ) {
			variables.moduleSettings = duplicate( arguments.settings );
			normalize();
		}
		return this;
	}

	public void function onDIComplete(){
		if ( !structKeyExists( variables, "normalized" ) ) {
			normalize();
		}
	}

	public string function getDefaultConnectionName(){
		return variables.normalized.defaultConnection;
	}

	public struct function getConnection( string name = getDefaultConnectionName() ){
		if ( !structKeyExists( variables.normalized.connections, arguments.name ) ) {
			configurationError( "Unknown Typesense connection [#arguments.name#]." );
		}
		return duplicate( variables.normalized.connections[ arguments.name ] );
	}

	public array function getConnectionNames(){
		return structKeyArray( variables.normalized.connections );
	}

	public struct function getSettings(){
		return duplicate( variables.normalized );
	}

	private void function normalize(){
		var source   = duplicate( variables.moduleSettings ?: {} );
		var defaults = {
			defaultConnection  : "default",
			unhealthyNodeTtlMs : 30000,
			maxRetries         : 3,
			connections        : {}
		};
		structAppend( defaults, source, true );
		if ( !isStruct( defaults.connections ) || !structCount( defaults.connections ) ) {
			configurationError( "At least one named Typesense connection is required." );
		}
		if ( !structKeyExists( defaults.connections, defaults.defaultConnection ) ) {
			configurationError( "The default Typesense connection [#defaults.defaultConnection#] is not configured." );
		}
		if ( defaults.maxRetries < 0 || defaults.maxRetries > 10 ) {
			configurationError( "maxRetries must be between 0 and 10." );
		}

		var connections = {};
		for ( var connectionName in defaults.connections ) {
			if ( !reFind( "^[A-Za-z][A-Za-z0-9_-]*$", connectionName ) ) {
				configurationError( "Invalid Typesense connection name [#connectionName#]." );
			}
			connections[ connectionName ] = normalizeConnection(
				connectionName,
				defaults.connections[ connectionName ],
				defaults.maxRetries,
				defaults.unhealthyNodeTtlMs
			);
		}
		variables.normalized = {
			defaultConnection : defaults.defaultConnection,
			connections       : connections
		};
	}

	private struct function normalizeConnection(
		required string name,
		required struct connection,
		required numeric maxRetries,
		required numeric unhealthyNodeTtlMs
	){
		var normalized = {
			nodes              : arguments.connection.nodes ?: [],
			apiKey             : arguments.connection.apiKey ?: "",
			connectTimeoutMs   : arguments.connection.connectTimeoutMs ?: 500,
			readTimeoutMs      : arguments.connection.readTimeoutMs ?: 1500,
			retries            : arguments.connection.retries ?: 1,
			retryBackoffMs     : arguments.connection.retryBackoffMs ?: 25,
			unhealthyNodeTtlMs : arguments.connection.unhealthyNodeTtlMs ?: arguments.unhealthyNodeTtlMs
		};
		if ( !isArray( normalized.nodes ) || !arrayLen( normalized.nodes ) ) {
			configurationError( "Typesense connection [#arguments.name#] requires at least one node." );
		}
		if ( !len( trim( normalized.apiKey ) ) ) {
			configurationError( "Typesense connection [#arguments.name#] requires an API key." );
		}
		if ( normalized.retries < 0 || normalized.retries > arguments.maxRetries ) {
			configurationError( "Typesense connection [#arguments.name#] retries must be between 0 and #arguments.maxRetries#." );
		}
		if ( normalized.connectTimeoutMs < 1 || normalized.readTimeoutMs < 1 || normalized.retryBackoffMs < 0 ) {
			configurationError( "Typesense connection [#arguments.name#] timeout and backoff values are invalid." );
		}
		var nodes = [];
		for ( var node in normalized.nodes ) {
			if ( !isStruct( node ) ) {
				configurationError( "Every node in Typesense connection [#arguments.name#] must be a struct." );
			}
			var protocol = lCase( trim( node.protocol ?: "https" ) );
			var host     = trim( node.host ?: "" );
			var port     = val( node.port ?: ( protocol == "https" ? 443 : 80 ) );
			if (
				!listFindNoCase( "http,https", protocol ) || !len( host ) || find( "/", host ) || port < 1 || port > 65535
			) {
				configurationError( "Typesense connection [#arguments.name#] contains an invalid node." );
			}
			arrayAppend( nodes, { protocol : protocol, host : host, port : port } );
		}
		normalized.nodes = nodes;
		return normalized;
	}

	private void function configurationError( required string message ){
		throw( type = "cbTypesense.ConfigurationException", message = arguments.message );
	}

}
