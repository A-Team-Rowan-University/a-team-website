port module SignIn exposing (SignInModel(..), SignInMsg, SignInUser, signIn, signInSubscriptions, updateSignIn, viewSignIn)

import Html exposing (Html, button, div, img, input, p, pre, span, text)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http exposing (emptyBody, header)
import Json.Decode as D
import Json.Encode as E



-- Subscriptions


signInSubscriptions : SignInModel -> Sub SignInMsg
signInSubscriptions _ =
    signIn SignIn



-- Ports


port signIn : (E.Value -> msg) -> Sub msg



-- Model


signedInUserDecoder : D.Decoder SignInUser
signedInUserDecoder =
    D.map5 SignInUser
        (D.field "first_name" D.string)
        (D.field "last_name" D.string)
        (D.field "email" D.string)
        (D.field "profile_url" D.string)
        (D.field "id_token" D.string)


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
    | SignInFailure D.Error



-- Update


type SignInMsg
    = SignIn E.Value


updateSignIn : SignInMsg -> SignInModel -> ( SignInModel, Cmd SignInMsg )
updateSignIn msg model =
    case msg of
        SignIn user_json ->
            case D.decodeValue signedInUserDecoder user_json of
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
