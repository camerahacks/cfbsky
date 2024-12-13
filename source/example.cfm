<cfscript>
    
    bskyAPI = new source.CFC.bskyEngine()

    actor = 'makerbymistake.com'
    
    // Create a post with a mention and a Hashtag
    example = bskyAPI.createPost(post='This is an API test and will be deleted in a few minutes! Thanks @makerbymistake.com for this BlueSky ##CFML API!')
    
    dump(example)

    // Get user lists
    example = bskyAPI.getLists(actor)

    dump(example)

    // Get the posts from the user's first list
    example = example['lists'][1]['uri'] ? bskyAPI.getListFeed(example['lists'][1]['uri']) : 'User doesn''t have any lists'

    dump(example)
    
</cfscript>