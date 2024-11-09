# BlueSky CFML
cfbsky is a CFML BlueSky API Wrapper cfc component. The goal is to keep everything in one cfc so you can just copy this to your application folder and start using it right away. No setup needed besides adding the two variables below to ```Application.cfc```

### Required Application.cfc variables:

```application.bsky.identifier = <handle or did>``` - Your BlueSky handle or did

```application.bsky.password = <password>``` - BlueSky password

### Authentication

BlueSky authentication is handled on the fly if the API calls requires authentication. Before making the call, the code checks if there is a valid BlueSky session stored in the ```application``` scope.

### WARNING

This is a work in progress and there is no error handling implemented. For now, please do your own error handling.