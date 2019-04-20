# resource-website [![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/resource-website.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/resource-website)

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

Build the docker images
```
docker-compose build
```

Run the containers
```
docker-compose up
```

## backend [![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/resource-website-backend.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/resource-website-backend)
Coded in Rust, manages database manipulation using AJAX requests from frontend.

## frontend [![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/resource-website-frontend.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/resource-website-frontend)
