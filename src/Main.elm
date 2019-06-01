port module Main exposing (Model, Msg(..), init, main, subscriptions, update, view)

import Browser
import Html exposing (Html, button, div, img, input, pre, text)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http exposing (emptyBody, header)
import Json.Decode exposing (Decoder, decodeValue, field, int, list, map5, nullable, string)
import Json.Encode as E
import Platform.Cmd
import Platform.Sub
import SignIn exposing (SignInModel(..), SignInMsg, SignInUser, signInSubscriptions, updateSignIn, viewSignIn)


main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map GotSignInMsg (signInSubscriptions model.signin)



-- MODEL


type alias User =
    { id : Int
    , first_name : String
    , last_name : String
    , email : Maybe String
    , banner_id : Int
    }


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
    = GotSignInMsg SignInMsg
    | GotUsers (Result Http.Error (List User))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotSignInMsg signin_msg ->
            let
                ( signInModel, signInCmd ) =
                    updateSignIn signin_msg model.signin
            in
            ( { model | signin = signInModel }, Cmd.map GotSignInMsg signInCmd )

        GotUsers users_result ->
            ( case users_result of
                Ok users ->
                    { model | userlist = UserList users }

                Err e ->
                    { model | userlist = NetworkError e }
            , Cmd.none
            )


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
        [ Html.map GotSignInMsg (viewSignIn model.signin)
        , case model.userlist of
            Loading ->
                text "Loading users..."

            UserList users ->
                div [] (List.map viewUser users)

            NetworkError e ->
                text "Network error loading users!"
        ]
