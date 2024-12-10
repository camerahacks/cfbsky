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
     * Get URL embed info
     *
     * @url 
     */
    public any function getEmbedInfo(required url) localmode='modern' {

        httpService = new http(method = 'GET', url = arguments.url)


        embedRequest = httpService.send().getPrefix()

        html = htmlParse( embedRequest.filecontent )

        embedInfo = {}

        // Use Open Graph attributes
        embedInfo['embedImage'] = xmlSearch(html, "//*[@property='og:image']")
        if(embedInfo['embedImage'].len()){

            embedInfo['embedImage'] = embedInfo['embedImage'][1]['XmlAttributes']['content']

        }

        embedInfo['embedTitle'] = xmlSearch(html, "//*[@property='og:title']")
        if(embedInfo['embedTitle'].len()){

            embedInfo['embedTitle'] = embedInfo['embedTitle'][1]['XmlAttributes']['content']

        }else {
            // If there is not open graph (og:) attribute, use the page title
            embedInfo['embedTitle'] = html.html.head.title.XmlText

        }

        embedInfo['embedDescription'] = xmlSearch(html, "//*[@property='og:description']")
        if(embedInfo['embedDescription'].len()){

            embedInfo['embedDescription'] = embedInfo['embedDescription'][1]['XmlAttributes']['content']

        } else {
            
            embedInfo['embedDescription'] = embedInfo['embedTitle']

        }

        return embedInfo


        
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
     * @record 
     */
    public any function detectURL(required record) localmode='modern' {


        record = arguments.record
        postText = record.text

        // Regex to find link
        // Credit where credit is due. Pattern from this post: https://stackoverflow.com/a/190405
        rePattern = 'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~##=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~##?&//=]*)'

        reResultArray = reFindNoCase(rePattern, postText, 1, True, 'all')

        // check if there is a match
        if(arrayLen(reResultArray)>=1 AND reResultArray[1].pos[1]!=0){

            offset = 0

            for(matches in reResultArray){

                // If a link is greater than 30 char, make it shorter in the post text
                if( matches.len[1] GT 30 ){

                    byteStart = matches.pos[1] - offset - 1
                    byteEnd = matches.pos[1] + 30 - 1
                    offset = offset + (matches.len[1] - 30)
                    shortURL = shortenURL(matches.match[1])
                    record['text'] = replace(postText, matches.match[1], shortenURL)

                }else {
                    
                    byteStart = matches.pos[1] - offset - 1
                    byteEnd = matches.pos[1] - offset + matches.len[1] - 1

                }

                record.facets.push({
                    'index': {
                        'byteStart': byteStart,
                        'byteEnd': byteEnd
                    },
                    'features': [
                        {'$type': 'app.bsky.richtext.facet##link', 'uri': matches.match[1]}
                    ]
                })

            }
        }

        return record;
        
    }

    /**
     * Shorten an url to 30 characters
     *
     * @url 
     */
    public any function shortenURL(required url) localmode='modern' {

        return left(arguments.url, 27)&'...'
        
    }

    /**
     * Detect mention in post text
     *
     * @record 
     */    
    public any function detectMention(required record) localmode='modern' {

        record = arguments.record

        // Regex to find mentions
        rePatternMention = '(@([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)'

        reResultArrayMention = reFindNoCase(rePatternMention, record.text, 1, true, 'all')

        // Check if there is a match
        if(arrayLen(reResultArrayMention)>=1 AND reResultArrayMention[1].pos[1]!=0){

            for(matches in reResultArrayMention){

                // Only add the mention if the handle exists
                if(resolveHandle(matches.match[1]) != 0){

                    record.facets.push({
                        'index': {
                            'byteStart': matches.pos[1] - 1,
                            'byteEnd': matches.pos[1] + matches.len[1] - 1
                        },
                        'features': [
                            {'$type': 'app.bsky.richtext.facet##mention', 'did': resolveHandle(matches.match[1])}
                        ]
                    })

                }

            }
        }

        return record
        
    }

    /**
     * Detect mention in post text
     *
     * @record 
     */    
    public any function detectHashtag(required record) localmode='modern' {

        record = arguments.record

        // Regex to find mentions
        rePatternHashtag = '(##+[a-zA-Z0-9(_)]{1,})'

        reResultArrayHashtag = reFindNoCase(rePatternHashtag, record['text'] , 1, true, 'all')

        // Check if there is a match
        if(arrayLen(reResultArrayHashtag)>=1 AND reResultArrayHashtag[1].pos[1]!=0){

            for(matches in reResultArrayHashtag){

                record.facets.push({
                    'index': {
                        'byteStart': matches.pos[1] - 1,
                        'byteEnd': matches.pos[1] + matches.len[1] - 1
                    },
                    'features': [
                        {'$type': 'app.bsky.richtext.facet##tag', 'tag': replace(matches.match[1], '##', '')}
                    ]
                })

            }
        }

        return record
        
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

            // TODO: Should raise an error here for not being authorized
        
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
    public any function getSuggestions(limit='100', cursor='') localmode='modern'{

        endpoint = 'xrpc/app.bsky.actor.getSuggestions'

        httpMethod = 'GET'

        limit = arguments.limit

        params = arrayNew()

        // Authorization required
        isSessionValid()

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'limit', 'value':limit})
        arrayAppend(params, {'type':'url', 'name':'cursor', 'value':arguments.cursor})

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
    public any function searchActors(required term, cursor='') localmode='modern'{

        endpoint = 'xrpc/app.bsky.actor.searchActors'

        httpMethod = 'GET'

        term = arguments.term

        params = arrayNew()

        // Authorization required
        isSessionValid()

        // Request Params
        arrayAppend(params, authorizationHeader())
        
        arrayAppend(params, {'type':'url', 'name':'term', 'value':term})
        arrayAppend(params, {'type':'url', 'name':'cursor', 'value':arguments.cursor})

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
    public any function getAuthorFeed(actor, limit='100', cursor='', filter='posts_no_replies') {

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
        arrayAppend(params, {'type':'url', 'name':'cursor', 'value':arguments.cursor})

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
     * @cursor
     */
    public any function getTimeline(algorithm='reverse-chronological', limit='17', cursor='') localmode='modern' {

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
        arrayAppend(params, {'type':'url', 'name':'cursor', 'value':arguments.cursor})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            bskyTimeline = deserializeJSON(bskyRequest.filecontent)

        }

        return bskyTimeline
        
    }

    // 
    // GRAPH
    // 

    /**
     * Enumerates which accounts the requesting account is currently blocking. Requires auth.
     *
     * @limit >= 1 and <= 100
     * @actor 
     * @cursor 
     */
    public any function getBlocks(limit='100', actor, cursor='') localmode='modern' {

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
        arrayAppend(params, {'type':'url', 'name':'cursor', 'value':arguments.cursor})

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
    public any function getFollowers(limit='100', actor, cursor='') localmode='modern' {

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
        arrayAppend(params, {'type':'url', 'name':'cursor', 'value':arguments.cursor})

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
    public any function getFollows(limit='100', actor, cursor='') localmode='modern' {

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
        arrayAppend(params, {'type':'url', 'name':'cursor', 'value':arguments.cursor})

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
    public any function getMutes(limit='100', actor, cursor='') localmode='modern' {

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
        arrayAppend(params, {'type':'url', 'name':'cursor', 'value':arguments.cursor})

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
            
            return requestContent

        }else{

            return bskyRequest

        }
        
    }

    /**
     * Create a single new repository record. Requires auth, implemented by PDS.
     *
     * @post Tex of the post
     * @createdAt 
     * @imageFile Image file path or CFML image object
     */
    public any function createPost(required post, createdAt=now(), imageFile) localmode='modern' {

        endpoint = 'xrpc/com.atproto.repo.createRecord'

        httpMethod = 'POST'

        params = arrayNew()

        postText = arguments.post
        createdAt = DateToISO8601(arguments.createdAt)

        // Create the basic shell of the record
        record = {"text": postText, "createdAt": createdAt}

        // Upload media and the formatted embed. Image takes precedence as an embed
        if (isDefined('arguments.imageFile')) {

            image = arguments.imageFile

            blobImage = uploadBlob(image)

            record['embed'] = {
                "$type":"app.bsky.embed.images",
                "images": [
                    {
                        "alt": "",
                        "image": blobImage['blob']
                    }
                ]
            }

        }

        // Authorization required
        isSessionValid()

        repo = application.bsky.did

        // TO-DO: This (adding facets) should all probably live in its own function
        record['facets'] = []
        
        record = detectURL(record)

        record = detectHashtag(record)
        
        record = detectMention(record)

        if(arrayLen(record['facets'])){

            // embed the first link if there are no embeds. Images take priority
            if(!isDefined('record.embed')){

                // find the first facet that is a link
                linkEmbeds = arrayFilter(record['facets'], function(f){

                    return f['features'][1]['$type'] == 'app.bsky.richtext.facet##link'

                })

                if( linkEmbeds.len() ){

                    embedInfo = getEmbedInfo(linkEmbeds[1]['features'][1]['uri'])

                    record['embed'] = {
                        "$type":"app.bsky.embed.external",
                        "external": 
                            {
                                "uri": linkEmbeds[1]['features'][1]['uri'],
                                "title": embedInfo['embedTitle'],
                                "description": embedInfo['embedDescription']
    
                            }
                        
                    }
    
                    // if the card has an image, embed it.
                    if (embedInfo['embedImage'].len()){
    
                        embedImage =  uploadBlob(imageRead(embedInfo['embedImage']))
    
                        record['embed']['external']['thumb'] = embedImage['blob']
                    
                    }

                }

            }
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