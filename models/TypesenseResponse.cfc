/**
 * Normalized Typesense HTTP response.
 */
component accessors="true" {

	property name="statusCode";
	property name="data";
	property name="headers";
	property name="requestId";
	property name="rawBody";

	public TypesenseResponse function init(
		required numeric statusCode,
		required any data,
		struct headers   = {},
		string requestId = "",
		string rawBody   = ""
	){
		variables.statusCode = arguments.statusCode;
		variables.data       = arguments.data;
		variables.headers    = arguments.headers;
		variables.requestId  = arguments.requestId;
		variables.rawBody    = arguments.rawBody;
		return this;
	}

	public boolean function isSuccess(){
		return variables.statusCode >= 200 && variables.statusCode < 300;
	}

	public array function hits(){
		return isStruct( variables.data ) && structKeyExists( variables.data, "hits" ) ? variables.data.hits : [];
	}

	public array function facetCounts(){
		return isStruct( variables.data ) && structKeyExists( variables.data, "facet_counts" ) ? variables.data.facet_counts : [];
	}

	public numeric function found(){
		return isStruct( variables.data ) && structKeyExists( variables.data, "found" ) ? variables.data.found : 0;
	}

	public numeric function page(){
		return isStruct( variables.data ) && structKeyExists( variables.data, "page" ) ? variables.data.page : 0;
	}

	public struct function getMemento( boolean includeRawBody = false ){
		var result = {
			statusCode : variables.statusCode,
			data       : variables.data,
			headers    : variables.headers,
			requestId  : variables.requestId
		};
		if ( arguments.includeRawBody ) {
			result.rawBody = variables.rawBody;
		}
		return result;
	}

}
