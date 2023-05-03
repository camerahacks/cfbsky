<cfscript>
dump(application)

bskyAPI = new CFC.bskyEngine()

test = bskyAPI.createPost(post="I'm creating a ##CFML wrapper for bluesky and this is the first post using the module")

dump(test)

dump(application)

</cfscript>