/**
 * Typesense health, diagnostics, metrics, stats, and snapshot endpoints.
 */
component {

	public Operations function init( required any client ){
		variables.client = arguments.client;
		return this;
	}

	public any function health(){
		return variables.client.request( method = "GET", path = "/health" );
	}

	public any function debug(){
		return variables.client.request( method = "GET", path = "/debug" );
	}

	public any function metrics(){
		return variables.client.request( method = "GET", path = "/metrics.json" );
	}

	public any function stats(){
		return variables.client.request( method = "GET", path = "/stats.json" );
	}

	public any function snapshot( string snapshotPath ){
		var body = {};
		if ( !isNull( arguments.snapshotPath ) && len( trim( arguments.snapshotPath ) ) ) {
			body.snapshot_path = arguments.snapshotPath;
		}
		return variables.client.request(
			method = "POST",
			path   = "/operations/snapshot",
			body   = body
		);
	}

}
