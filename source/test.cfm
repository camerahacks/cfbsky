<cfscript>
dump(application)

bskyAPI = new CFC.bskyEngine()

test = bskyAPI.getTimeline()

dump(test)

dump(application)

</cfscript>