PubAnnotation
=============

*A scalable and sharable storage system of literature annotation.*

It is based on a production level DBMS, e.g., PostgreSQL, which makes it *scaleable*.
Annotation data on PubAnnotation are *shareable* and *comparable*, even if they come from different annotation projects.

Requirement
-----------

Please use it with
* ruby version 3.4.5,
* PostgreSQL 9.0 or above,
* Elasticsearch 8.x,
* [redis](https://redis.io/)
* [Ollama](https://ollama.com/) (for media caption generation)
* [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (for audio transcription)
* [ffmpeg](https://ffmpeg.org/) (for detecting silent audio and extracting audio from video before transcription)

### Ollama setup (for media caption generation)

Install Ollama:
```
$ brew install ollama
```

Start Ollama:
```
$ ollama serve
```

Pull the moondream model:
```
$ ollama pull moondream
```

### whisper.cpp setup (for audio transcription)

Install whisper.cpp:
```
$ brew install whisper-cpp
```

Download a model (e.g. base.en; the Homebrew formula does not bundle a download script, so fetch the `.bin` file directly):
```
$ mkdir -p ~/models
$ curl -L -o ~/models/ggml-base.en.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
```

Note: the Homebrew build has no `whisper-server` binary, so transcription runs via `whisper-cli` directly instead of an HTTP server:
```
$ whisper-cli -m ~/models/ggml-base.en.bin -f path/to/audio.wav
```

### ffmpeg setup (for detecting silent audio and extracting audio from video before transcription)

Install ffmpeg:
```
$ brew install ffmpeg
```

If your system does not already have an installation of ruby, you need to install it. Using [rvm](https://rvm.io/) is generally a recommended way to install ruby in your system.

### Job execution preparation for Mac
#### Redis installation

```
$ brew install redis
```

#### Launch Redis

Start redis-server by specifying the location of `redis.conf`.
```
$ redis-server /usr/local/etc/redis.conf
```


## For development
### Docker Compose

With Docker Engine/Docker Desktop and Docker Compose installed, run:

```sh
docker compose up --build -d
docker compose logs -f setup ollama-setup web worker
```

Open http://localhost:3000. Set `PUBANNOTATION_PORT=3001` before the command if
port 3000 is already in use. The first build downloads Ruby and the gems and can
take several minutes.

The development stack includes Ruby 4.0.5, Rails, a Sidekiq worker, PostgreSQL 17,
Redis 7.4, Elasticsearch 9 (matching the current Elasticsearch client gem), and
Ollama 0.34.2.
Compose waits for the backing services, then prepares the database and search
index before starting web and worker. A fresh database loads `db/seeds.rb`,
including the development account `admin@pubannotation.org` / `abc123`.
This configuration is for local development; only the web port is published,
on localhost.

Source files are mounted from the checkout. Rebuild after changing the Gemfile
or Dockerfile. Database, Redis, search, Ollama models, uploaded files, logs, and temporary files
use Docker volumes, separate from the host's local development data.

```sh
docker compose exec web bin/rails console
docker compose logs --tail=100 worker
docker compose down
```

`docker compose down` keeps the data. `docker compose down --volumes` deletes all
data belonging to this Compose stack. To rerun database preparation after adding
migrations, run `docker compose run --rm setup`.

Rails reads an optional `.env` in the mounted checkout for OAuth and reCAPTCHA
credentials (see `.env.example`). Database, Redis, and Elasticsearch connections
are set by Compose. No image-processing gems are added; the existing Active
Storage image-variant warning may still appear.

Ollama runs on CPU by default, without requiring a host installation or GPU.
On first startup, `ollama-setup` downloads the `moondream` image-captioning model;
web and worker wait until the download succeeds. This requires additional disk
space and download time. The model is kept in the `ollama_data` volume and reused
on subsequent starts. Rails and worker connect to `ollama:11434` internally;
the Ollama port is not published on the host.

Set `OLLAMA_CAPTION_MODEL` in `.env` to use another vision-capable model, then run
`docker compose up -d` to download it and update web and worker together.
To inspect the installed models or explicitly update the current model:

```sh
docker compose exec ollama ollama list
docker compose run --rm --entrypoint /bin/sh ollama-setup -c 'ollama pull "$OLLAMA_CAPTION_MODEL"'
```

whisper.cpp and its model, the embedding service, and Stardog are not included.
ffmpeg is installed, but transcription and features
using those external services require additional configuration. Inside a
container, `localhost` refers to that container, not the host machine.

### Setup and Start

1. git clone https://github.com/pubannotation/pubannotation.git
2. cd pubannotation
3. bin/setup

`bin/setup` installs dependencies, prepares the database, clears logs and temporary files, and starts the development processes through `bin/dev`.

If you only want to set up the application without starting the server, run:
```
bin/setup --skip-server
```

To start the development processes later, run:
```
bin/dev
```

### Test
This project uses RSpec for testing. To run the tests, execute:
```
bundle exec rspec
```

### Start sidekiq worker only

Start the worker by specifying the location of sidekiq.yml.

By starting a worker by specifying a queue, only Jobs that belong to that queue can be executed.
```
# Start sidekiq
$ bundle exec sidekiq -C config/sidekiq.yml

# Start by specifying a queue
$ bundle exec sidekiq -C config/sidekiq.yml -q general
```

Deploy
-----

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

License
-------

The PubAnnotation repository (http://pubannotation.org) is freely available to anyone. The whole software system is also freely available under [MIT license](http://opensource.org/licenses/MIT).

## Deployment

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
