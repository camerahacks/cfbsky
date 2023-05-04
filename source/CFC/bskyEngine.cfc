component hint="BlueSky Calls" displayname="BlueSky Calls" output="false" {

    public function init(){

        local_useragent = 'cfcbsky'

        local_apiURL = 'https://bsky.social/'

        bsky_identifier = application.bsky.identifier

        bsky_password = application.bsky.password

		return this;
	}

    
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

    // FEED

    public any function getTimeline(algorithm='reverse-chronological', limit='17') localmode='modern' {

        endpoint = 'xrpc/app.bsky.feed.getTimeline'

        httpMethod = 'GET'

        algorithm = arguments.algorithm
        limit = arguments.limit

        params = arrayNew()

        // Authorization required
        isSessionValid()

        authorizationHeader = 'Bearer '&application.bsky.accessJwt
        arrayAppend(params, {'type':'header', 'name':'Authorization', 'value':authorizationHeader})
        
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

        authorizationHeader = 'Bearer '&application.bsky.accessJwt
        arrayAppend(params, {'type':'header', 'name':'Authorization', 'value':authorizationHeader})
        
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

        authorizationHeader = 'Bearer '&application.bsky.accessJwt
        arrayAppend(params, {'type':'header', 'name':'Authorization', 'value':authorizationHeader})
        
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

        authorizationHeader = 'Bearer '&application.bsky.accessJwt
        arrayAppend(params, {'type':'header', 'name':'Authorization', 'value':authorizationHeader})
        
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

        authorizationHeader = 'Bearer '&application.bsky.accessJwt
        arrayAppend(params, {'type':'header', 'name':'Authorization', 'value':authorizationHeader})
        
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

    
    public any function createPost(repo=application.bsky.did, required post, createdAt=now()) localmode='modern' {

        endpoint = 'xrpc/com.atproto.repo.createRecord'

        httpMethod = 'POST'

        params = arrayNew()

        repo = arguments.repo
        post = arguments.post
        createdAt = DateToISO8601(arguments.createdAt)

        // Authorization required
        isSessionValid()

        // Lets start with simple text. We will get fancy later once API is working
        record = {"text":post, "createdAt":createdAt}

        body = {"repo":repo,"collection":"app.bsky.feed.post","record":record}
        arrayAppend(params, {'type':'body', 'name':'body', 'value':serializeJSON(body)})

        authorizationHeader = 'Bearer '&application.bsky.accessJwt
        arrayAppend(params, {'type':'header', 'name':'Authorization', 'value':authorizationHeader})
        arrayAppend(params, {'type':'header', 'name':'Content-Type', 'value':'application/json'})

        bskyRequest = sendRequest(endpoint, httpMethod, params)

        if(bskyRequest.statuscode=="200 OK"){

            return deserializeJSON(bskyRequest.filecontent)

        }else{

            return bskyRequest

        }
        
    }

}