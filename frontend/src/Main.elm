module Main exposing (Model(..), Msg(..), Page(..), init, main, subscriptions, update, view)

import Browser
import FormatNumber exposing (format)
import FormatNumber.Locales exposing (usLocale)
import Html exposing (Attribute, Html, div, h1, span, text, ul)
import Http
import Json.Decode as Decode exposing (Decoder, field, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required)
import User


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type Model
    = User User.UserModel


type Msg
    = GotUserMsg User.UserMsg


init : () -> ( Model, Cmd Msg )
init i =
    let
        ( userModel, userCmd ) =
            User.init i
    in
    ( User userModel, Cmd.map GotUserMsg userCmd )


type Page
    = Users


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( GotUserMsg user_msg, User user_model ) ->
            let
                ( userModel, userCmd ) =
                    User.update user_msg user_model
            in
            ( User userModel, Cmd.map GotUserMsg userCmd )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


view : Model -> Html Msg
view model =
    case model of
        User user_model ->
            Html.map GotUserMsg (User.view user_model)
