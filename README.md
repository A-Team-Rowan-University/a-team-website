## resource-website-backend [![Build Status](https://api.travis-ci.org/A-Team-Rowan-University/resource-website-backend.svg?branch=master)](https://travis-ci.org/A-Team-Rowan-University/resource-website-backend)
Coded in Rust, manages database manipulation using AJAX requests from frontend.

### Dependencies:
* [Rouille 3.0.0](https://github.com/tomaka/rouille)
* [Diesel 1.3.3](https://github.com/diesel-rs/diesel)
* [dotenv 0.13.0](https://github.com/sgrif/rust-dotenv)
* [serde 1.0](https://github.com/serde-rs/serde)
* [serde_json 1.0](https://github.com/serde-rs/json)
* [log 0.4](https://github.com/rust-lang-nursery/log)
* [simplelog](https://github.com/drakulix/simplelog.rs)

### API Calls

`GET /users`
Gets information about every user in the system. Returns a List of Users.

`GET /users/{id: u64}`
Gets information about the user with the given id. Returns a single User.

`POST /users`
Creates a new user. The body of POST should be a valid User. Returns the id of the created user.

`POST /users/{id: u64}`
Updates a given user.

### Data Models

Many of the API calls share a common set of data models, represented in JSON format.

#### User
| Property Name | Type   | Optional | Description |
|---------------|--------|----------|-------------|
| id            | u64    | No       | The internal id of the user |
| first_name    | String | No       | The first name of the user |
| last_name     | String | no       | The last name of the user |
| banner_id     | u64    | No       | The banner id of the user |
| email         | String | Yes      | The Rowan email of the user. If the user does not have an email, this will be null of non-existent |
```
{
    "id": 11,
    "first_name": "John"
    "last_name": "Smith",
    "banner_id": 9162xxxxx,
    "email": "smithj1@students.rowan.edu"
}
```

#### Partial User
| Property Name | Type   | Optional | Description |
|---------------|--------|----------|-------------|
| first_name    | String | Yes      | The first name of the user |
| last_name     | String | Yes      | The last name of the user |
| banner_id     | u64    | Yes      | The banner id of the user |
| email         | String | Yes      | The Rowan email of the user. If the user does not have an email, this will be null of non-existent |
```
{
    "first_name": "John"
    "last_name": "Smith",
    "banner_id": 9162xxxxx,
    "email": "smithj1@students.rowan.edu"
}
```

#### List of Users
| Property Name | Type          | Optional | Description     |
|---------------|---------------|----------|-----------------|
| users         | List of Users | No       | A list of Users |
```
{
    "users": [
    {
    "first_name": "John"
    "last_name": "Smith",
    "banner_id": 9162xxxxx,
    "email": "smithj1@students.rowan.edu"
    },
    {
    "first_name": "Mike"
    "last_name": "Johnson",
    "banner_id": 9162xxxxx,
    "email": "johnsonm1@students.rowan.edu"
    }
    ]
}
```
