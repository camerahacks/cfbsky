<cfscript>
    
    bskyAPI = new source.CFC.bskyEngine()
    
    // Create a post with a mention and a Hashtag
    example = bskyAPI.createPost(post='This is an API test and will be deleted in a few minutes! Thanks @makerbymistake.com for this BlueSky ##CFML API!')
    
    dump(example)
    
</cfscript>