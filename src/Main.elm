module Main exposing (Model, Msg(..), User, init, main, update, view)

import Browser
import Html exposing (Html, button, div, input, text)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)


main =
    Browser.sandbox { init = init, update = update, view = view }



-- MODEL


type alias User =
    { first_name : String, last_name : String, email : String, id_token : String }


type Model
    = SignedIn User
    | SignedOut User


init : Model
init =
    SignedOut { first_name = "", last_name = "", email = "", id_token = "" }



-- UPDATE


type Msg
    = SignIn User
    | SignOut


update : Msg -> Model -> Model
update msg model =
    case msg of
        SignIn user ->
            SignedIn user

        SignOut ->
            SignedOut { first_name = "", last_name = "", email = "", id_token = "" }



-- VIEW


view : Model -> Html Msg
view model =
    case model of
        SignedOut user ->
            div [] [ text "Signed out!" ]

        SignedIn user ->
            div [] [ text user.first_name ]
