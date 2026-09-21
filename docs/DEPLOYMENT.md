# Deployment guide

[Back to README](../README.md) · [Development guide](DEVELOPMENT.md)

See the [requirements and service setup instructions](DEVELOPMENT.md#requirements) for the required dependencies. The Docker Compose stack described in the development guide is for local development.

Run the commands below from the repository root.

## Production environment

Start the Rails application and Sidekiq worker with the environment variables required for production.

Required production environment variables include:

```
DEVISE_SECRET_KEY=[Generated Devise secret key]
GOOGLE_CLIENT_ID=[Generated Google OAuth client id]
GOOGLE_CLIENT_SECRET=[Generated Google OAuth client secret]
RECAPTCHA_SITE_KEY=[Generated reCAPTCHA site key]
RECAPTCHA_SECRET_KEY=[Generated reCAPTCHA secret key]
REDIS_URL=redis://localhost:6379/0
ELASTICSEARCH_URL=http://localhost:9200
```

`ELASTICSEARCH_API_KEY` can also be set when the Elasticsearch cluster requires API key authentication.

## Authentication and reCAPTCHA

### Google authentication procedure

Open the following URL in the browser and log in with the PubAnnotation-specific Google account.
```
https://console.developers.google.com/
```

Create a pubannotation project.
Example:
```
pubannotation
```

Configure the OAuth consent screen and create an OAuth Client ID for Google sign-in.

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
[Application base URL]/users/auth/google_oauth2/callback
```

### Create .env file.
```
cp .env.example .env
```

### .env file settings.
```
GOOGLE_CLIENT_ID=[Generated client id]
GOOGLE_CLIENT_SECRET=[Generated client secret]
```

### ReCAPTCHA settings procedure

Access the Google reCAPTCHA site and log in with your Google account.
```
https://www.google.com/recaptcha/admin/create
```

The first screen that opens is the paid Enterprise version.  
Click "Switch to create a legacy key" to switch to the free version.
```
Switch to create a legacy key
```

Enter the required information.

label:
```
pubannotation
```

reCAPTCHA type:
```
v2 "I'm not a robot" checkbox
```

domain:  
Add your domain, example:
```
example.com
```

After you register your site, site_key and secret_key are generated.  
Add keys to .env file to use reCAPTCHA on your app.
```
RECAPTCHA_SITE_KEY=[Generated site key]
RECAPTCHA_SECRET_KEY=[Generated secret key]
```

