port module Main exposing (Model, Msg(..), init, main, subscriptions, update, view)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http exposing (emptyBody, header)
import Json.Decode as D
import Json.Encode as E
import Platform.Cmd
import Platform.Sub
import Url
import Url.Parser as P exposing ((</>))


main =
    Browser.application
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    signIn SignIn



-- Ports


port signIn : (E.Value -> msg) -> Sub msg



-- MODEL


type alias User =
    { id : Int
    , first_name : String
    , last_name : String
    , email : Maybe String
    , banner_id : Int
    }


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


type Route
    = Home
    | Users
    | NotFound


routeParser : P.Parser (Route -> a) a
routeParser =
    P.oneOf
        [ P.map Home P.top
        , P.map Users (P.s "users")
        ]


type UserListModel
    = Loading
    | UserList (List User)
    | NetworkError Http.Error


type alias Model =
    { navkey : Nav.Key
    , route : Route
    , signin : SignInModel
    , users : UserListModel
    }


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { navkey = key
      , route = Maybe.withDefault NotFound (P.parse routeParser url)
      , signin = SignedOut
      , users = Loading
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = SignIn E.Value
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotUsers (Result Http.Error (List User))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SignIn user_json ->
            case D.decodeValue signedInUserDecoder user_json of
                Ok user ->
                    ( { model | signin = SignedIn user }
                    , loadData model.route (SignedIn user)
                    )

                Err e ->
                    ( { model | signin = SignInFailure e }, Cmd.none )

        GotUsers users_result ->
            ( case users_result of
                Ok users ->
                    { model | users = UserList users }

                Err e ->
                    { model | users = NetworkError e }
            , Cmd.none
            )

        LinkClicked request ->
            case request of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.navkey (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            case P.parse routeParser url of
                Nothing ->
                    ( { model | route = NotFound }, Cmd.none )

                Just route ->
                    ( { model | route = route }, loadData route model.signin )


loadData : Route -> SignInModel -> Cmd Msg
loadData route signin =
    case route of
        Home ->
            Cmd.none

        Users ->
            case signin of
                SignedIn user ->
                    Http.request
                        { method = "GET"
                        , headers = [ header "id_token" user.id_token ]
                        , url = "http://localhost/api/v1/users/"
                        , body = emptyBody
                        , expect = Http.expectJson GotUsers userListDecoder
                        , timeout = Nothing
                        , tracker = Nothing
                        }

                _ ->
                    Cmd.none

        NotFound ->
            Cmd.none


signedInUserDecoder : D.Decoder SignInUser
signedInUserDecoder =
    D.map5 SignInUser
        (D.field "first_name" D.string)
        (D.field "last_name" D.string)
        (D.field "email" D.string)
        (D.field "profile_url" D.string)
        (D.field "id_token" D.string)


userDecoder : D.Decoder User
userDecoder =
    D.map5 User
        (D.field "id" D.int)
        (D.field "first_name" D.string)
        (D.field "last_name" D.string)
        (D.field "email" (D.nullable D.string))
        (D.field "banner_id" D.int)


userListDecoder : D.Decoder (List User)
userListDecoder =
    D.field "users" (D.list userDecoder)



-- VIEW


viewSignIn : SignInModel -> Html Msg
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
                        [ text "Waiting for Google..." ]
                    ]
                ]

        SignInFailure _ ->
            div [] [ text "Failed to sign in" ]


viewUser : User -> Html Msg
viewUser user =
    div [ class "box" ]
        [ p [ class "title is-5" ] [ text (user.first_name ++ " " ++ user.last_name) ]
        , p [ class "subtitle is-5 columns" ]
            [ span [ class "column" ]
                [ text ("Email: " ++ Maybe.withDefault "No email" user.email) ]
            , span [ class "column" ]
                [ text ("Banner ID: " ++ String.fromInt user.banner_id) ]
            ]
        ]


viewPageUserList : UserListModel -> Html Msg
viewPageUserList user_list =
    case user_list of
        Loading ->
            text "Loading users..."

        UserList users ->
            div []
                [ p [ class "title has-text-centered" ] [ text "Users" ]
                , div [ class "columns" ]
                    [ div [ class "column is-one-fifth" ]
                        [ p [ class "title is-4 has-text-centered" ] [ text "Search" ]
                        , p [ class "has-text-centered" ] [ text "Working on it :)" ]
                        ]
                    , div [ class "column" ] (List.map viewUser users)
                    ]
                ]

        NetworkError e ->
            text "Network error loading users!"


viewPage : Model -> Html Msg
viewPage model =
    case model.route of
        Users ->
            viewPageUserList model.users

        Home ->
            h1 [] [ text "Welcome to the A-Team!" ]

        NotFound ->
            h1 [] [ text "Page not found!" ]


view : Model -> Browser.Document Msg
view model =
    { title = "A-Team!"
    , body =
        [ div []
            [ nav [ class "navbar", class "is-primary" ]
                [ div [ class "navbar-brand" ]
                    [ a [ class "navbar-item", href "/" ]
                        [ img [ src "/A-TeamLogo2.svg" ] [] ]
                    , a
                        [ attribute "role" "button"
                        , class "navbar-burger"
                        , class "burger"
                        , attribute "aria-label" "menu"
                        , attribute "aria-expanded" "false"
                        , attribute "data-target" "navbar"
                        ]
                        [ span [ attribute "aria-hidden" "true" ] []
                        , span [ attribute "aria-hidden" "true" ] []
                        , span [ attribute "aria-hidden" "true" ] []
                        ]
                    ]
                , div [ id "navbar", class "navbar-menu" ]
                    [ div [ class "navbar-start" ]
                        [ a [ class "navbar-item", href "/" ] [ text "Home" ]
                        , a [ class "navbar-item", href "/users" ] [ text "Users" ]
                        ]
                    , div [ class "navbar-end" ]
                        [ div [ class "navbar-item" ]
                            [ viewSignIn model.signin ]
                        ]
                    ]
                ]
            , div [ class "container" ] [ viewPage model ]
            ]
        ]
    }
