port module Main exposing (Model, Msg(..), SignInUser, init, main, signIn, subscriptions, update, view)

import Browser
import Html exposing (Html, button, div, img, input, pre, text)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http exposing (emptyBody, header)
import Json.Decode exposing (Decoder, decodeValue, field, int, list, map5, nullable, string)
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


type alias User =
    { id : Int
    , first_name : String
    , last_name : String
    , email : Maybe String
    , banner_id : Int
    }


type SignInModel
    = SignedIn SignInUser
    | SignedOut
    | SignInFailure Json.Decode.Error


type UserListModel
    = Loading
    | UserList (List User)
    | NetworkError Http.Error


type alias Model =
    { signin : SignInModel
    , userlist : UserListModel
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { signin = SignedOut
      , userlist = Loading
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = SignIn E.Value
    | GotUsers (Result Http.Error (List User))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SignIn user_json ->
            case decodeValue signedInUserDecoder user_json of
                Ok user ->
                    ( { model | signin = SignedIn user }
                    , Http.request
                        { method = "GET"
                        , headers = [ header "id_token" user.id_token ]
                        , url = "http://localhost/api/v1/users/"
                        , body = emptyBody
                        , expect = Http.expectJson GotUsers userListDecoder
                        , timeout = Nothing
                        , tracker = Nothing
                        }
                    )

                Err e ->
                    ( { model | signin = SignInFailure e }, Cmd.none )

        GotUsers users_result ->
            ( case users_result of
                Ok users ->
                    { model | userlist = UserList users }

                Err e ->
                    { model | userlist = NetworkError e }
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


userDecoder : Decoder User
userDecoder =
    map5 User
        (field "id" int)
        (field "first_name" string)
        (field "last_name" string)
        (field "email" (nullable string))
        (field "banner_id" int)


userListDecoder : Decoder (List User)
userListDecoder =
    field "users" (list userDecoder)



-- VIEW


viewUser : User -> Html Msg
viewUser user =
    div []
        [ div [] [ text (user.first_name ++ " " ++ user.last_name) ]
        , div [] [ text (Maybe.withDefault "No email" user.email) ]
        , div [] [ text (String.fromInt user.banner_id) ]
        ]


view : Model -> Html Msg
view model =
    div []
        [ div
            [ class "g-signin2"
            , attribute "data-onsuccess" "onSignIn"
            ]
            []
        , case model.signin of
            SignedIn user ->
                div []
                    [ div [] [ text (user.first_name ++ " " ++ user.last_name) ]
                    , img [ src user.profile_url ] []
                    , pre [] [ text user.id_token ]
                    ]

            SignedOut ->
                div [] [ text "Not signed in" ]

            SignInFailure _ ->
                div [] [ text "Failed to sign in" ]
        , case model.userlist of
            Loading ->
                text "Loading users..."

            UserList users ->
                div [] (List.map viewUser users)

            NetworkError e ->
                text "Network error loading users!"
        ]
