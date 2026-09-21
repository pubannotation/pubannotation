PubAnnotation
=============

*A scalable and sharable storage system of literature annotation.*

It is based on a production level DBMS, e.g., PostgreSQL, which makes it *scaleable*.
Annotation data on PubAnnotation are *shareable* and *comparable*, even if they come from different annotation projects.

## Guides

- [Development guide](docs/DEVELOPMENT.md): requirements, service setup, Docker Compose, local development, tests, and Sidekiq.
- [Deployment guide](docs/DEPLOYMENT.md): production environment variables, Google authentication, and reCAPTCHA.

## API

### POST /textae
Sending a POST request to /textae with an annotation in the body returns a URL that generates HTML with the annotation opened in TextAE.     
Specify JSON or SimpleInlineTextAnnotationFormat annotation to the body.

#### Request Examples
Please specify the content-type according to the body.

##### JSON
```
curl --globoff -X POST https://pubannotation.org/textae \
  -H "Content-Type: application/json" \
  -d '{
         "text": "Elon Musk is a member of the PayPal Mafia.",
         "denotations":[
           {"span":{"begin": 0, "end": 9}, "obj":"Person"}
         ]
       }'
```


##### SimpleInlineTextAnnotationFormat
```
curl -X POST https://pubannotation.org/textae \
  -H "Content-Type: text/plain" \
  -d "[Elon Musk][Person] is a member of the PayPal Mafia.

      [Person]: https://example.com/Person"
```

Notes:   
If you want to specify BODY from a file, you need to send the data in binary format to keep the newlines.

curl example:   
Use `--data-binary` option instead of `-d`
```
curl -X POST http://pubannotation.org/textae \
  -H "Content-Type: text/plain" \
  --data-binary @sample.txt
```

License
-------

The PubAnnotation repository (http://pubannotation.org) is freely available to anyone. The whole software system is also freely available under [MIT license](http://opensource.org/licenses/MIT).
