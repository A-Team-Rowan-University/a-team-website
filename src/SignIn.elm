port module SignIn exposing (SignInModel(..), SignInMsg, SignInUser, signIn, signInSubscriptions, updateSignIn, viewSignIn)

import Html exposing (Html, button, div, img, input, p, pre, span, text)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http exposing (emptyBody, header)
import Json.Decode exposing (Decoder, decodeValue, field, int, list, map5, nullable, string)
import Json.Encode as E



-- Subscriptions


signInSubscriptions : SignInModel -> Sub SignInMsg
signInSubscriptions _ =
    signIn SignIn



-- Ports


port signIn : (E.Value -> msg) -> Sub msg



-- Model


signedInUserDecoder : Decoder SignInUser
signedInUserDecoder =
    map5 SignInUser
        (field "first_name" string)
        (field "last_name" string)
        (field "email" string)
        (field "profile_url" string)
        (field "id_token" string)


type alias SignInUser =
    { first_name : String
    , last_name : String
    , email : String
    , profile_url : String
    , id_token : String
    }


type SignInModel
    = SignedIn SignInUser
    | SignedOut
    | SignInFailure Json.Decode.Error



-- Update


type SignInMsg
    = SignIn E.Value


updateSignIn : SignInMsg -> SignInModel -> ( SignInModel, Cmd SignInMsg )
updateSignIn msg model =
    case msg of
        SignIn user_json ->
            case decodeValue signedInUserDecoder user_json of
                Ok user ->
                    ( SignedIn user, Cmd.none )

                Err e ->
                    ( SignInFailure e, Cmd.none )



-- View


viewSignIn : SignInModel -> Html SignInMsg
viewSignIn model =
    case model of
        SignedIn user ->
            span [ class "level" ]
                [ div [ class "level-left" ]
                    [ p [ class "has-text-left", class "level-item" ]
                        [ text (user.first_name ++ " " ++ user.last_name) ]
                    ]
                , div [ class "level-right" ]
                    [ div [ class "image is-32x32", class "level-item" ]
                        [ img [ src user.profile_url ] [] ]
                    ]
                ]

        SignedOut ->
            div [ class "level-item" ]
                [ div []
                    [ div
                        [ class "g-signin2"
                        , attribute "data-onsuccess" "onSignIn"
                        ]
                        []
                    ]
                ]

        SignInFailure _ ->
            div [] [ text "Failed to sign in" ]
