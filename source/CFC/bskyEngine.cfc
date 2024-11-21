/**
 * CFC wrapper to interact with BlueSky API calls and some helper functions. 
 */

component hint="BlueSky Calls" displayname="BlueSky Calls" output="false" {

    public function init(){

        local_useragent = 'cfcbsky'

        local_apiURL = 'https://bsky.social/'

        bsky_identifier = application.bsky.identifier

        bsky_password = application.bsky.password

		return this;
	}

    // HELPER FUNCTIONS //

    /**
     * Send the API request
     *
     * @endpoint Atproto endpoint
     * @httpMethod Method to be used for the request
     * @params Array of params to be added to the request
     */

    public any function sendRequest(required endpoint, httpMethod='GET', params) localmode='modern' {

        apiEndpoint = local_apiURL&arguments.endpoint

        httpMethod = arguments.httpMethod

        httpService = new http(method = httpMethod, url = apiEndpoint, useragent = local_useragent)

        httpService.addParam(name='Accept', type='header', value="*/*")
        httpService.addParam(name='Connection', type='header', value="keep-alive")

        if(isDefined('arguments.params')){
            for(param in arguments.params){

                httpService.addParam(name=param.name, type=param.type, value=param.value)
            }
        }

        bskyRequest = httpService.send().getPrefix()

        return bskyRequest
        
    }

    /**
     * Formats the Authorization header to be used with the endpoint
     */
    public any function authorizationHeader() localmode='modern'{

        authorizationHeader = 'Bearer '&application.bsky.accessJwt

        return {'type':'header', 'name':'Authorization', 'value':authorizationHeader}

        
    }

    /**
     * Remove metadata from image file. Always good practice to remove metadata
     *
     * @imageFile 
     */    
    public any function removeMetadata(required imageFile) localmode='modern'{

        cleanImage = imageNew(arguments.imageFile)

        return cleanImage
        
    }

    /**
     * Extract the record key from an atporoto URI
     *
     * @uri 
     */
    public any function getKeyFromURI(required uri) localmode='modern' {

        uri = arguments.uri

        // break the URI down into array

        uriArray = listToArray(uri, "/")

        //TODO Have to do some checking in the future to make sure URI is valid

        return arrayLast(uriArray)
        
    }

    /**
	 * Converts "Regular" date to ISO 8601
	 * https://en.wikipedia.org/wiki/ISO_8601
	 *
	 * @datetime Date to be converted
	 * @convertToUTC Convert to UTC? Default is True
	 */
	public function DateToISO8601(required date datetime, boolean convertToUTC=true) localmode='modern' {


		if(convertToUTC){

			datetime = dateConvert("local2Utc", arguments.datetime)

		}

		//return dateTimeFormat(datetime, "iso8601") // this works in Lucee

		//return dateTimeFormat(datetime, "iso") // this works in ACF
		
		return (dateFormat( datetime, "yyyy-mm-dd" ) & "T" & timeFormat( datetime, "HH:mm:ss" ) & "Z")


	}

    /**
     * Detect richtext strings in the post text
     *
     * @post 
     */
    public array function detectRichText(required post) localmode='modern' {

        // Regex to find link
        rePattern = '(^|\s|\()((https?:\/\/[\S]+)|(([a-z][a-z0-9]*(\.[a-z0-9]+)+)[\S]*))'

        reResultArray = reFindNoCase(rePattern, arguments.post, 1, True, 'all')

        facets = arrayNew()

        // check if there is a match
        if(arrayLen(reResultArray)>=1 AND reResultArray[1].pos[1]!=0){

            for(matches in reResultArray){

                facets.push({
                    'index': {
                        'byteStart': matches.pos[6]-1,
                        'byteEnd': matches.pos[3]+matches.len[3]
                    },
                    'features': [
                        {'$type': 'app.bsky.richtext.facet##link', 'uri': matches.match[3]}
                    ]
                })

            }
        }

        return facets;
        
    }

    /**
     * Detect mention in post text
     *
     * @post 
     */    
    public any function detectMention(required post) localmode='modern' {

        // Regex to find mentions
        rePatternMention = '(@([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)'

        reResultArrayMention = reFindNoCase(rePatternMention, arguments.post, 1, true, 'all')

        facets = arrayNew()

        // Check if there is a match
        if(arrayLen(reResultArrayMention)>=1 AND reResultArrayMention[1].pos[1]!=0){

            for(matches in reResultArrayMention){

                // Only add the mention if the handle exists
                if(resolveHandle(matches.match[1]) != 0){

                    facets.push({
                        'index': {
                            'byteStart': matches.pos[1]-1,
                            'byteEnd': matches.pos[1]+matches.len[1]
                        },
                        'features': [
                            {'$type': 'app.bsky.richtext.facet##mention', 'did': matches.match[1]}
                        ]
                    })

                }

            }
        }

        return facets
        
    }

    /**
     * Checks if the atproto server session is valid. If not valid, get a new session
     */    
    public boolean function isSessionValid() localmode='modern' {
        
        // Check if application authorization exists
        if(isDefined('application.bsky.accessJwt')){

            // If session is returned, session is valid
            if(getSession()){

                return 1

            }else{
                
                return refreshSession()

            }

        }else{

            return createSession()

        }

        // If everything fails, return false
        return 0

    }

    // IDENTITY CALLS //

    /**
     * Validate user handle with server
     *
     * @handle User handle without @
     */
    public any function resolveHandle(required handle) localmode='modern' {

        endpoint = 'xrpc/com.atproto.identity.resolveHandle'

        httpMethod = 'GET'

        // Remove @
        handle = replace(arguments.handle, '@', '')

        params = [{'type':'url', 'name':'handle', 'value':handle}]

        handleRequest = sendRequest(endpoint, httpMethod, params)

        if(handleRequest.status_code != 400){

            handleInfo = deserializeJSON(handleRequest.filecontent)

            return handleInfo.did

        } else {
            
            return 0

        }
        
    }

    // SERVER CALLS //

    /**
     * Create an authentication session.
     */
    public boolean function createSession() localmode='modern' {

        endpoint = 'xrpc/com.atproto.server.createSession'

        httpMethod = 'POST'

        params = arrayNew()

        body = {"identifier":bsky_identifier, "password":bsky_password}

        arrayAppend(params, {'type':'body', 'name':'body', 'value':serializeJSON(body)})
        arrayAppend(params, {'type':'header', 'name':'Content-Type', 'value':'application/json'})

        bskySessionRequest = sendRequest(endpoint, httpMethod, params)

        if(bskySessionRequest.statuscode=="200 OK"){
            
            bskySessionRequest = deserializeJSON(bskySessionRequest.filecontent)
            
            // Save accessJwt and refreshJwt into application
            application.bsky.accessJwt = bskySessionRequest.accessJwt
            application.bsky.refreshJwt = bskySessionRequest.refreshJwt
            application.bsky.did = bskySessionRequest.did
        
        }else {
        
            return 0
        
        }

        return 1
        
    }

    /**
     * Get information about the current auth session. Requires auth.
     */
    public boolean function getSession() localmode='modern' {

        endpoint = 'xrpc/com.atproto.server.getSession'

        httpMethod = 'GET'

        params = arrayNew()

        authorizationHeader = 'Bearer '&application.bsky.accessJwt
        arrayAppend(params, {'type':'header', 'name':'Authorization', 'value':authorizationHeader})

        bskySessionRequest = sendRequest(endpoint, httpMethod, params)

        if(bskySessionRequest.statuscode=="200 OK"){
            
            return 1
        
        }else {
        
            return 0
        
        }
        
    }

    /**
     * Refresh an authentication session. Requires auth using the 'refreshJwt' (not the 'accessJwt').
     */
    public boolean function refreshSession() localmode='modern' {

        endpoint = 'xrpc/com.atproto.server.refreshSession'

        httpMethod = 'POST'

        params = arrayNew()

        authorizationHeader = 'Bearer '&application.bsky.refreshJwt
        arrayAppend(params, {'type':'header', 'name':'Authorization', 'value':authorizationHeader})

        bskySessionRequest = sendRequest(endpoint, httpMethod, params)

        if(bskySessionRequest.statuscode=="200 OK"){
            
            bskySessionRequest = deserializeJSON(bskySessionRequest.filecontent)
            
            // Save accessJwt and refreshJwt into application
            application.bsky.accessJwt = bskySessionRequest.accessJwt
            application.bsky.refreshJwt = bskySessionRequest.refreshJwt
            application.bsky.did = bskySessionRequest.did
        
        }else {
        
            return 0
        
        }

        return 1
        
    }

    /**
     * This has never worked. Will delete
     *
     * @useCount 
     */
    public any function createInviteCode(required useCount) localmode='modern' {

        endpoint = 'xrpc/com.atproto.server.createInviteCode'   

        httpMethod = 'POST'

        params = arrayNew()

        // Authorization required
        isSessionValid()

        body = {"useCount":arguments.useCount, "forAccount":application.bsky.did}
        arrayAppend(params, {'type':'body', 'name':'body', 'value':serializeJSON(body)})

        authorizationHeader = 'Bearer '&application.bsky.accessJwt
        arrayAppend(params, {'type':'header', 'name':'Authorization', 'value':authorizationHeader})
        arrayAppend(params, {'type':'header', 'name':'Content-Type', 'value':'application/json'})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            inviteCode = deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }

        return inviteCode

    }

    // ACTOR

    /**
     * Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.
     *
     * @actor The user's did
     */
    public any function getProfile(actor) localmode='modern'{

        endpoint = 'xrpc/app.bsky.actor.getProfile'

        httpMethod = 'GET'

        actor = arguments.actor

        // Authorization required
        isSessionValid()

        if(!isDefined('arguments.actor')){
            actor = application.bsky.did
        }

        params = arrayNew()

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'actor', 'value':actor})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }
        
    }

    
    public any function getProfiles(actors) localmode='modern'{
        
    }

    /**
     * Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.
     *
     * @limit 
     * @cursor 
     */
    public any function getSuggestions(limit='100', cursor) localmode='modern'{

        endpoint = 'xrpc/app.bsky.actor.getSuggestions'

        httpMethod = 'GET'

        limit = arguments.limit

        params = arrayNew()

        // Authorization required
        isSessionValid()

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'limit', 'value':limit})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }

        
    }

    /**
     * Find actors (profiles) matching search criteria. Does not require auth.
     *
     * @term 
     * @cursor 
     */
    public any function searchActors(required term, cursor) localmode='modern'{

        endpoint = 'xrpc/app.bsky.actor.searchActors'

        httpMethod = 'GET'

        term = arguments.term

        params = arrayNew()

        // Authorization required
        isSessionValid()

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'term', 'value':term})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }
        
    }

    /**
     * Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.
     *
     * @term 
     * @limit 
     */
    public any function searchActorsTypehead(required term, limit='100') localmode='modern'{

        endpoint = 'xrpc/app.bsky.actor.searchActorsTypeahead'

        httpMethod = 'GET'

        term = arguments.term
        limit = arguments.limit

        params = arrayNew()

        // Authorization required
        isSessionValid()

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'term', 'value':term})
        arrayAppend(params, {'type':'url', 'name':'limit', 'value':limit})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }
        
    }

    // FEED

    /**
     * Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.
     *
     * @actor 
     * @limit 
     * @cursor 
     * @filter 
     */
    public any function getAuthorFeed(actor, limit='100', cursor, filter='posts_no_replies') {

        endpoint = 'xrpc/app.bsky.feed.getAuthorFeed'

        httpMethod = 'GET'

        actor = arguments.actor

        // Authorization required
        isSessionValid()

        if(!isDefined('arguments.actor')){
            actor = application.bsky.did
        }

        params = arrayNew()

        // Request Params
        arrayAppend(params, authorizationHeader())

        arrayAppend(params, {'type':'url', 'name':'actor', 'value':actor})
        arrayAppend(params, {'type':'url', 'name':'limit', 'value':arguments.limit})
        arrayAppend(params, {'type':'url', 'name':'filter', 'value':arguments.filter})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }
        
    }

    /**
     * Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.
     *
     * @algorithm 
     * @limit 
     */
    public any function getTimeline(algorithm='reverse-chronological', limit='17') localmode='modern' {

        endpoint = 'xrpc/app.bsky.feed.getTimeline'

        httpMethod = 'GET'

        algorithm = arguments.algorithm
        limit = arguments.limit

        params = arrayNew()

        // Authorization required
        isSessionValid()

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'algorithm', 'value':algorithm})
        arrayAppend(params, {'type':'url', 'name':'limit', 'value':limit})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            bskyTimeline = deserializeJSON(bskyRequest.filecontent)

        }

        return bskyTimeline
        
    }

    // GRAPH

    public any function getBlocks(limit='100', actor, cursor) localmode='modern' {

        endpoint = 'xrpc/app.bsky.graph.getBlocks'

        httpMethod = 'GET'

        limit = arguments.limit
        actor = arguments.actor

        params = arrayNew()

        // Authorization required
        isSessionValid()

        if(!isDefined('arguments.actor')){
            actor = application.bsky.did
        }

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'actor', 'value':actor})
        arrayAppend(params, {'type':'url', 'name':'limit', 'value':limit})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }
        
    }

    /**
     * Enumerates accounts which follow a specified account (actor).
     *
     * @limit 
     * @actor 
     * @cursor 
     */
    public any function getFollowers(limit='100', actor, cursor) localmode='modern' {

        endpoint = 'xrpc/app.bsky.graph.getFollowers'

        httpMethod = 'GET'

        limit = arguments.limit
        actor = arguments.actor

        params = arrayNew()

        // Authorization required
        isSessionValid()

        if(!isDefined('arguments.actor')){
            actor = application.bsky.did
        }

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'actor', 'value':actor})
        arrayAppend(params, {'type':'url', 'name':'limit', 'value':limit})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }
        
    }

    /**
     * Enumerates accounts which a specified account (actor) follows.
     *
     * @limit 
     * @actor 
     * @cursor 
     */
    public any function getFollows(limit='100', actor, cursor) localmode='modern' {

        endpoint = 'xrpc/app.bsky.graph.getFollows'

        httpMethod = 'GET'

        limit = arguments.limit
        actor = arguments.actor

        params = arrayNew()

        // Authorization required
        isSessionValid()

        if(!isDefined('arguments.actor')){
            actor = application.bsky.did
        }

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'actor', 'value':actor})
        arrayAppend(params, {'type':'url', 'name':'limit', 'value':limit})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }
        
    }

    /**
     * Enumerates accounts that the requesting account (actor) currently has muted. Requires auth.
     *
     * @limit 
     * @actor 
     * @cursor 
     */
    public any function getMutes(limit='100', actor, cursor) localmode='modern' {

        endpoint = 'xrpc/app.bsky.graph.getMutes'

        httpMethod = 'GET'

        limit = arguments.limit
        actor = arguments.actor

        params = arrayNew()

        // Authorization required
        isSessionValid()

        if(!isDefined('arguments.actor')){
            actor = application.bsky.did
        }

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'actor', 'value':actor})
        arrayAppend(params, {'type':'url', 'name':'limit', 'value':limit})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }
        
    }

    // REPO CALLS //

    /**
     * Upload a new blob, to be referenced from a repository record. The blob will be deleted if it is not referenced within a time window (eg, minutes).
     * Blob restrictions (mimetype, size, etc) are enforced when the reference is created. Requires auth, implemented by PDS
     *
     * @imageFile File path
     * @altText Alt text - not currently implemented
     */
    public any function uploadBlob(required imageFile, altText) localmode='modern' {

        endpoint = 'xrpc/com.atproto.repo.uploadBlob'

        httpMethod = 'POST'

        mime = fileGetMimeType(imageFile)

        params = arrayNew()

        // remove metadata
        cleanImage = ImageGetBlob(removeMetadata(arguments.imageFile))

        // Authorization required
        isSessionValid()

        arrayAppend(params, authorizationHeader())
        arrayAppend(params, {'type':'header', 'name':'Content-Type', 'value':mime})
        arrayAppend(params, {'type':'body', 'name':'body', 'value':cleanImage})


        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            requestContent = deserializeJSON(bskyRequest.filecontent)

            embed = {
                        "$type":"app.bsky.embed.images",
                        "images": [
                            {
                                "alt": "",
                                "image": requestContent['blob']
                            }
                        ]
                    }
            
            return embed

        }else{

            return bskyRequest

        }
        
    }

    /**
     * Create a single new repository record. Requires auth, implemented by PDS.
     *
     * @post Tex of the post
     * @createdAt 
     * @imageFile Image file path
     */
    public any function createPost(required post, createdAt=now(), imageFile) localmode='modern' {

        endpoint = 'xrpc/com.atproto.repo.createRecord'

        httpMethod = 'POST'

        params = arrayNew()

        post = arguments.post
        createdAt = DateToISO8601(arguments.createdAt)

        // Authorization required
        isSessionValid()

        repo = application.bsky.did

        facets = detectRichText(post)

        // Lets start with simple text. We will get fancy later once API is working
        record = {"text":post, "facets": facets , "createdAt":createdAt}

        // Upload media and the formatted embed
        if (isDefined('arguments.imageFile')) {

            image = arguments.imageFile

            blobImage = uploadBlob(image)

            record['embed'] = blobImage

        }

        // Request Params
        body = {"repo":repo,"collection":"app.bsky.feed.post","record":record}
        arrayAppend(params, {'type':'body', 'name':'body', 'value':serializeJSON(body)})

        arrayAppend(params, authorizationHeader())
        arrayAppend(params, {'type':'header', 'name':'Content-Type', 'value':'application/json'})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }
        
    }

    /**
     * Delete a repository record, or ensure it doesn't exist. Requires auth, implemented by PDS.
     *
     * @record The record key. Usually extraccted from the record uri
     */    
    public any function deletePost(required record) {

        endpoint = 'xrpc/com.atproto.repo.deleteRecord'

        httpMethod = 'POST'

        params = arrayNew()

        // Authorization required
        isSessionValid()

        repo = application.bsky.did

        // Request Params
        arrayAppend(params, authorizationHeader())

        body = {"repo":repo,"collection":"app.bsky.feed.post","rkey":record}
        arrayAppend(params, {'type':'body', 'name':'body', 'value':serializeJSON(body)})
        arrayAppend(params, {'type':'header', 'name':'Content-Type', 'value':'application/json'})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }


        
    }

}