component hint="BlueSky Calls" displayname="BlueSky Calls" output="false" {

    public function init(){

        local_useragent = 'cfcbsky'

        local_apiURL = 'https://bsky.social/'

        bsky_identifier = application.bsky.identifier

        bsky_password = application.bsky.password

		return this;
	}

    // HELPER FUNCTIONS

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

    
    public any function authorizationHeader() {

        authorizationHeader = 'Bearer '&application.bsky.accessJwt

        return {'type':'header', 'name':'Authorization', 'value':authorizationHeader}

        
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

    
    public array function detectRichText(required post) {

        // Regex to find link
        rePattern = '(^|\s|\()((https?:\/\/[\S]+)|(([a-z][a-z0-9]*(\.[a-z0-9]+)+)[\S]*))'

        reResultArray = reFindNoCase(rePattern, arguments.post, 1, True, 'all')

        facets = arrayNew()

        // check if there is a match
        if(arrayLen(reResultArray)>=1 AND reResultArray[1].pos[1]!=0){

            for(matches in reResultArray){

                facets.push({
                    'index': {
                        'byteStart': matches.pos[3]-1,
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

    // SERVER

    
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

    // REPO

    
    public any function createPost(required post, createdAt=now()) localmode='modern' {

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

}