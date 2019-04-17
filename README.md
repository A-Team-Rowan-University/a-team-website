# resource-website [![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/resource-website.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/resource-website)

The central server used for managing the databases of the ECE Apprengineering Team at Rowan University.

## backend [![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/resource-website-backend.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/resource-website-backend)
Coded in Rust, manages database manipulation using AJAX requests from frontend.

### Dependencies:
* [Rouille 3.0.0](https://github.com/tomaka/rouille)
* [Diesel 1.3.3](https://github.com/diesel-rs/diesel)
* [dotenv 0.13.0](https://github.com/sgrif/rust-dotenv)
* [serde 1.0](https://github.com/serde-rs/serde)
* [serde_json 1.0](https://github.com/serde-rs/json)
* [log 0.4](https://github.com/rust-lang-nursery/log)
* [simplelog](https://github.com/drakulix/simplelog.rs)

## frontend [![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/resource-website-frontend.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/resource-website-frontend)
Coded in Elm, makes requests to the backend to access database and returns to the user.

### Dependencies:
* Core Elm Packages
   * [browser](https://github.com/elm/browser)
   * [core](https://github.com/elm/core)
   * [html](https://github.com/elm/html)
   * [http](https://github.com/elm/http)
   * [json](https://github.com/elm/json)
   * [url](https://github.com/elm/url)
   * [bytes](https://github.com/elm/bytes)
   * [file](https://github.com/elm/file)
   * [time](https://github.com/elm/time)
   * [virtual-dom](https://github.com/elm/virtual-dom)
* [elm-json-decode-pipeline 1.0.0](https://github.com/NoRedInk/elm-json-decode-pipeline)
* [elm-format-number 6.0.2](https://github.com/cuducos/elm-format-number)
* [elm-round 1.0.4](https://github.com/myrho/elm-round)
