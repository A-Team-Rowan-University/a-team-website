port module Main exposing (Model(..), Msg(..), SignInUser, init, main, signIn, subscriptions, update, view)

import Browser
import Html exposing (Html, button, div, img, input, text)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Decode exposing (Decoder, decodeValue, field, map5, string)
import Json.Encode as E
import Platform.Cmd
import Platform.Sub


main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


subscriptions : Model -> Sub Msg
subscriptions _ =
    signIn SignIn


port signIn : (E.Value -> msg) -> Sub msg



-- MODEL


type alias SignInUser =
    { first_name : String
    , last_name : String
    , email : String
    , profile_url : String
    , id_token : String
    }


type Model
    = SignedIn SignInUser
    | SignedOut
    | SignInFailure Json.Decode.Error


init : () -> ( Model, Cmd msg )
init _ =
    ( SignedOut, Cmd.none )



-- UPDATE


type Msg
    = SignIn E.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SignIn user_json ->
            ( case decodeValue signedInUserDecoder user_json of
                Ok user ->
                    SignedIn user

                Err e ->
                    SignInFailure e
            , Cmd.none
            )


signedInUserDecoder : Decoder SignInUser
signedInUserDecoder =
    map5 SignInUser
        (field "first_name" string)
        (field "last_name" string)
        (field "email" string)
        (field "profile_url" string)
        (field "id_token" string)



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ div
            [ class "g-signin2"
            , attribute "data-onsuccess" "onSignIn"
            ]
            []
        , case model of
            SignedIn user ->
                div []
                    [ div [] [ text user.first_name ]
                    , div [] [ text user.last_name ]
                    , div [] [ text user.email ]
                    , img [ src user.profile_url ] []
                    , div [] [ text user.id_token ]
                    ]

            SignedOut ->
                div [] [ text "Not signed in" ]

            SignInFailure _ ->
                div [] [ text "Sign in failure" ]
        ]
