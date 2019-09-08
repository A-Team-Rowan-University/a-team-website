# resource-website [![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/a-team-website.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/a-team-website)

The central server used for managing the databases of the ECE Apprengineering Team at Rowan University.

## Usage
First, clone this repo:
```
git clone https://github.com/A-Team-Rowan-University/resource-website`
```

Then, cd to it
```
cd resource-website
```

Init and update the submodules
```
git submodule init
git submodule update
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

## What is included in this repository

This repo includes the backend api server, apache configs, and Dockerfiles to run them all.

The webdev_lib that does all the backend heavy lifting is located at https://github.com/A-Team-Rowan-University/resource-website-backend.
[![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/resource-website-backend.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/resource-website-backend)

The frontend resources that get served for the website are at https://github.com/A-Team-Rowan-University/resource-website-frontend.
[![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/resource-website-frontend.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/resource-website-frontend)

