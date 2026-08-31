/**
 * Creates and caches isolated clients for named connections.
 */
component singleton {

	property name="config" inject="Config@cbtypesense";
	property name="hyper"  inject="HyperBuilder@hyper";

	public ClientFactory function init( any config, any hyper ){
		if ( !isNull( arguments.config ) ) {
			variables.config = arguments.config;
		}
		if ( !isNull( arguments.hyper ) ) {
			variables.hyper = arguments.hyper;
		}
		variables.clients = {};
		return this;
	}

	public any function get( string name = variables.config.getDefaultConnectionName() ){
		if ( !structKeyExists( variables.clients, arguments.name ) ) {
			lock name="cbTypesense.ClientFactory.#arguments.name#" type="exclusive" timeout="5" {
				if ( !structKeyExists( variables.clients, arguments.name ) ) {
					variables.clients[ arguments.name ] = new cbtypesense.models.ConnectionClient(
						connectionName = arguments.name,
						connection     = variables.config.getConnection( arguments.name ),
						hyper          = variables.hyper
					);
				}
			}
		}
		return variables.clients[ arguments.name ];
	}

}
