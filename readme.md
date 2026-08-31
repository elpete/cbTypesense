# cbTypesense

A resilient, endpoint-oriented [Typesense](https://typesense.org/) client for ColdBox applications. cbTypesense uses Hyper 8, supports named least-privilege connections, and keeps application-specific search projection and authorization outside the module.

## Compatibility

- ColdBox 8
- Hyper 8.2+
- BoxLang and CFML engines supported by the current ColdBox module template
- Typesense 29.x; the live contract suite pins `typesense/typesense:29.0@sha256:316b7e71c21f7e5e5caa8daa150e1b3f2be8c876081ee1f77bc2d92cd7f137d0`

The exact upstream source, license checksum, and container provenance are recorded in [`compatibility/typesense-29.0.md`](compatibility/typesense-29.0.md).

The module is MIT licensed. Typesense 29.0 is a separate GPL-3.0 program and is not bundled in this package.

## Installation

```bash
box install cbtypesense
```

## Configuration

Configure one or more named connections in `config/ColdBox.cfc`. Keep search, indexing, and administrative credentials separate in production.

```cfml
moduleSettings = {
    cbtypesense : {
        defaultConnection : "search",
        unhealthyNodeTtlMs : 30000,
        maxRetries : 3,
        connections : {
            search : {
                nodes : [
                    { protocol : "http", host : "127.0.0.1", port : 8108 }
                ],
                apiKey : getSystemSetting( "TYPESENSE_SEARCH_API_KEY", "" ),
                connectTimeoutMs : 500,
                readTimeoutMs : 1500,
                retries : 1,
                retryBackoffMs : 25
            },
            indexer : {
                nodes : [
                    { protocol : "http", host : "127.0.0.1", port : 8108 }
                ],
                apiKey : getSystemSetting( "TYPESENSE_INDEX_API_KEY", "" )
            }
        }
    }
};
```

Configuration is validated without making a network request. The normalized configuration returned by `Config@cbtypesense` is copied so callers cannot mutate shared state.

## Usage

Inject the default façade or request an isolated named client from the factory:

```cfml
property name="typesense" inject="Client@cbtypesense";
property name="typesenseClients" inject="ClientFactory@cbtypesense";

typesense.collections().create( schema );
typesense.documents( "inventory_items" ).upsert( document );
result = typesense.documents( "inventory_items" ).importDocuments(
    documents,
    action = "upsert"
);
searchResponse = typesense.search( "inventory_items", {
    q : "blue dress",
    query_by : "name,brand,model",
    filter_by : "organization_id:=42"
} );
typesense.aliases().upsert( "inventory_items_current", "inventory_items_v1" );

indexer = typesenseClients.get( "indexer" );
```

Public endpoint clients cover collections and schemas, aliases, document CRUD/import/export/search, multi-search, API keys, local scoped-search-key generation, and health/debug/stats/metrics/snapshot operations.

`importDocuments()` accepts an array of structs, a generator closure, an object implementing `hasNext()` and `next()`, a line reader implementing `readLine()`, or prepared NDJSON. It returns `TypesenseImportResult`; always inspect its succeeded and failed counts. Set `throwOnFailure=true` when any failed line must abort the caller.

Use `request()` only as a forward-compatible escape hatch. It accepts relative paths only and still applies configured authentication, normalized errors, and retry safety.

## Responses and failures

Calls return `TypesenseResponse`, which exposes status, parsed data, headers, request ID, and raw body. Search responses additionally expose `hits()`, `facetCounts()`, `found()`, `page()`, and `searchTimeMs()`.

Failures use `cbTypesense.AuthenticationException`, `PermissionException`, `NotFoundException`, `ValidationException`, `RateLimitException`, `ConnectionException`, or `ServerException`.

Reads retry eligible connection, 408, 429, and server failures across configured nodes. Unsafe writes are never retried automatically. Explicitly idempotent upsert/import calls can opt in with `retry=true`.

## Scoped search keys

Generate scoped keys locally from a search-only parent key. A `filter_by` restriction is required; `expires_at` is validated when present.

```cfml
scopedKey = getInstance( "ScopedKey@cbtypesense" ).generate(
    parentKey = variables.parentSearchKey,
    parameters = {
        filter_by : "organization_id:=42 && visibility:=[organization]",
        expires_at : dateAdd( "n", 15, now() ).getTime() / 1000
    }
);
```

The module does not decide tenant or ACL filters. That belongs to the consuming application.

## Development and verification

```bash
box install
cd test-harness && box install && cd ..
docker compose -f test-harness/compose.typesense.yml up -d
box server start serverConfigFile=server-boxlang-cfml@1.json
box testbox run
box run-script format:check
box run-script build:module
```

The live suite uses unique collections and cleans up its documents, aliases, and keys. Docker is used only for the external test service; no Typesense binary or image is included in the module artifact.

## License

cbTypesense is released under the [MIT License](LICENSE).
