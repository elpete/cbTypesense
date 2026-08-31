/**
 * Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
 * www.ortussolutions.com
 * ---
 */
component {

	// Module Properties
	this.title       = "cbTypesense";
	this.author      = "Eric Peterson";
	this.webURL      = "https://github.com/coldbox-modules/cbtypesense";
	this.description = "A resilient Typesense API client for ColdBox";
	this.version     = "@build.version@+@build.number@";

	// Model Namespace
	this.modelNamespace = "cbtypesense";

	// CF Mapping
	this.cfmapping = "cbtypesense";

	// Dependencies
	this.dependencies = [ "hyper" ];

	/**
	 * Configure Module
	 */
	function configure(){
		settings = {
			defaultConnection  : "default",
			unhealthyNodeTtlMs : 30000,
			maxRetries         : 3,
			connections        : {
				default : {
					nodes : [
						{
							protocol : getSystemSetting( "TYPESENSE_PROTOCOL", "http" ),
							host     : getSystemSetting( "TYPESENSE_HOST", "127.0.0.1" ),
							port     : getSystemSetting( "TYPESENSE_PORT", 8108 )
						}
					],
					apiKey           : getSystemSetting( "TYPESENSE_API_KEY", "" ),
					connectTimeoutMs : 500,
					readTimeoutMs    : 1500,
					retries          : 1,
					retryBackoffMs   : 25
				}
			}
		};
	}

	/**
	 * Fired when the module is registered and activated.
	 */
	function onLoad(){
	}

	/**
	 * Fired when the module is unregistered and unloaded
	 */
	function onUnload(){
	}

}
