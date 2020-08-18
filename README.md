PubAnnotation
=============

*A scalable and sharable storage system of literature annotation.*

It is based on a production level DBMS, e.g., PostgreSQL, which makes it *scaleable*.
Annotation data on PubAnnotation are *shareable* and *comparable* even if they come from different annotation projects.

Requirement
-----------

Please use it with
* ruby version 2.3.4
* Postgresql 9.0 or above, and
* ElasticSearch 5
If your system does not already have an installation of ruby, you need to install it. Using [rvm](https://rvm.io/) is generally a recommended way to install ruby in your system.

Installation
------------

1. git clone https://github.com/pubannotation/pubannotation.git
2. cd pubannotation
3. bundle install

Setup
-----
1. Edit config/database.yml as you like
2. RAILE_ENV=production rake db:create
3. RAILE_ENV=production rake db:migration
4. RAILE_ENV=production rake assets:precompile

Deploy
-----

rails s -e production

(You will encounter an error message with an instruction to set a secret key for devise. Please follow the instruction.)

License
-------

The PubAnnotation repository (http://pubannotation.org) is freely available to anyone. The whole software system is also freely available under [MIT license](http://opensource.org/licenses/MIT).

## Deployment

### Google authentication procedure

Execute the following ur in the browser and log in with the pubannotation specific user account.
```
https://console.developers.google.com/
```

Create a pubannotation project.
Example:
```
pubannotation
```

Click link(Enable APIs and services) to activate the API library:
```
Gmail API
```

OAuth consent screen.

User Type:
```
External
```
application name:
```
pubannotation
```

Create authentication information(OAuth Client ID).
Application type:
```
Web Application
```
After creating an OAuth client, client id and client secret are generated:

client id
```
99999999999-xx99x9xx9xxxxxx9x9xx9xx9xxxxxx.apps.googleusercontent.com
```
client secret
```
xxxxxxxxx9xxxx9xx9x9xx99
```

Add an approved redirect URI.
```
[Same URL as environment variable(pubannotation)]/users/auth/google_oauth2/callback
```

### Create .env file.
```
cp .env.example .env
```

### .env file settings.
```
CLIENT_ID=[Generated client id]
CLIENT_SECRET=[Generated client secret]
```
