# resource-website [![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/a-team-website.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/a-team-website)

The central server used for managing the databases of the ECE Apprengineering Team at Rowan University.

## Usage
First, clone this repo:
```
git clone https://github.com/A-Team-Rowan-University/a-team-website
```

Then, cd to it
```
cd a-team-website
```

Build the images with
```
docker-compose build
```

Create and run the containers
```
docker-compose up -d
```

You can stop the running containers with
```
docker-compose stop
```

And start the them again (without rebuilding them) with
```
docker-compose start
```

And finally, remove the containers and images
```
docker-compose down
```

See `docker-compose --help` for more information

Also you can use the debug script for simplicity
```
./debug_run.sh
```
