# Access to the API

Following is documentation on ways to access the API from various
software contexts.

For general information on using the API, see [api.md](api.md).

## Access from shell (bash) using wget

`wget` is a common shell utility, similar to `curl`, for doing HTTP
requests.  Suppose the API token is in a file called `api.token`.  The
following illustrates use of `wget` with the `cypher` service:

    wget -O cypher.out --header "Authorization: JWT `cat api.token`" \
      https://eol.org/service/cypher?query="MATCH (n:Trait) RETURN n LIMIT 1;"

Or, if the Cypher query is in a file called `query.cypher`:

    wget -O cypher.out --header "Authorization: JWT `cat api.token`" \
      https://eol.org/service/cypher?query="`cat query.cypher`"

These commands may only work from `bash`, which is the shell that I
use, and the standard shell on most GNU/Linux systems.


## Access from shell using curl
Example POST request with a query in file `query.cypher`:
   
    curl https://eol.org/service/cypher -H "Authorization: JWT $(cat api.token)" \
        --data-urlencode query@query.cypher
        
You'll need to POST lengthy queries due to URL length limits. This is likely also possible with `wget`
but hasn't been tested.

## Access using python

A simple python program that invokes the `/service/cypher` API call is
given here.  The name of the file containins the token is given as a
command line argument, and the query is given as a second command line
argument, for example (typed at the shell):

    python3 cypher.py --tokenfile=api.token --query="MATCH (n:Trait) RETURN n LIMIT 1;"

For `cypher.py` see [here](cypher.py).  This module may be adapted for
use in particular python programs.

*Warning:* The beta.eol.org site uses TLS1.2 for connection privacy
(`https:`).  This version of TLS seems to be not fully supported in
the version of Python that is built in to MacOS 10.12 (Sierra), and
may be absent from tools of similar vintage.  If the example fails
with an SSL error, make sure you have an up to date version of openssl
(1.0.1 works, at least) and a version of Python that uses it.  I find
this puzzling since TLS 1.2 was published ten years ago, but I am just
relaying my experience.


## Access from a web form

Put the following in a file with extension `.html`, and open it in a
browser.  This mode of use does not require a token if you are logged
in to the EOL site.

```
<h1>Cypher query</h1>
<form action='https://eol.org/service/cypher'>
  <textarea name='query' id='query' cols='50' rows='5'>MATCH (n:Trait) RETURN n LIMIT 1;</textarea>
  <input type='submit' />
</form>
```

